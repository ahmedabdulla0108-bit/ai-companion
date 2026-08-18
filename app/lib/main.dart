import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/screens/talk_screen.dart';

void main() => runApp(const ProviderScope(child: CompanionApp()));

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'Voice Companion',
        home: TalkScreen(),
      );
}
