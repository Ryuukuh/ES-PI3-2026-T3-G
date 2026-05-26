import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // IMPORT DO FIRESTORE PARA O TESTE MANTIDO
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart'; // IMPORT DA TELA DE CADASTRO MANTIDO
import 'screens/home_screen.dart';     // IMPORT DA TELA HOME REAL ATIVADO
import '../theme/app_colors.dart';

void main() async {
  // Garante o vínculo com os recursos nativos do sistema operacional antes de ligar o Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização assíncrona do ecossistema Firebase na nuvem com opções geradas
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 🔥 CÓDIGO DE TESTE TEMPORÁRIO MANTIDO
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
        '/home': (context) => const HomeScreen(), // Apontando para a Home real com o Dashboard azul
        '/cadastro': (context) => const RegisterScreen(), // Apontando para a classe correta de cadastro
        
        // 🚀 NOVA ROTA ATIVADA: Evita que o botão "Explorar Mercado" fique sem ação
        '/catalogo': (context) => const PlaceholderCatalogo(), 
      },
    );
  }
}

// Tela provisória para o botão "Explorar Mercado" navegar sem dar erro de rota
class PlaceholderCatalogo extends StatelessWidget {
  const PlaceholderCatalogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Startups', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo[900],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 80, color: Colors.indigo),
            SizedBox(height: 16),
            Text(
              'Sucesso! O clique funcionou.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            SizedBox(height: 8),
            Text(
              'A tela do Catálogo (Issue #12) será desenvolvida aqui.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}