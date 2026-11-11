import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  AuthService() {
    if (Firebase.apps.isEmpty) {
      _initialized = true;
      return;
    }
    _auth = FirebaseAuth.instance;
    _user = _auth!.currentUser;
    _initialized = true;
    _authSub = _auth!.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  FirebaseAuth? _auth;
  StreamSubscription<User?>? _authSub;
  User? _user;
  bool _initialized = false;
  bool _busy = false;
  bool _googleInitialized = false;
  String? _error;

  bool get isAvailable => _auth != null;
  bool get isInitialized => _initialized;
  bool get isBusy => _busy;
  bool get isSignedIn => _user != null;
  User? get user => _user;
  String? get error => _error;

  Future<bool> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      _error = 'Firebase is not configured on this build.';
      notifyListeners();
      return false;
    }

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await google.initialize();
        _googleInitialized = true;
      }

      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('Google ID token missing.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await auth.signInWithCredential(credential);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _error = e.description ?? e.code.name;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? e.code;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) return;

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      if (_googleInitialized) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      debugPrint('Google sign out failed: $e');
    }

    try {
      await auth.signOut();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount() async {
    final auth = _auth;
    final user = auth?.currentUser;
    if (auth == null || user == null) return false;

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      for (final name in ['destinations', 'history', 'todos', 'settings']) {
        batch.delete(db.doc('users/${user.uid}/data/$name'));
      }
      await batch.commit();
      await user.delete();

      if (_googleInitialized) {
        await GoogleSignIn.instance.disconnect();
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _error = 'Please sign in again, then delete the account.';
      } else {
        _error = e.message ?? e.code;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
