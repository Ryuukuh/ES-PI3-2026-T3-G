// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa
// Componente: Tela de Recuperação de Senha

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Etapas: 0 = inserir email, 1 = inserir código, 2 = nova senha
  int _step = 0;

  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmSenhaController = TextEditingController();

  bool _isLoading = false;
  bool _showNovaSenha = false;
  bool _showConfirmSenha = false;
  String _email = '';

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _novaSenhaController.dispose();
    _confirmSenhaController.dispose();
    super.dispose();
  }

  Future<void> _solicitarCodigo() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Informe um e-mail válido.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await http.post(
        Uri.parse('http://localhost:3000/api/esqueci-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (!mounted) return;

      // A rota sempre retorna 200 por segurança
      setState(() {
        _email = email;
        _step = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código enviado para o seu e-mail!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Não foi possível conectar ao servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verificarCodigo() async {
    final codigo = _codigoController.text.trim();
    if (codigo.length != 6) {
      _showError('O código deve ter 6 dígitos.');
      return;
    }

    // Apenas avança para a etapa de nova senha
    // A validação real ocorre ao salvar
    setState(() => _step = 2);
  }

  Future<void> _redefinirSenha() async {
    final novaSenha = _novaSenhaController.text;
    final confirmSenha = _confirmSenhaController.text;

    if (novaSenha.length < 6) {
      _showError('A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (novaSenha != confirmSenha) {
      _showError('As senhas não conferem.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/resetar-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _email,
          'codigo': _codigoController.text.trim(),
          'novaSenha': novaSenha,
        }),
      );

      if (!mounted) return;

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha redefinida com sucesso! Faça login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        _showError(body['error'] ?? 'Erro ao redefinir senha.');
        // Volta para o passo do código se o código for inválido
        setState(() => _step = 1);
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Não foi possível conectar ao servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recuperar Senha'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              _buildStepIndicator(),
              const SizedBox(height: 32),
              if (_step == 0) _buildStepEmail(),
              if (_step == 1) _buildStepCodigo(),
              if (_step == 2) _buildStepNovaSenha(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _step;
        final done = i < _step;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 36 : 28,
              height: active ? 36 : 28,
              decoration: BoxDecoration(
                color: done || active ? AppColors.primary : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: active ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: active ? 16 : 13,
                        ),
                      ),
              ),
            ),
            if (i < 2)
              Container(
                width: 40,
                height: 2,
                color: i < _step ? AppColors.primary : Colors.grey[300],
              ),
          ],
        );
      }),
    );
  }

  Widget _buildStepEmail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Informe seu e-mail cadastrado',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enviaremos um código de verificação para redefinir sua senha.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'E-mail',
            prefixIcon: Icon(Icons.email, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _solicitarCodigo,
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
              : const Text('Enviar código', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildStepCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Insira o código recebido',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Verifique o e-mail enviado para $_email.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _codigoController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            labelText: 'Código de 6 dígitos',
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _verificarCodigo,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Confirmar código', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text('Não recebi o código — tentar novamente'),
        ),
      ],
    );
  }

  Widget _buildStepNovaSenha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Crie sua nova senha',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'A nova senha deve ter pelo menos 6 caracteres.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _novaSenhaController,
          obscureText: !_showNovaSenha,
          decoration: InputDecoration(
            labelText: 'Nova senha',
            prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_showNovaSenha ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showNovaSenha = !_showNovaSenha),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmSenhaController,
          obscureText: !_showConfirmSenha,
          decoration: InputDecoration(
            labelText: 'Confirmar nova senha',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_showConfirmSenha ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showConfirmSenha = !_showConfirmSenha),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _redefinirSenha,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Redefinir senha', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }
}
