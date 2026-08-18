import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/persona.dart';
import 'package:app/state/providers.dart';

class PersonaPickerScreen extends ConsumerWidget {
  const PersonaPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.read(backendClientProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a companion')),
      body: FutureBuilder<List<Persona>>(
        future: backend.listPersonas(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: [
              for (final p in snap.data!)
                ListTile(
                  title: Text(p.name),
                  subtitle: Text(p.description),
                  onTap: () {
                    ref.read(conversationControllerProvider.notifier).setPersona(p.id);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
