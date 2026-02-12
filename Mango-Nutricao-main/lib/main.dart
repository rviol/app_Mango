// arquivo: main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'widgets/auth_check.dart';

void main() async {
  // 1. Garante que o Flutter carregue os plugins antes de iniciar
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ATIVA O CACHE LOCAL (Torna o app instantâneo)
  FirebaseDatabase.instance.setPersistenceEnabled(true);

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp( // Removi o const aqui para permitir alterar theme se quiser
      debugShowCheckedModeBanner: false,
      title: 'App Nutrição',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple, // Adicionei um tema básico roxo
        useMaterial3: true,
      ),
      home: const AuthCheck(),
    );
  }
}