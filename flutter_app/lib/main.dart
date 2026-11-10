
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://ubjihxctiujchazrlnyv.supabase.co';
const supabaseKey = 'sb_publishable_qMh2cZsHZZsRP_ide1v7Hw_s8Tsep1S';

const backendUrl = 'https://ashiwany-personal-ai-api.onrender.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const PersonalAiApp());
}

class PersonalAiApp extends StatelessWidget {
  const PersonalAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Personal AI Agent',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();

    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      return const LoginPage();
    }

    return AgentHome(
      key: ValueKey(session.user.id),
      userId: session.user.id,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool signup = false;
  bool loading = false;
  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> authenticate() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Enter your email and password.');
      return;
    }

    setState(() => loading = true);

    try {
      final auth = Supabase.instance.client.auth;

      if (signup) {
        final response = await auth.signUp(
          email: email,
          password: password,
        );

        if (response.session == null) {
          showMessage(
            'Check your email for a verification link, '
            'then return here and log in.',
          );
        } else {
          showMessage('Account created successfully.');
        }
      } else {
        await auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      showMessage(error.message);
    } catch (_) {
      showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.smart_toy_rounded,
                    size: 76,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Personal AI Agent',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    signup
                        ? 'Create your personal account'
                        : 'Welcome back',
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(
                            () => hidePassword = !hidePassword,
                          );
                        },
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : authenticate,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: loading
                            ? const CircularProgressIndicator()
                            : Text(signup ? 'Sign Up' : 'Log In'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => setState(() => signup = !signup),
                    child: Text(
                      signup
                          ? 'Already have an account? Log In'
                          : 'New user? Create an account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AgentHome extends StatefulWidget {
  final String userId;

  const AgentHome({
    super.key,
    required this.userId,
  });

  @override
  State<AgentHome> createState() => _AgentHomeState();
}

class _AgentHomeState extends State<AgentHome> {
  final chatInput = TextEditingController();
  final itemInput = TextEditingController();

  int tab = 0;
  bool loading = false;

  List<Map<String, String>> chat = [];
  List<String> notes = [];
  List<Map<String, dynamic>> tasks = [];

  String get storagePrefix => 'agent_${widget.userId}_';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    chatInput.dispose();
    itemInput.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final storedChat = jsonDecode(
        prefs.getString('${storagePrefix}chat') ?? '[]',
      ) as List;

      final storedNotes = jsonDecode(
        prefs.getString('${storagePrefix}notes') ?? '[]',
      ) as List;

      final storedTasks = jsonDecode(
        prefs.getString('${storagePrefix}tasks') ?? '[]',
      ) as List;

      if (!mounted) return;

      setState(() {
        chat = storedChat
            .map(
              (e) => Map<String, String>.from(e as Map),
            )
            .toList();

        notes = storedNotes.map((e) => e.toString()).toList();

        tasks = storedTasks
            .map(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load saved local data.'),
        ),
      );
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      '${storagePrefix}chat',
      jsonEncode(chat),
    );
    await prefs.setString(
      '${storagePrefix}notes',
      jsonEncode(notes),
    );
    await prefs.setString(
      '${storagePrefix}tasks',
      jsonEncode(tasks),
    );
  }

  void message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> send() async {
    final text = chatInput.text.trim();

    if (text.isEmpty || loading) return;

    setState(() {
      loading = true;
      chat.add({'role': 'user', 'content': text});
    });

    chatInput.clear();
    await save();

    try {
      final auth = Supabase.instance.client.auth;
      var session = auth.currentSession;

      if (session == null) {
        throw Exception('Please log in again.');
      }

      if (session.isExpired) {
        final refreshed = await auth.refreshSession();
        session = refreshed.session;

        if (session == null) {
          throw Exception('Session expired. Please log in again.');
        }
      }

      final response = await http
          .post(
            Uri.parse('$backendUrl/chat'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
            body: jsonEncode({
              'messages': chat.length > 12
                  ? chat.sublist(chat.length - 12)
                  : chat,
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 401) {
        throw Exception('Session expired. Please log in again.');
      }

      if (response.statusCode != 200) {
        throw Exception(
          'AI service error (${response.statusCode}). '
          'Please try again.',
        );
      }

      final data = jsonDecode(response.body);
      final reply = data['reply']?.toString() ?? '';

      if (!mounted) return;

      setState(() {
        chat.add({
          'role': 'assistant',
          'content': reply.isEmpty
              ? 'No response generated.'
              : reply,
        });
      });

      await save();
    } catch (error) {
      message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addNote() async {
    final text = itemInput.text.trim();
    if (text.isEmpty) return;

    setState(() => notes.insert(0, text));
    itemInput.clear();
    await save();
  }

  Future<void> addTask() async {
    final text = itemInput.text.trim();
    if (text.isEmpty) return;

    setState(() {
      tasks.insert(0, {
        'title': text,
        'completed': false,
      });
    });

    itemInput.clear();
    await save();
  }

  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      message('Unable to log out. Please try again.');
    }
  }

  Widget chatPage() {
    return Column(
      children: [
        Expanded(
          child: chat.isEmpty
              ? const Center(
                  child: Text('Ask your AI assistant anything!'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: chat.length,
                  itemBuilder: (context, index) {
                    final item = chat[index];
                    final isUser = item['role'] == 'user';

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
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(item['content'] ?? ''),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (loading) const LinearProgressIndicator(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatInput,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Ask something...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => send(),
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget notesPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: itemInput,
                  decoration: const InputDecoration(
                    hintText: 'Write a note',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => addNote(),
                ),
              ),
              IconButton(
                onPressed: addNote,
                icon: const Icon(Icons.add),
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
                  onPressed: () async {
                    setState(() => notes.removeAt(index));
                    await save();
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: itemInput,
                  decoration: const InputDecoration(
                    hintText: 'Add a task',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => addTask(),
                ),
              ),
              IconButton(
                onPressed: addTask,
                icon: const Icon(Icons.add_task),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];

              return CheckboxListTile(
                title: Text(task['title']?.toString() ?? ''),
                value: task['completed'] == true,
                onChanged: (value) async {
                  setState(() {
                    task['completed'] = value ?? false;
                  });
                  await save();
                },
                secondary: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    setState(() => tasks.removeAt(index));
                    await save();
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
    final pages = [
      chatPage(),
      notesPage(),
      tasksPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal AI Agent'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) {
          setState(() {
            tab = index;
            itemInput.clear();
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'AI Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
        ],
      ),
    );
  }
}
