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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const PlaceholderHomeScreen(), // Registra a rota que estava faltando!
        // '/cadastro': (context) => const CadastroScreen(), // Quando tiver a tela de cadastro, descomente aqui
      },
    );
  }
}

// Tela Provisória para o fluxo de Login funcionar e não quebrar o Navigator
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MesclaInvest - Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false, // Remove o botão de voltar após o login
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 100, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Login efetuado com sucesso!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            SizedBox(height: 8),
            Text(
              'A rota /home respondeu corretamente.',
              style: TextStyle(fontSize: 16, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}