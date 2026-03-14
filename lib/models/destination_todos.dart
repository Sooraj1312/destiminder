import 'todo.dart';

class DestinationTodos {
  final String destinationId;
  final List<Todo> todos;

  DestinationTodos({
    required this.destinationId,
    required this.todos,
  });

  // Get pending todos (not completed)
  List<Todo> get pendingTodos => todos.where((t) => !t.isCompleted).toList();
  
  // Get completed todos
  List<Todo> get completedTodos => todos.where((t) => t.isCompleted).toList();

  Map<String, dynamic> toJson() => {
    'destinationId': destinationId,
    'todos': todos.map((t) => t.toJson()).toList(),
  };

  factory DestinationTodos.fromJson(Map<String, dynamic> json) => DestinationTodos(
    destinationId: json['destinationId'],
    todos: (json['todos'] as List).map((t) => Todo.fromJson(t)).toList(),
  );
}