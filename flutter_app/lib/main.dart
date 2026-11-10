
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PersonalAiApp());
}

class PersonalAiApp extends StatelessWidget {
  const PersonalAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal AI Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const AgentHome(),
    );
  }
}

class BackendSettings {
  const BackendSettings({
    required this.url,
    required this.token,
  });

  final String url;
  final String token;
}

class BackendSettingsDialog extends StatefulWidget {
  const BackendSettingsDialog({
    super.key,
    required this.initialUrl,
    required this.initialToken,
  });

  final String initialUrl;
  final String initialToken;

  @override
  State<BackendSettingsDialog> createState() =>
      _BackendSettingsDialogState();
}

class _BackendSettingsDialogState
    extends State<BackendSettingsDialog> {
  late final TextEditingController urlController;
  late final TextEditingController tokenController;

  @override
  void initState() {
    super.initState();

    urlController = TextEditingController(
      text: widget.initialUrl,
    );

    tokenController = TextEditingController(
      text: widget.initialToken,
    );
  }

  @override
  void dispose() {
    urlController.dispose();
    tokenController.dispose();
    super.dispose();
  }

  void saveSettings() {
    final url = urlController.text
        .trim()
        .replaceFirst(RegExp(r'/+$'), '');

    final token = tokenController.text.trim();

    final uri = Uri.tryParse(url);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid HTTPS backend URL.'),
        ),
      );
      return;
    }

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your app access token.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      BackendSettings(url: url, token: token),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI backend settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your backend URL and app access token, '
              'NOT your Gemini API key.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'HTTPS backend URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tokenController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'App access token',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saveSettings,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class AgentHome extends StatefulWidget {
  const AgentHome({super.key});

  @override
  State<AgentHome> createState() => _AgentHomeState();
}

class _AgentHomeState extends State<AgentHome> {
  int tab = 0;
  bool loading = false;

  String url = '';
  String token = '';

  final chatInput = TextEditingController();
  final noteInput = TextEditingController();
  final taskInput = TextEditingController();

  List<Map<String, String>> chat = [];
  List<String> notes = [];
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedChat = jsonDecode(
        prefs.getString('chat') ?? '[]',
      ) as List;

      final savedNotes = jsonDecode(
        prefs.getString('notes') ?? '[]',
      ) as List;

      final savedTasks = jsonDecode(
        prefs.getString('tasks') ?? '[]',
      ) as List;

      if (!mounted) return;

      setState(() {
        url = prefs.getString('url') ?? '';

        chat = savedChat
            .map((e) => Map<String, String>.from(e as Map))
            .toList();

        notes = List<String>.from(savedNotes);

        tasks = savedTasks
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      showMessage('Could not load saved data.');
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('url', url);
      await prefs.setString('chat', jsonEncode(chat));
      await prefs.setString('notes', jsonEncode(notes));
      await prefs.setString('tasks', jsonEncode(tasks));
    } catch (e) {
      showMessage('Could not save data.');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> settings() async {
    final result = await showDialog<BackendSettings>(
      context: context,
      builder: (dialogContext) {
        return BackendSettingsDialog(
          initialUrl: url,
          initialToken: token,
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      url = result.url;
      token = result.token;
    });

    await save();

    showMessage('Backend settings saved.');
  }

  Future<void> send() async {
    final message = chatInput.text.trim();

    if (message.isEmpty || loading) return;

    if (!url.startsWith('https://') || token.isEmpty) {
      showMessage(
        'Configure the backend URL and token in Settings.',
      );
      return;
    }

    chatInput.clear();

    setState(() {
      chat.add({
        'role': 'user',
        'content': message,
      });

      loading = true;
    });

    await save();

    try {
      final messages = chat.length > 12
          ? chat.sublist(chat.length - 12)
          : List<Map<String, String>>.from(chat);

      final response = await http
          .post(
            Uri.parse('$url/chat'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 401) {
        throw Exception('Invalid backend access token.');
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Backend returned HTTP ${response.statusCode}.',
        );
      }

      final data =
          jsonDecode(response.body) as Map<String, dynamic>;

      final reply = data['reply'];

      if (reply is! String || reply.trim().isEmpty) {
        throw Exception('Empty AI response.');
      }

      if (!mounted) return;

      setState(() {
        chat.add({
          'role': 'assistant',
          'content': reply,
        });
      });
    } catch (e) {
      showMessage('Chat failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });

        await save();
      }
    }
  }

  void addNote() {
    final text = noteInput.text.trim();

    if (text.isEmpty) return;

    setState(() {
      notes.insert(0, text);
      noteInput.clear();
    });

    save();
  }

  void addTask() {
    final text = taskInput.text.trim();

    if (text.isEmpty) return;

    setState(() {
      tasks.insert(0, {
        'title': text,
        'done': false,
      });

      taskInput.clear();
    });

    save();
  }

  Widget chatPage() {
    return Column(
      children: [
        if (url.isEmpty || token.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Connect your Gemini backend in Settings '
              'to enable AI Chat.',
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: chat.length,
            itemBuilder: (context, index) {
              final message = chat[index];

              final isUser = message['role'] == 'user';

              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Card(
                  color: isUser
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                      : null,
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(message['content'] ?? ''),
                  ),
                ),
              );
            },
          ),
        ),
        if (loading) const LinearProgressIndicator(),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: chatInput,
                  decoration: const InputDecoration(
                    hintText: 'Ask Gemini...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => send(),
                ),
              ),
              IconButton(
                tooltip: 'Send message',
                onPressed: loading ? null : send,
                icon: const Icon(Icons.send),
              ),
              IconButton(
                tooltip: 'Clear chat',
                onPressed: loading
                    ? null
                    : () {
                        setState(() {
                          chat.clear();
                        });
                        save();
                      },
                icon: const Icon(Icons.delete_sweep),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget notesPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: noteInput,
                  decoration: const InputDecoration(
                    hintText: 'New note',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => addNote(),
                ),
              ),
              IconButton(
                onPressed: addNote,
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(notes[index]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      notes.removeAt(index);
                    });
                    save();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget tasksPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: taskInput,
                  decoration: const InputDecoration(
                    hintText: 'New task',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => addTask(),
                ),
              ),
              IconButton(
                onPressed: addTask,
                icon: const Icon(Icons.add_circle),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Checkbox(
                  value: tasks[index]['done'] == true,
                  onChanged: (value) {
                    setState(() {
                      tasks[index]['done'] = value ?? false;
                    });
                    save();
                  },
                ),
                title: Text(
                  tasks[index]['title'] as String,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      tasks.removeAt(index);
                    });
                    save();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal AI Agent'),
        actions: [
          IconButton(
            tooltip: 'Backend settings',
            onPressed: settings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          chatPage(),
          notesPage(),
          tasksPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) {
          setState(() {
            tab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            label: 'AI Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_outlined),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            label: 'Tasks',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    chatInput.dispose();
    noteInput.dispose();
    taskInput.dispose();
    super.dispose();
  }
}
