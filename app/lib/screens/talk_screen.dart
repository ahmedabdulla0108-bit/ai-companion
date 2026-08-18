import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/state/conversation_state.dart';
import 'package:app/state/providers.dart';
import 'package:app/screens/persona_picker_screen.dart';
import 'package:app/screens/settings_screen.dart';

class TalkScreen extends ConsumerWidget {
  const TalkScreen({super.key});

  String _hint(TalkPhase p) => switch (p) {
        TalkPhase.idle => 'Hold to talk',
        TalkPhase.listening => 'Listening…',
        TalkPhase.thinking => 'Thinking…',
        TalkPhase.speaking => 'Speaking…',
        TalkPhase.error => 'Tap to retry',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationControllerProvider);
    final controller = ref.read(conversationControllerProvider.notifier);
    final stt = ref.read(sttServiceProvider);

    Future<void> onPressStart() async {
      final ok = await stt.init();
      if (!ok) return;
      controller.setListening();
      await stt.startListening(controller.setPartial);
    }

    Future<void> onPressEnd() async {
      final finalText = await stt.stopListening();
      await controller.submitUserText(finalText);
    }

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
                  Text(state.partialTranscript, style: const TextStyle(color: Colors.grey)),
                if (state.errorMessage != null)
                  Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(_hint(state.phase)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTapDown: (_) => onPressStart(),
                  onTapUp: (_) => onPressEnd(),
                  onTapCancel: onPressEnd,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor:
                        state.phase == TalkPhase.listening ? Colors.red : Colors.blue,
                    child: const Icon(Icons.mic, size: 40, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
