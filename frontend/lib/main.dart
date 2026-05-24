import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 1. IMPORT DO FIRESTORE PARA O TESTE
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'theme/app_colors.dart';

void main() async {
  // Garante o vínculo com os recursos nativos do sistema operacional antes de ligar o Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização assíncrona do ecossistema Firebase na nuvem com opções geradas
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 🔥 2. CÓDIGO DE TESTE TEMPORÁRIO
  // Isso vai tentar criar uma coleção chamada 'teste_conexao' e salvar um documento lá dentro
  try {
    await FirebaseFirestore.instance.collection('teste_conexao').add({
      'status': 'Conectado com sucesso!',
      'horario': DateTime.now().toString(),
      'desenvolvedor': 'Rafael',
    });
    print('✅ TESTE DO FIREBASE: Dados enviados com sucesso para a nuvem!');
  } catch (e) {
    print('❌ TESTE DO FIREBASE: Erro ao enviar dados: $e');
  }
  
  runApp(const MesclaInvestApp());
}

class MesclaInvestApp extends StatelessWidget {
  const MesclaInvestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MesclaInvest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        useMaterial3: true,
      ),
      // Inicia o fluxo do aplicativo direto pela nossa tela de login refatorada
      home: const LoginScreen(),
    );
  }
}