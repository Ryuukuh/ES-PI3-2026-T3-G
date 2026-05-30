import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/startup_details_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'theme/app_colors.dart';

void main() async {
  // Garante o vínculo com os recursos nativos do sistema operacional antes de ligar o Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização assíncrona do ecossistema Firebase na nuvem com opções geradas
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/cadastro': (context) => const RegisterScreen(),
        '/catalogo': (context) => const CatalogScreen(),
        '/perfil': (context) => const ProfileScreen(),
        '/carteira': (context) => const PortfolioScreen(),
        '/startup-detalhes': (context) => const StartupDetailsScreen(),
        '/esqueci-senha': (context) => const ForgotPasswordScreen(),
      },
    );
  }
}
