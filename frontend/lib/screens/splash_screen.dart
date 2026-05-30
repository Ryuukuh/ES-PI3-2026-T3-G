import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/session_service.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final storedUser = await SessionService.loadUser();

    if (storedUser == null) {
      _navigateToLogin();
      return;
    }

    final uid = storedUser['uid']?.toString() ?? '';
    if (uid.isEmpty) {
      await SessionService.clearUser();
      _navigateToLogin();
      return;
    }

    try {
      final url = Uri.parse('http://localhost:3000/api/usuario/$uid');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final usuario = body['usuario'] ?? {};
        final updatedUser = {
          ...storedUser,
          ...Map<String, dynamic>.from(usuario),
        };
        await SessionService.saveUser(updatedUser);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home', arguments: updatedUser);
        return;
      }
    } catch (_) {
      // fallback para abrir a home com os dados salvos localmente
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home', arguments: storedUser);
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Carregando sessão...', style: TextStyle(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
