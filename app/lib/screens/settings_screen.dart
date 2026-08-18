import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/app_settings.dart';
import 'package:app/state/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController url, token, user;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    url = TextEditingController(text: s.backendUrl);
    token = TextEditingController(text: s.bearerToken);
    user = TextEditingController(text: s.userId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(controller: url, decoration: const InputDecoration(labelText: 'Backend URL (http://<pc-ip>:8000)')),
            TextField(controller: token, decoration: const InputDecoration(labelText: 'Bearer token')),
            TextField(controller: user, decoration: const InputDecoration(labelText: 'Your user id')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await ref.read(settingsProvider.notifier).save(AppSettings(
                      backendUrl: url.text.trim(),
                      bearerToken: token.text.trim(),
                      userId: user.text.trim().isEmpty ? 'me' : user.text.trim(),
                    ));
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ]),
        ),
      );
}
