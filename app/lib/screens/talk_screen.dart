import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/state/conversation_state.dart';
import 'package:app/state/providers.dart';
import 'package:app/screens/persona_picker_screen.dart';
import 'package:app/screens/settings_screen.dart';

class TalkScreen extends ConsumerWidget {
  const TalkScreen({super.key});

  bool _active(TalkPhase p) =>
      p == TalkPhase.listening || p == TalkPhase.thinking || p == TalkPhase.speaking;

  String _hint(TalkPhase p) => switch (p) {
        TalkPhase.idle => 'Tap to start talking',
        TalkPhase.listening => 'Listening…',
        TalkPhase.thinking => 'Thinking…',
        TalkPhase.speaking => 'Speaking…',
        TalkPhase.error => 'Tap to start again',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationControllerProvider);
    final controller = ref.read(conversationControllerProvider.notifier);
    final active = _active(state.phase);

    return Scaffold(
      appBar: AppBar(
        title: Text('Companion — ${state.activePersonaId}'),
        actions: [
          IconButton(
              icon: const Icon(Icons.people),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PersonaPickerScreen()))),
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final m in state.messages)
                  Align(
                    alignment: m.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: m.role == 'user' ? Colors.blue.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(m.text),
                    ),
                  ),
                if (state.partialTranscript.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(state.partialTranscript,
                          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    ),
                  ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_hint(state.phase), style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    if (active) {
                      controller.stopConversation();
                    } else {
                      controller.startConversation();
                    }
                  },
                  child: CircleAvatar(
                    radius: 52,
                    backgroundColor: active ? Colors.red : Colors.green,
                    child: Icon(
                      active ? Icons.stop : Icons.mic,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  active ? 'End conversation' : 'Start conversation',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
