import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const PersonalAiApp());

class PersonalAiApp extends StatelessWidget {
  const PersonalAiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Personal AI Agent', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
    home: const AgentHome(),
  );
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
  final itemInput = TextEditingController();
  List<Map<String, String>> chat = [];
  List<String> notes = [];
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      url = p.getString('url') ?? '';
      chat = (jsonDecode(p.getString('chat') ?? '[]') as List).map((e) => Map<String, String>.from(e as Map)).toList();
      notes = List<String>.from(jsonDecode(p.getString('notes') ?? '[]'));
      tasks = (jsonDecode(p.getString('tasks') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }
  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('url', url);
    await p.setString('chat', jsonEncode(chat));
    await p.setString('notes', jsonEncode(notes));
    await p.setString('tasks', jsonEncode(tasks));
  }
  void alert(String msg) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); }
  Future<void> settings() async {
    final u = TextEditingController(text: url), t = TextEditingController(text: token);
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('AI backend settings'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Enter your backend URL and app access token, NOT the Gemini API key.'),
        TextField(controller: u, decoration: const InputDecoration(labelText: 'HTTPS backend URL')),
        TextField(controller: t, obscureText: true, decoration: const InputDecoration(labelText: 'App access token')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () { setState(() { url = u.text.trim().replaceFirst(RegExp(r'/+$'), ''); token = t.text.trim(); }); save(); Navigator.pop(context); }, child: const Text('Save'))],
    ));
    u.dispose(); t.dispose();
  }
  Future<void> send() async {
    final text = chatInput.text.trim();
    if (text.isEmpty || loading) return;
    if (!url.startsWith('https://') || token.isEmpty) { alert('Set an HTTPS backend URL and access token in Settings.'); return; }
    chatInput.clear();
    setState(() { chat.add({'role': 'user', 'content': text}); loading = true; });
    await save();
    try {
      final res = await http.post(Uri.parse('$url/chat'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'messages': chat.length > 12 ? chat.sublist(chat.length - 12) : chat}),
      ).timeout(const Duration(seconds: 45));
      if (res.statusCode != 200) throw Exception('Backend returned HTTP ${res.statusCode}');
      final reply = (jsonDecode(res.body) as Map<String, dynamic>)['reply'];
      if (reply is! String || reply.isEmpty) throw Exception('Empty AI response');
      if (mounted) setState(() => chat.add({'role': 'assistant', 'content': reply}));
    } catch (e) { alert('Chat failed: $e'); }
    finally { if (mounted) setState(() => loading = false); await save(); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Personal AI Agent'), actions: [IconButton(onPressed: settings, icon: const Icon(Icons.settings))]),
    body: IndexedStack(index: tab, children: [chatPage(), notesPage(), tasksPage()]),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
      NavigationDestination(icon: Icon(Icons.chat_outlined), label: 'AI Chat'),
      NavigationDestination(icon: Icon(Icons.note_outlined), label: 'Notes'),
      NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Tasks'),
    ]),
  );
  Widget chatPage() => Column(children: [
    if (url.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Connect your secure Gemini backend in Settings to enable chat.')),
    Expanded(child: ListView.builder(itemCount: chat.length, itemBuilder: (context, i) {
      final m = chat[i]; final isUser = m['role'] == 'user';
      return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: Card(
        color: isUser ? Theme.of(context).colorScheme.primaryContainer : null,
        margin: const EdgeInsets.all(8), child: Padding(padding: const EdgeInsets.all(12), child: Text(m['content'] ?? '')),
      ));
    })),
    if (loading) const LinearProgressIndicator(),
    Padding(padding: const EdgeInsets.all(8), child: Row(children: [
      Expanded(child: TextField(controller: chatInput, decoration: const InputDecoration(hintText: 'Ask Gemini...', border: OutlineInputBorder()))),
      IconButton(onPressed: loading ? null : send, icon: const Icon(Icons.send)),
      IconButton(tooltip: 'Clear chat', onPressed: () { setState(() => chat.clear()); save(); }, icon: const Icon(Icons.delete_sweep)),
    ])),
  ]);
  Widget entry(String label, VoidCallback onAdd) => Padding(padding: const EdgeInsets.all(8), child: Row(children: [
    Expanded(child: TextField(controller: itemInput, decoration: InputDecoration(hintText: label, border: const OutlineInputBorder()))),
    IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle)),
  ]));
  Widget notesPage() => Column(children: [
    entry('New note', () { if (itemInput.text.trim().isEmpty) return; setState(() { notes.insert(0, itemInput.text.trim()); itemInput.clear(); }); save(); }),
    Expanded(child: ListView.builder(itemCount: notes.length, itemBuilder: (context, i) => ListTile(title: Text(notes[i]), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { setState(() => notes.removeAt(i)); save(); })))),
  ]);
  Widget tasksPage() => Column(children: [
    entry('New task', () { if (itemInput.text.trim().isEmpty) return; setState(() { tasks.insert(0, {'title': itemInput.text.trim(), 'done': false}); itemInput.clear(); }); save(); }),
    Expanded(child: ListView.builder(itemCount: tasks.length, itemBuilder: (context, i) => ListTile(
      leading: Checkbox(value: tasks[i]['done'] == true, onChanged: (v) { setState(() => tasks[i]['done'] = v ?? false); save(); }),
      title: Text(tasks[i]['title'] as String),
      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { setState(() => tasks.removeAt(i)); save(); }),
    ))),
  ]);
  @override
  void dispose() { chatInput.dispose(); itemInput.dispose(); super.dispose(); }
}
