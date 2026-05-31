// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Tela de Login com suporte a MFA

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();

  bool _isLoading = false;
  bool _showMfaStep = false;
  bool _showPassword = false;
  String _pendingUid = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final url = Uri.parse('http://localhost:3000/api/login');

    try {
      final resposta = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'senha': _passwordController.text,
        }),
      );

      final dados = jsonDecode(resposta.body);

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        // MFA requerido
        if (dados['mfaRequired'] == true) {
          setState(() {
            _pendingUid = dados['uid']?.toString() ?? '';
            _showMfaStep = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Código de verificação enviado para seu e-mail.'),
              backgroundColor: Colors.blue,
            ),
          );
          return;
        }

        await _finalizarLogin(dados);
      } else {
        _mostrarErro(dados['error'] ?? 'Erro ao efetuar login.');
      }
    } catch (_) {
      if (!mounted) return;
      _mostrarErro('Não foi possível conectar ao servidor backend.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verificarMfa() async {
    final codigo = _mfaCodeController.text.trim();
    if (codigo.length != 6) {
      _mostrarErro('O código deve ter 6 dígitos.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/mfa/verificar-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': _pendingUid, 'codigo': codigo}),
      );

      final dados = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _finalizarLogin(dados);
      } else {
        _mostrarErro(dados['error'] ?? 'Código inválido.');
      }
    } catch (_) {
      if (!mounted) return;
      _mostrarErro('Não foi possível conectar ao servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizarLogin(Map<String, dynamic> dados) async {
    final usuarioRaw = dados['usuario'] as Map<String, dynamic>;
    final usuarioData = Map<String, dynamic>.from(usuarioRaw);

    final saldoFicticioValue = usuarioData['saldoFicticio'];
    final saldoFicticio = saldoFicticioValue is num
        ? saldoFicticioValue.toDouble()
        : double.tryParse(saldoFicticioValue?.toString() ?? '0.0') ?? 0.0;

    final currentUser = {
      'uid': dados['uid']?.toString() ?? '',
      'nomeCompleto': usuarioData['nomeCompleto']?.toString() ?? 'Investidor',
      'email': usuarioData['email']?.toString() ?? '',
      'cpf': usuarioData['cpf']?.toString() ?? '',
      'telefone': usuarioData['telefone']?.toString() ?? '',
      'saldoFicticio': saldoFicticio,
      'tokens': usuarioData['tokens'] ?? {},
      'historicoAportes': usuarioData['historicoAportes'] ?? [],
      'mfaEnabled': usuarioData['mfaEnabled'] ?? false,
    };

    await SessionService.saveUser(currentUser);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bem-vindo, ${usuarioData['nomeCompleto']}!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushReplacementNamed(context, '/home', arguments: currentUser);
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _showMfaStep ? _buildMfaStep() : _buildLoginStep(),
        ),
      ),
    );
  }

  Widget _buildLoginStep() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.trending_up_rounded, size: 80, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'MesclaInvest',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Simulador de Tokenização de Startups',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textLight),
          ),
          const SizedBox(height: 48),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.email, color: AppColors.primary),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Por favor, informe seu e-mail.';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Senha',
              prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Por favor, informe sua senha.';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/esqueci-senha'),
              child: const Text(
                'Esqueci minha senha',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _fazerLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Entrar', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/cadastro'),
            child: const Text(
              'Não tem uma conta? Cadastre-se',
              style: TextStyle(color: AppColors.primary, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMfaStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.security, size: 72, color: AppColors.primary),
        const SizedBox(height: 16),
        const Text(
          'Verificação em dois fatores',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Insira o código de 6 dígitos enviado para o seu e-mail.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _mfaCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, letterSpacing: 10, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            labelText: 'Código MFA',
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _verificarMfa,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Verificar', style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() {
            _showMfaStep = false;
            _mfaCodeController.clear();
          }),
          child: const Text('Voltar ao login'),
        ),
      ],
    );
  }
}
