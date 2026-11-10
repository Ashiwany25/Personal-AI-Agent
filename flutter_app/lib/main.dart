import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = 'https://ubjihxctiujchazrlnyv.supabase.co';
const supabaseKey = 'sb_publishable_qMh2cZsHZZsRP_ide1v7Hw_s8Tsep1S';
const backendUrl = 'https://ashiwany-personal-ai-api.onrender.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(const PersonalAiApp());
}

class PersonalAiApp extends StatelessWidget {
  const PersonalAiApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Personal AI Agent',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: const AuthGate(),
      );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? subscription;

  @override
  void initState() {
    super.initState();
    subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session == null
        ? const LoginPage()
        : AgentHome(key: ValueKey(session.user.id), userId: session.user.id);
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        final response = await auth.signUp(email: email, password: password);
        showMessage(response.session == null
            ? 'Check your email for a verification link, then log in.'
            : 'Account created successfully.');
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
    } on AuthException catch (error) {
      showMessage(error.message);
    } catch (_) {
      showMessage('Unable to connect. Please try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.smart_toy_rounded,
                      size: 76, color: Colors.indigo),
                  const SizedBox(height: 16),
                  const Text('Personal AI Agent',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(signup ? 'Create your personal account' : 'Welcome back'),
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
                        onPressed: () =>
                            setState(() => hidePassword = !hidePassword),
                        icon: Icon(hidePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
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
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(signup ? 'Sign Up' : 'Log In'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => setState(() => signup = !signup),
                    child: Text(signup
                        ? 'Already have an account? Log In'
                        : 'New user? Create an account'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

class AgentHome extends StatefulWidget {
  final String userId;
  const AgentHome({super.key, required this.userId});

  @override
  State<AgentHome> createState() => _AgentHomeState();
}

class _AgentHomeState extends State<AgentHome> {
  final chatInput = TextEditingController();
  final noteInput = TextEditingController();
  final taskInput = TextEditingController();
  final client = Supabase.instance.client;

  int tab = 0;
  bool sending = false;
  bool refreshing = true;
  bool savingNote = false;
  bool savingTask = false;
  List<Map<String, dynamic>> chat = [];
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() {
    super.initState();
    refreshAll();
  }

  @override
  void dispose() {
    chatInput.dispose();
    noteInput.dispose();
    taskInput.dispose();
    super.dispose();
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String readableError(Object error) {
    if (error is PostgrestException) {
      return 'Cloud storage error: ${error.message}';
    }
    if (error is AuthException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> refreshAll() async {
    if (!mounted) return;
    setState(() => refreshing = true);
    try {
      // Each query is also restricted by Supabase RLS.
      final results = await Future.wait([
        client.from('conversations').select('id,user_id,role,content,created_at')
            .eq('user_id', widget.userId).order('created_at', ascending: true),
        client.from('notes').select('id,user_id,content,created_at')
            .eq('user_id', widget.userId).order('created_at', ascending: false),
        client.from('tasks').select('id,user_id,title,is_completed,created_at')
            .eq('user_id', widget.userId).order('created_at', ascending: false),
      ]);
      if (!mounted) return;
      setState(() {
        chat = (results[0] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        notes = (results[1] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
        tasks = (results[2] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (error) {
      message('Unable to load cloud data. ${readableError(error)}');
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Future<void> send() async {
    final text = chatInput.text.trim();
    if (text.isEmpty || sending || refreshing) return;
    setState(() => sending = true);
    try {
      final session = client.auth.currentSession;
      if (session == null) throw Exception('Please log in again.');
      var accessToken = session.accessToken;
      if (session.isExpired) {
        final renewed = await client.auth.refreshSession();
        if (renewed.session == null) {
          throw Exception('Session expired. Please log in again.');
        }
        accessToken = renewed.session!.accessToken;
      }

      // Persist the user's message before calling Gemini.
      final inserted = await client.from('conversations').insert({
        'user_id': widget.userId,
        'role': 'user',
        'content': text,
      }).select('id,user_id,role,content,created_at').single();
      if (!mounted) return;
      setState(() => chat.add(Map<String, dynamic>.from(inserted)));
      chatInput.clear();

      final history = chat.map((e) => {
        'role': e['role'],
        'content': e['content'],
      }).toList();
      final recent = history.length > 12
          ? history.sublist(history.length - 12)
          : history;
      final response = await http.post(
        Uri.parse('$backendUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'messages': recent}),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 401) {
        throw Exception('Session expired. Please log in again.');
      }
      if (response.statusCode != 200) {
        throw Exception('AI service error (${response.statusCode}). Please try again.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = (data['reply'] ?? '').toString().trim();
      final savedReply = await client.from('conversations').insert({
        'user_id': widget.userId,
        'role': 'assistant',
        'content': reply.isEmpty ? 'No response generated.' : reply,
      }).select('id,user_id,role,content,created_at').single();
      if (!mounted) return;
      setState(() => chat.add(Map<String, dynamic>.from(savedReply)));
    } catch (error) {
      message(readableError(error));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> addNote() async {
    final text = noteInput.text.trim();
    if (text.isEmpty || savingNote || refreshing) return;
    setState(() => savingNote = true);
    try {
      final row = await client.from('notes').insert({
        'user_id': widget.userId,
        'content': text,
      }).select('id,user_id,content,created_at').single();
      if (!mounted) return;
      setState(() => notes.insert(0, Map<String, dynamic>.from(row)));
      noteInput.clear();
    } catch (error) {
      message(readableError(error));
    } finally {
      if (mounted) setState(() => savingNote = false);
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await client.from('notes').delete()
          .eq('id', id).eq('user_id', widget.userId);
      if (!mounted) return;
      setState(() => notes.removeWhere((e) => e['id'] == id));
    } catch (error) {
      message(readableError(error));
    }
  }

  Future<void> addTask() async {
    final text = taskInput.text.trim();
    if (text.isEmpty || savingTask || refreshing) return;
    setState(() => savingTask = true);
    try {
      final row = await client.from('tasks').insert({
        'user_id': widget.userId,
        'title': text,
        'is_completed': false,
      }).select('id,user_id,title,is_completed,created_at').single();
      if (!mounted) return;
      setState(() => tasks.insert(0, Map<String, dynamic>.from(row)));
      taskInput.clear();
    } catch (error) {
      message(readableError(error));
    } finally {
      if (mounted) setState(() => savingTask = false);
    }
  }

  Future<void> updateTask(String id, bool value) async {
    try {
      final row = await client.from('tasks').update({'is_completed': value})
          .eq('id', id).eq('user_id', widget.userId)
          .select('id,user_id,title,is_completed,created_at').single();
      if (!mounted) return;
      setState(() {
        final index = tasks.indexWhere((e) => e['id'] == id);
        if (index >= 0) tasks[index] = Map<String, dynamic>.from(row);
      });
    } catch (error) {
      message(readableError(error));
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await client.from('tasks').delete()
          .eq('id', id).eq('user_id', widget.userId);
      if (!mounted) return;
      setState(() => tasks.removeWhere((e) => e['id'] == id));
    } catch (error) {
      message(readableError(error));
    }
  }

  Future<void> logout() async {
    try {
      await client.auth.signOut();
    } catch (_) {
      message('Unable to log out. Please try again.');
    }
  }

  Widget chatPage() => Column(children: [
        Expanded(
          child: chat.isEmpty
              ? const Center(child: Text('Ask your AI assistant anything!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: chat.length,
                  itemBuilder: (context, index) {
                    final item = chat[index];
                    final isUser = item['role'] == 'user';
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight : Alignment.centerLeft,
                      child: Card(
                        color: isUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text((item['content'] ?? '').toString()),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (sending) const LinearProgressIndicator(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: chatInput,
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Ask something...', border: OutlineInputBorder()),
                  onSubmitted: (_) => send(),
                ),
              ),
              IconButton(
                onPressed: sending || refreshing ? null : send,
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]);

  Widget notesPage() => Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: noteInput,
              decoration: const InputDecoration(
                  hintText: 'Write a note', border: OutlineInputBorder()),
              onSubmitted: (_) => addNote(),
            )),
            IconButton(
              onPressed: savingNote || refreshing ? null : addNote,
              icon: const Icon(Icons.add),
            ),
          ]),
        ),
        Expanded(child: ListView.builder(
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return ListTile(
              title: Text((note['content'] ?? '').toString()),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => deleteNote(note['id'].toString()),
              ),
            );
          },
        )),
      ]);

  Widget tasksPage() => Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(
              controller: taskInput,
              decoration: const InputDecoration(
                  hintText: 'Add a task', border: OutlineInputBorder()),
              onSubmitted: (_) => addTask(),
            )),
            IconButton(
              onPressed: savingTask || refreshing ? null : addTask,
              icon: const Icon(Icons.add_task),
            ),
          ]),
        ),
        Expanded(child: ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            final id = task['id'].toString();
            return CheckboxListTile(
              title: Text((task['title'] ?? '').toString()),
              value: task['is_completed'] == true,
              onChanged: (value) => updateTask(id, value ?? false),
              secondary: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => deleteTask(id),
              ),
            );
          },
        )),
      ]);

  @override
  Widget build(BuildContext context) {
    final pages = [chatPage(), notesPage(), tasksPage()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal AI Agent'),
        actions: [
          IconButton(
            tooltip: 'Refresh cloud data',
            onPressed: refreshing || sending ? null : refreshAll,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: refreshing
          ? const Center(child: CircularProgressIndicator())
          : pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), label: 'AI Chat'),
          NavigationDestination(
              icon: Icon(Icons.note_alt_outlined), label: 'Notes'),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Tasks'),
        ],
      ),
    );
  }
}
