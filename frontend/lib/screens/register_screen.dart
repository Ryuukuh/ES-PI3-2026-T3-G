// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Tela de Cadastro de novo usuário

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // IMPORT NECESSÁRIO PARA OS FORMATADORES
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _cadastrarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse('http://localhost:3000/api/cadastro');

    try {
      final resposta = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nomeCompleto': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'cpf': _cpfController.text.replaceAll(RegExp(r'\D'), ''), 
          'telefone': _phoneController.text.replaceAll(RegExp(r'\D'), ''), 
          'senha': _passwordController.text,
        }),
      );

      final dados = jsonDecode(resposta.body);

      if (resposta.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso! Faça seu login.'), 
            backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context); 
      } else {
        if (!mounted) return;
        _mostrarErro(dados['error'] ?? 'Erro ao realizar o cadastro.');
      }
    } catch (e) {
      _mostrarErro('Não foi possível conectar ao servidor backend.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Criar Conta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cadastre-se para começar a simular seus investimentos.',
                style: TextStyle(fontSize: 16, color: AppColors.textLight),
              ),
              const SizedBox(height: 32),
              
              // Campo Nome
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
                  prefixIcon: Icon(Icons.person, color: AppColors.primary),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe seu nome completo.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo E-mail
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email, color: AppColors.primary),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe seu e-mail.';
                  }
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Informe um e-mail válido (exemplo@email.com).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo Telefone - Configurado para limitar e aceitar só números
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11, // IMPEDE DIGITAR MAIS DE 11 NÚMEROS
                inputFormatters: [FilteringTextInputFormatter.digitsOnly], // RECUSA LETRAS E SÍMBOLOS
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                  hintText: 'DDD + Número (ex: 19999999999)',
                  counterText: '', // Oculta o contador visual feio do Flutter
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe seu telefone.';
                  }
                  if (value.length < 10) {
                    return 'Telefone incompleto. Deve conter no mínimo 10 dígitos.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo CPF - Configurado para limitar e aceitar só números
              TextFormField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                maxLength: 11, // IMPEDE DIGITAR MAIS DE 11 DÍGITOS
                inputFormatters: [FilteringTextInputFormatter.digitsOnly], // RECUSA LETRAS E SÍMBOLOS
                decoration: const InputDecoration(
                  labelText: 'CPF',
                  prefixIcon: Icon(Icons.badge, color: AppColors.primary),
                  hintText: 'Apenas os 11 números',
                  counterText: '', // Oculta o contador visual feio do Flutter
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe seu CPF.';
                  }
                  if (value.length != 11) {
                    return 'O CPF deve conter exatamente 11 dígitos.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo Senha
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: Icon(Icons.lock, color: AppColors.primary),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Crie uma senha para sua segurança.';
                  }
                  if (value.length < 6) {
                    return 'A senha deve conter no mínimo 6 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Botão Cadastrar
              ElevatedButton(
                onPressed: _isLoading ? null : _cadastrarUsuario,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Cadastrar',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}