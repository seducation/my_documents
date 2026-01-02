import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/editor_provider.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const MedicalNotesApp());
}

class MedicalNotesApp extends StatelessWidget {
  const MedicalNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EditorProvider()),
      ],
      child: MaterialApp(
        title: 'My Documents',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
          useMaterial3: true,
          textTheme: GoogleFonts.interTextTheme(),
          scaffoldBackgroundColor: const Color(
              0xFFF5F5F5), // Light Grey background for contrast with A4 White
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
