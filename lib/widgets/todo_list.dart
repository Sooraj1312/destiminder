import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/todo_service.dart';
import '../models/todo.dart';
import '../models/destination.dart';

class TodoList extends StatefulWidget {
  final Destination destination;
  final VoidCallback onClose;

  const TodoList({
    super.key,
    required this.destination,
    required this.onClose,
  });

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final TextEditingController _todoController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _showCompleted = false; // Toggle to show/hide completed tasks

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.checklist, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tasks for ${widget.destination.displayName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  // Toggle completed tasks visibility
                  IconButton(
                    icon: Icon(
                        _showCompleted ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white,
                    ),
                    onPressed: () {
                        setState(() {
                        _showCompleted = !_showCompleted;
                        });
                    },
                    tooltip: _showCompleted ? 'Hide completed' : 'Show completed',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            
            // Todo List
            Consumer<TodoService>(
              builder: (context, todoService, child) {
                final allTodos = todoService.getTodosForDestination(widget.destination.id);
                
                // Split into pending and completed
                final pendingTodos = allTodos.where((t) => !t.isCompleted).toList();
                final completedTodos = allTodos.where((t) => t.isCompleted).toList();
                
                if (allTodos.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No tasks added yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddTodoDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Your First Task'),
                        ),
                      ],
                    ),
                  );
                }
                
                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    children: [
                      // Pending Tasks Section
                      if (pendingTodos.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'PENDING (${pendingTodos.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...pendingTodos.map((todo) => _buildTodoItem(todo, false)),
                      ],
                      
                      // Completed Tasks Section (if enabled)
                      if (_showCompleted && completedTodos.isNotEmpty) ...[
                        const Divider(height: 32, thickness: 1),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'COMPLETED (${completedTodos.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...completedTodos.map((todo) => _buildTodoItem(todo, true)),
                      ],
                    ],
                  ),
                );
              },
            ),
            
            // Add Todo Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showAddTodoDialog,
                      icon: const Icon(Icons.add_task),
                      label: const Text('Add Task'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoItem(Todo todo, bool isCompleted) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCompleted ? Colors.grey[50] : Colors.white,
      child: ListTile(
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (value) {
            _toggleTodoWithUndo(todo);
          },
          activeColor: Colors.green,
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted ? Colors.grey : Colors.black,
            fontWeight: todo.isCompleted ? FontWeight.normal : FontWeight.w500,
          ),
        ),
        subtitle: todo.description != null
            ? Text(
                todo.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: todo.isCompleted ? Colors.grey : Colors.grey[700],
                ),
              )
            : null,
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
          onSelected: (value) {
            if (value == 'delete') {
              _deleteTodo(todo);
            } else if (value == 'edit') {
              _showEditTodoDialog(todo);
            }
          },
        ),
        onTap: () {
          _toggleTodoWithUndo(todo);
        },
      ),
    );
  }

  void _toggleTodoWithUndo(Todo todo) {
    final todoService = Provider.of<TodoService>(context, listen: false);
    final newStatus = !todo.isCompleted;
    
    // Toggle the todo
    todoService.toggleTodo(widget.destination.id, todo.id);
    
    // Show UNDO snackbar only when marking as done (not when undoing)
    if (newStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${todo.title}" completed'),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.orange,
            onPressed: () {
              // Undo - toggle back to pending
              todoService.toggleTodo(widget.destination.id, todo.id);
            },
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showAddTodoDialog() {
    _todoController.clear();
    _descController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _todoController,
              decoration: const InputDecoration(
                labelText: 'Task title',
                hintText: 'e.g., Buy milk',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Additional details...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_todoController.text.isNotEmpty) {
                final todoService = Provider.of<TodoService>(context, listen: false);
                todoService.addTodo(
                  widget.destination.id,
                  _todoController.text,
                  description: _descController.text.isNotEmpty 
                      ? _descController.text 
                      : null,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditTodoDialog(Todo todo) {
    _todoController.text = todo.title;
    _descController.text = todo.description ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _todoController,
              decoration: const InputDecoration(labelText: 'Task title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_todoController.text.isNotEmpty) {
                final todoService = Provider.of<TodoService>(context, listen: false);
                final updated = todo.copyWith(
                  title: _todoController.text,
                  description: _descController.text.isNotEmpty 
                      ? _descController.text 
                      : null,
                );
                todoService.updateTodo(widget.destination.id, updated);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteTodo(Todo todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${todo.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final todoService = Provider.of<TodoService>(context, listen: false);
              todoService.deleteTodo(widget.destination.id, todo.id);
              Navigator.pop(context);
              
              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Task deleted'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _todoController.dispose();
    _descController.dispose();
    super.dispose();
  }
}