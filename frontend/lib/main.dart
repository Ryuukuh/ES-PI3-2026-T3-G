// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Ponto de entrada do aplicativo e configuração de rotas
//
// Este é o primeiro arquivo executado quando o app abre.
// Ele inicializa o Firebase e define todas as rotas de navegação do app.

// Importa o kit principal de widgets visuais do Flutter (botões, textos, telas, etc.)
import 'package:flutter/material.dart';

// Importa o Firebase Core — obrigatório antes de usar qualquer serviço do Firebase
import 'package:firebase_core/firebase_core.dart';

// Importa as configurações do Firebase geradas automaticamente pelo FlutterFire CLI
// Contém as chaves de API para Android, iOS e outras plataformas
import 'firebase_options.dart';

// Importa cada tela do app para que possam ser usadas nas rotas de navegação
import 'screens/login_screen.dart';           // Tela de login com e-mail e senha
import 'screens/register_screen.dart';        // Tela de cadastro de novo usuário
import 'screens/home_screen.dart';            // Dashboard principal após o login
import 'screens/catalog_screen.dart';         // Catálogo de startups disponíveis
import 'screens/profile_screen.dart';         // Perfil e configurações do usuário
import 'screens/portfolio_screen.dart';       // Carteira de investimentos e gráficos
import 'screens/startup_details_screen.dart'; // Detalhes, Q&A e simulador de aporte
import 'screens/splash_screen.dart';          // Tela de carregamento e verificação de sessão
import 'screens/forgot_password_screen.dart'; // Recuperação de senha por e-mail

// Importa as cores centralizadas do projeto (tema visual do MesclaInvest)
import 'theme/app_colors.dart';

// Ponto de entrada do app Flutter — sempre começa aqui.
// 'async' permite usar 'await' para esperar o Firebase inicializar antes de abrir a tela.
void main() async {
  // Garante que o Flutter está pronto para chamar código nativo do dispositivo
  // (câmera, armazenamento, etc.) antes de inicializar o Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase usando as configurações certas para a plataforma atual
  // (Android, iOS, Web, etc.). O 'await' faz o código esperar essa etapa terminar.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicia o app Flutter passando o widget raiz (MesclaInvestApp)
  runApp(const MesclaInvestApp());
}

// Widget raiz do aplicativo — envolve todo o app e define tema e rotas.
// 'StatelessWidget' significa que este widget não muda de aparência após ser criado.
class MesclaInvestApp extends StatelessWidget {
  const MesclaInvestApp({super.key});

  // O método 'build' descreve como o widget deve ser desenhado na tela.
  // É chamado pelo Flutter sempre que o widget precisa ser renderizado.
  @override
  Widget build(BuildContext context) {
    // MaterialApp é o widget de nível mais alto — configura tema, rotas e tela inicial
    return MaterialApp(
      // Nome do app exibido no gerenciador de tarefas do sistema operacional
      title: 'MesclaInvest',

      // Remove a faixa vermelha de "DEBUG" no canto da tela durante desenvolvimento
      debugShowCheckedModeBanner: false,

      // Define o tema visual global: cores, fontes e estilo padrão de todos os widgets
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background, // Fundo branco em todas as telas
        primaryColor: AppColors.primary,               // Azul escuro como cor principal
        useMaterial3: true,                            // Usa o design mais moderno do Material
      ),

      // Tela inicial exibida ao abrir o app — verifica se há sessão ativa
      home: const SplashScreen(),

      // Mapa de rotas nomeadas: associa uma string a uma tela.
      // Quando o código chama Navigator.pushNamed(context, '/login'),
      // o Flutter abre a LoginScreen automaticamente.
      routes: {
        '/login':            (context) => const LoginScreen(),          // Tela de login
        '/home':             (context) => const HomeScreen(),           // Dashboard principal
        '/cadastro':         (context) => const RegisterScreen(),       // Criar nova conta
        '/catalogo':         (context) => const CatalogScreen(),        // Catálogo de startups
        '/perfil':           (context) => const ProfileScreen(),        // Perfil do usuário
        '/carteira':         (context) => const PortfolioScreen(),      // Carteira de tokens
        '/startup-detalhes': (context) => const StartupDetailsScreen(), // Detalhes da startup
        '/esqueci-senha':    (context) => const ForgotPasswordScreen(), // Recuperação de senha
      },
    );
  }
}
