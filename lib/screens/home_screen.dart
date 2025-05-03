import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/task_model.dart';
import '../services/gemini_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<TaskModel> taskBox;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isProcessingCommand = false;

  @override
  void initState() {
    super.initState();
    taskBox = Hive.box<TaskModel>('tasks');
    _speech = stt.SpeechToText();
  }

  Future<void> _startListening() async {
    if (_isProcessingCommand) return;

    final micStatus = await Permission.microphone.request();

    if (micStatus != PermissionStatus.granted) {
      _showSnack('Microphone permission denied.');
      return;
    }

    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) async {
        if (result.finalResult) {
          _speech.stop();
          setState(() => _isListening = false);
          await _handleVoiceCommand(result.recognizedWords);
        }
      });
    } else {
      _showSnack('Speech recognition not available.');
    }
  }

  Future<void> _stopListening() async {
    setState(() {
      _isListening = false;
      _isProcessingCommand = false;
    });
    await _speech.stop();
  }

  Future<void> _handleVoiceCommand(String commandText) async {
    if (_isProcessingCommand) return; // Ignore if already processing

    setState(() {
      _isProcessingCommand = true;
    });

    final json = await GeminiService.parseCommand(commandText);
    if (json == null) {
      _showSnack('Could not understand command.');
      setState(() {
        _isProcessingCommand = false;
      });
      return;
    }

    final action = json['action']?.toLowerCase();
    final title = json['title']?.toString().trim();
    final description = json['description']?.toString().trim() ?? '';
    final datetimeStr = json['datetime'];

    if (title == null || title.isEmpty) {
      _showSnack('Task title is missing. Please specify a title.');
      setState(() {
        _isProcessingCommand = false;
      });
      return;
    }

    DateTime? dateTime;
    if (datetimeStr != null && datetimeStr.isNotEmpty) {
      try {
        dateTime = DateTime.parse(datetimeStr);
      } catch (_) {
        _showSnack('Invalid date/time format.');
        setState(() {
          _isProcessingCommand = false;
        });
        return;
      }
    }

    // Handle duplicates and conflicts
    final existingTasks = taskBox.values.where((t) {
      final titleMatch = t.title.toLowerCase() == title.toLowerCase();
      final dateMatch = dateTime == null || t.datetime == dateTime;
      return titleMatch || dateMatch;
    }).toList();

    if (existingTasks.isNotEmpty) {
      if (existingTasks.length == 1) {
        _handleAction(
            action, existingTasks.first, title, description, dateTime);
      } else {
        _showSnack(
            'Multiple tasks found with the same title and time. Which one would you like to update/delete?');
        setState(() {
          _isProcessingCommand = false;
        });
      }
    } else {
      _handleAction(action, null, title, description, dateTime);
    }
  }

  void _handleAction(String? action, TaskModel? existingTask, String title,
      String description, DateTime? dateTime) async {
    switch (action) {
      case 'create':
        final newTask = TaskModel(
          id: const Uuid().v4(),
          title: title,
          description: description,
          datetime: dateTime ?? DateTime.now(),
        );
        await taskBox.add(newTask);
        _showSnack('Task created.');
        break;

      case 'update':
        if (existingTask != null) {
          existingTask.title = title;
          existingTask.description = description;
          existingTask.datetime = dateTime ?? existingTask.datetime;
          await existingTask.save();
          _showSnack('Task updated.');
        } else {
          _showSnack('No matching task found to update.');
        }
        break;

      case 'delete':
        if (existingTask != null) {
          await existingTask.delete();
          _showSnack('Task deleted.');
        } else {
          _showSnack('No matching task found to delete.');
        }
        break;

      default:
        _showSnack('Unknown action.');
    }

    setState(() {
      _isProcessingCommand = false;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Task Manager'),
        backgroundColor: Colors.teal,
        elevation: 4,
      ),
      body: ValueListenableBuilder(
        valueListenable: taskBox.listenable(),
        builder: (_, Box<TaskModel> box, __) {
          if (box.isEmpty) return const Center(child: Text('No tasks yet.'));
          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (_, i) {
              final task = box.getAt(i)!;
              return Card(
                margin: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  title: Text(task.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${task.description}\n${task.datetime}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          // Add navigation to edit task screen
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _showDeleteConfirmationDialog(task);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isListening ? _stopListening : _startListening,
        backgroundColor: Colors.teal,
        child: Icon(
          _isListening ? Icons.mic_off : Icons.mic,
          color: Colors.white,
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(TaskModel task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content:
            Text('Are you sure you want to delete the task: "${task.title}"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () async {
              await task.delete();
              _showSnack('Task deleted.');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
