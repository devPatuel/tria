import 'package:flutter/material.dart';

void main() => runApp(const TriaApp());

/// Root widget of the application.
///
/// Holds only theming and the initial route; all behaviour lives in the
/// controllers under `lib/state/`.
class TriaApp extends StatelessWidget {
  const TriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tría',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('Tría'))),
    );
  }
}
