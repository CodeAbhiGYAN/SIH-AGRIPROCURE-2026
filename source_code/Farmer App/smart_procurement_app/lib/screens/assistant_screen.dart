import 'package:flutter/material.dart';
import '../main.dart';

class AssistantScreen extends StatefulWidget {
  final AppState state;
  const AssistantScreen({super.key, required this.state});

  @override
  State<AssistantScreen> createState() => _AssistantState();
}

class _AssistantState extends State<AssistantScreen> {
  final controller = TextEditingController();
  final messages = <({bool user, String text})>[];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final q = controller.text.trim();
    if (q.isEmpty) return;
    final context = {...widget.state.assistantContext, 'language': widget.state.language};
    final ans = await widget.state.ai.answer(q, context: context);
    if (!mounted) return;
    setState(() {
      messages.add((user: true, text: q));
      messages.add((user: false, text: ans));
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final suggestions = state.language == 'Hindi'
        ? ['मैं कब निकलूं?', 'मेरा केंद्र क्यों बदला?', 'मेरी उपस्थिति कैसे दर्ज करें?', 'मेरा भुगतान कब आएगा?']
        : ['When should I leave?', 'Why was my centre changed?', 'How do I mark attendance?', 'What is my payment status?'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(state.t('assistant_title'), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(state.t('assistant_help')),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ActionChip(label: Text(suggestions[i]), onPressed: () { controller.text = suggestions[i]; _ask(); }),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: messages.length,
            itemBuilder: (_, i) {
              final message = messages[i];
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: message.user ? Alignment.centerRight : Alignment.centerLeft,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(message.text),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => _ask(),
                    decoration: InputDecoration(hintText: state.t('ask_something')),
                  ),
                ),
                IconButton(onPressed: _ask, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
