import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/todo.dart';
import '../models/destination_todos.dart';

class TodoService extends ChangeNotifier {
  Map<String, DestinationTodos> _destinationTodos = {};
  
  // Get todos for a specific destination
  List<Todo> getTodosForDestination(String destinationId) {
    return _destinationTodos[destinationId]?.todos ?? [];
  }
  
  // Get pending todos for a destination
  List<Todo> getPendingTodos(String destinationId) {
    return _destinationTodos[destinationId]?.pendingTodos ?? [];
  }
  
  // Check if destination has any pending todos
  bool hasPendingTodos(String destinationId) {
    final dest = _destinationTodos[destinationId];
    return dest != null && dest.pendingTodos.isNotEmpty;
  }

  TodoService() {
    loadTodos();
  }

  Future<void> loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? todosJson = prefs.getString('destination_todos');
    
    if (todosJson != null) {
      final Map<String, dynamic> decoded = json.decode(todosJson);
      _destinationTodos = decoded.map((key, value) => 
        MapEntry(key, DestinationTodos.fromJson(value))
      );
    }
    notifyListeners();
  }

  // Add todo to a destination
  Future<void> addTodo(String destinationId, String title, {String? description}) async {
    final todos = _destinationTodos[destinationId]?.todos ?? [];
    final newTodo = Todo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      createdAt: DateTime.now(),
      priority: todos.length, // Add at the end
    );
    
    todos.add(newTodo);
    _destinationTodos[destinationId] = DestinationTodos(
      destinationId: destinationId,
      todos: todos,
    );
    
    await _saveTodos();
    notifyListeners();
  }

  // Toggle todo completion
  Future<void> toggleTodo(String destinationId, String todoId) async {
    final dest = _destinationTodos[destinationId];
    if (dest == null) return;
    
    final index = dest.todos.indexWhere((t) => t.id == todoId);
    if (index != -1) {
      final todo = dest.todos[index];
      dest.todos[index] = todo.copyWith(
        isCompleted: !todo.isCompleted,
        completedAt: !todo.isCompleted ? DateTime.now() : null,
      );
      await _saveTodos();
      notifyListeners();
    }
  }

  // Delete todo
  Future<void> deleteTodo(String destinationId, String todoId) async {
    final dest = _destinationTodos[destinationId];
    if (dest == null) return;
    
    dest.todos.removeWhere((t) => t.id == todoId);
    
    // If no todos left, remove the destination entry
    if (dest.todos.isEmpty) {
      _destinationTodos.remove(destinationId);
    }
    
    await _saveTodos();
    notifyListeners();
  }

  // Update todo
  Future<void> updateTodo(String destinationId, Todo updatedTodo) async {
    final dest = _destinationTodos[destinationId];
    if (dest == null) return;
    
    final index = dest.todos.indexWhere((t) => t.id == updatedTodo.id);
    if (index != -1) {
      dest.todos[index] = updatedTodo;
      await _saveTodos();
      notifyListeners();
    }
  }

  // Reorder todos (for priority)
  Future<void> reorderTodos(String destinationId, int oldIndex, int newIndex) async {
    final dest = _destinationTodos[destinationId];
    if (dest == null) return;
    
    if (oldIndex < newIndex) newIndex -= 1;
    final todo = dest.todos.removeAt(oldIndex);
    dest.todos.insert(newIndex, todo);
    
    // Update priorities based on new order
    for (int i = 0; i < dest.todos.length; i++) {
      dest.todos[i] = dest.todos[i].copyWith(priority: i);
    }
    
    await _saveTodos();
    notifyListeners();
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonMap = {};
    _destinationTodos.forEach((key, value) {
      jsonMap[key] = value.toJson();
    });
    await prefs.setString('destination_todos', json.encode(jsonMap));
  }
}