import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/arrival_history.dart';
import '../models/destination.dart';
import '../models/destination_todos.dart';
import '../models/todo.dart';
import 'background_monitor.dart';
import 'destination_service.dart';
import 'history_service.dart';
import 'todo_service.dart';

class CloudSyncService extends ChangeNotifier {
  CloudSyncService({
    required this.destinationService,
    required this.historyService,
    required this.todoService,
  }) {
    if (Firebase.apps.isNotEmpty) {
      _db = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      _authSub = _auth!.authStateChanges().listen(_onAuthChanged);
      _lifecycle = AppLifecycleListener(onResume: _onResume);
    }
  }

  final DestinationService destinationService;
  final HistoryService historyService;
  final TodoService todoService;

  final ValueNotifier<int> settingsRevision = ValueNotifier<int>(0);

  FirebaseFirestore? _db;
  FirebaseAuth? _auth;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _destSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _historySub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _todosSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;
  AppLifecycleListener? _lifecycle;
  Timer? _pushDebounce;

  String? _uid;
  bool _isSyncing = false;
  int _remoteApplyDepth = 0;
  DateTime? _lastSync;
  String? _error;

  bool get isAvailable => _db != null;
  bool get isSignedIn => _auth?.currentUser != null;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSync => _lastSync;
  String? get error => _error;
  User? get user => _auth?.currentUser;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _uid = null;
      _stopListeners();
      _lastSync = null;
      _error = null;
      notifyListeners();
      return;
    }

    if (_uid == user.uid) return;

    _uid = user.uid;
    _error = null;
    notifyListeners();

    await syncNow();

    if (_uid == user.uid) {
      _listenToUser(user.uid);
    }
  }

  void _onResume() {
    if (_uid != null) {
      syncNow();
    }
  }

  Future<void> syncNow() async {
    final uid = _uid;
    final db = _db;
    if (uid == null || db == null || _isSyncing) return;

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      await _pullAndMerge(uid, db);
      await _pushAll(uid, db);
      _lastSync = DateTime.now();
    } catch (e) {
      _error = _friendlyError(e);
      debugPrint('CloudSync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void schedulePush() {
    if (_remoteApplyDepth > 0) return;

    final uid = _uid;
    final db = _db;
    if (uid == null || db == null) return;

    _pushDebounce?.cancel();
    _pushDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        await _pushAll(uid, db);
        _lastSync = DateTime.now();
        notifyListeners();
      } catch (e) {
        _error = _friendlyError(e);
        debugPrint('CloudSync push error: $e');
        notifyListeners();
      }
    });
  }

  void _listenToUser(String uid) {
    _stopListeners();
    final db = _db;
    if (db == null) return;

    _destSub = db
        .doc('users/$uid/data/destinations')
        .snapshots()
        .listen(_applyRemoteDestinations, onError: _onRemoteError);
    _historySub = db
        .doc('users/$uid/data/history')
        .snapshots()
        .listen(_applyRemoteHistory, onError: _onRemoteError);
    _todosSub = db
        .doc('users/$uid/data/todos')
        .snapshots()
        .listen(_applyRemoteTodos, onError: _onRemoteError);
    _settingsSub = db
        .doc('users/$uid/data/settings')
        .snapshots()
        .listen(_applyRemoteSettings, onError: _onRemoteError);
  }

  void _stopListeners() {
    _destSub?.cancel();
    _historySub?.cancel();
    _todosSub?.cancel();
    _settingsSub?.cancel();
    _destSub = null;
    _historySub = null;
    _todosSub = null;
    _settingsSub = null;
  }

  Future<void> _pullAndMerge(String uid, FirebaseFirestore db) async {
    final results = await Future.wait<DocumentSnapshot<Map<String, dynamic>>>([
      db.doc('users/$uid/data/destinations').get(),
      db.doc('users/$uid/data/history').get(),
      db.doc('users/$uid/data/todos').get(),
      db.doc('users/$uid/data/settings').get(),
    ]);

    final destinationsDoc = results[0];
    final historyDoc = results[1];
    final todosDoc = results[2];
    final settingsDoc = results[3];

    _remoteApplyDepth++;
    try {
      await destinationService.replaceAll(
        _mergeDestinations(
          destinationService.destinations,
          _parseDestinations(destinationsDoc.data()),
        ),
      );

      await historyService.replaceAll(
        _mergeHistory(
          historyService.history,
          _parseHistory(historyDoc.data()),
        ),
      );

      await todoService.replaceAll(
        _mergeTodos(
          todoService.allTodos,
          _parseTodos(todosDoc.data()),
        ),
      );

      final settings = settingsDoc.data();
      if (settings != null) {
        await _applySettings(settings);
      }
    } finally {
      _remoteApplyDepth--;
    }
  }

  Future<void> _pushAll(String uid, FirebaseFirestore db) async {
    final destinations =
        destinationService.destinations.map((d) => d.toJson()).toList();
    final history = historyService.history.map((h) => h.toJson()).toList();
    final todos = <String, dynamic>{};
    todoService.allTodos.forEach((key, value) {
      todos[key] = value.toJson();
    });
    final settings = await _readSettings();

    final batch = db.batch();
    batch.set(db.doc('users/$uid/data/destinations'), {
      'items': destinations,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(db.doc('users/$uid/data/history'), {
      'items': history,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(db.doc('users/$uid/data/todos'), {
      'items': todos,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(db.doc('users/$uid/data/settings'), {
      ...settings,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> _applyRemoteDestinations(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    if (!snap.exists || snap.metadata.hasPendingWrites) return;

    _remoteApplyDepth++;
    try {
      await destinationService.replaceAll(_parseDestinations(snap.data()));
      _lastSync = DateTime.now();
    } finally {
      _remoteApplyDepth--;
    }
    notifyListeners();
  }

  Future<void> _applyRemoteHistory(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    if (!snap.exists || snap.metadata.hasPendingWrites) return;

    _remoteApplyDepth++;
    try {
      await historyService.replaceAll(_parseHistory(snap.data()));
      _lastSync = DateTime.now();
    } finally {
      _remoteApplyDepth--;
    }
    notifyListeners();
  }

  Future<void> _applyRemoteTodos(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    if (!snap.exists || snap.metadata.hasPendingWrites) return;

    _remoteApplyDepth++;
    try {
      await todoService.replaceAll(_parseTodos(snap.data()));
      _lastSync = DateTime.now();
    } finally {
      _remoteApplyDepth--;
    }
    notifyListeners();
  }

  Future<void> _applyRemoteSettings(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    if (!snap.exists || snap.metadata.hasPendingWrites) return;

    final data = snap.data();
    if (data == null) return;

    await _applySettings(data);
    _lastSync = DateTime.now();
    notifyListeners();
  }

  Future<void> _applySettings(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    var changed = false;

    Future<void> setBool(String key) async {
      final value = data[key];
      if (value is bool && prefs.getBool(key) != value) {
        await prefs.setBool(key, value);
        changed = true;
      }
    }

    Future<void> setInt(String key) async {
      final value = data[key];
      if (value is int && prefs.getInt(key) != value) {
        await prefs.setInt(key, value);
        changed = true;
      }
    }

    await setBool('master_voice_enabled');
    await setBool('destinations_locked');
    await setBool('show_route_line');
    await setInt('home_tile_layer');
    await setBool('background_monitoring');

    if (changed) {
      settingsRevision.value++;
    }

    if (!kIsWeb) {
      final backgroundEnabled = data['background_monitoring'];
      if (backgroundEnabled is bool) {
        try {
          if (backgroundEnabled) {
            await BackgroundMonitor.startMonitoring();
          } else {
            await BackgroundMonitor.stopMonitoring();
          }
        } catch (e) {
          debugPrint('Background monitor sync failed: $e');
        }
      }
    }
  }

  Future<Map<String, dynamic>> _readSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'master_voice_enabled': prefs.getBool('master_voice_enabled') ?? true,
      'destinations_locked': prefs.getBool('destinations_locked') ?? true,
      'show_route_line': prefs.getBool('show_route_line') ?? false,
      'home_tile_layer': prefs.getInt('home_tile_layer') ?? 0,
      'background_monitoring':
          prefs.getBool('background_monitoring') ?? false,
    };
  }

  List<Destination> _parseDestinations(Map<String, dynamic>? data) {
    final raw = data?['items'];
    if (raw is! List) return const [];

    final result = <Destination>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          result.add(Destination.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('Skipping invalid destination: $e');
        }
      }
    }
    return result;
  }

  List<ArrivalHistory> _parseHistory(Map<String, dynamic>? data) {
    final raw = data?['items'];
    if (raw is! List) return const [];

    final result = <ArrivalHistory>[];
    for (final item in raw) {
      if (item is Map) {
        try {
          result.add(ArrivalHistory.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          debugPrint('Skipping invalid history entry: $e');
        }
      }
    }
    return result;
  }

  Map<String, DestinationTodos> _parseTodos(Map<String, dynamic>? data) {
    final raw = data?['items'];
    if (raw is! Map) return {};

    final result = <String, DestinationTodos>{};
    raw.forEach((key, value) {
      if (key is String && value is Map) {
        try {
          result[key] =
              DestinationTodos.fromJson(Map<String, dynamic>.from(value));
        } catch (e) {
          debugPrint('Skipping invalid todo list: $e');
        }
      }
    });
    return result;
  }

  List<Destination> _mergeDestinations(
    List<Destination> local,
    List<Destination> remote,
  ) {
    final result = <Destination>[];
    final seen = <String>{};

    for (final destination in remote) {
      if (seen.add(destination.id)) {
        result.add(destination);
      }
    }
    for (final destination in local) {
      if (seen.add(destination.id)) {
        result.add(destination);
      }
    }
    return result;
  }

  List<ArrivalHistory> _mergeHistory(
    List<ArrivalHistory> local,
    List<ArrivalHistory> remote,
  ) {
    final byId = <String, ArrivalHistory>{};
    for (final entry in remote) {
      byId[entry.id] = entry;
    }
    for (final entry in local) {
      byId.putIfAbsent(entry.id, () => entry);
    }

    final result = byId.values.toList();
    result.sort((a, b) => b.arrivalTime.compareTo(a.arrivalTime));
    return result;
  }

  Map<String, DestinationTodos> _mergeTodos(
    Map<String, DestinationTodos> local,
    Map<String, DestinationTodos> remote,
  ) {
    final result = <String, DestinationTodos>{};
    for (final entry in remote.entries) {
      result[entry.key] = entry.value;
    }

    for (final entry in local.entries) {
      final remoteEntry = result[entry.key];
      if (remoteEntry == null) {
        result[entry.key] = entry.value;
        continue;
      }

      final byId = <String, Todo>{};
      for (final todo in remoteEntry.todos) {
        byId[todo.id] = todo;
      }
      for (final todo in entry.value.todos) {
        byId.putIfAbsent(todo.id, () => todo);
      }

      final todos = byId.values.toList();
      todos.sort((a, b) => a.priority.compareTo(b.priority));
      result[entry.key] = DestinationTodos(
        destinationId: entry.key,
        todos: todos,
      );
    }
    return result;
  }

  void _onRemoteError(Object error) {
    _error = _friendlyError(error);
    debugPrint('CloudSync listener error: $error');
    notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Permission denied. Check your Firestore rules.';
        case 'unavailable':
          return 'No internet connection. Local data is safe.';
        case 'unauthenticated':
          return 'Sign-in expired. Please sign in again.';
      }
      return error.message ?? error.code;
    }
    return error.toString();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _stopListeners();
    _pushDebounce?.cancel();
    _lifecycle?.dispose();
    settingsRevision.dispose();
    super.dispose();
  }
}
