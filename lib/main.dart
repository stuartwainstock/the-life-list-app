import 'package:flutter/material.dart';
import 'screens/home_shell.dart';

void main() {
  runApp(const GoBirderApp());
}

class GoBirderApp extends StatelessWidget {
  const GoBirderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoBirder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
