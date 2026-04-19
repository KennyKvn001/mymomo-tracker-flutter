import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShadApp.material(
      title: 'MoMo Transaction Tracker',
      debugShowCheckedModeBanner: false,
      materialThemeBuilder: (context, theme) {
        return theme.copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        );
      },
      home: HomeScreen(),
    );
  }
}
