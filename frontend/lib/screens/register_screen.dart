// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Tela de Cadastro de novo usuário
//
// Esta tela apresenta o formulário de criação de conta.
// Coleta: Nome, E-mail, Telefone, CPF e Senha.
// Valida todos os campos antes de enviar para o backend.

// Importa o kit de widgets visuais do Flutter
import 'package:flutter/material.dart';

// Importa formatadores de texto — usado para aceitar somente números em alguns campos
import 'package:flutter/services.dart';

// Importa o pacote HTTP para enviar os dados do cadastro ao backend
import 'package:http/http.dart' as http;

// Importa ferramentas para codificar/decodificar JSON
import 'dart:convert';

// Importa as cores do tema do projeto
import '../theme/app_colors.dart';

// StatefulWidget porque exibe spinner de carregamento durante o cadastro
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Chave global do formulário — permite validar todos os campos com um único comando
  final _formKey = GlobalKey<FormState>();

  // Controladores de cada campo de texto — permitem ler o valor digitado
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controla se o spinner de carregamento está visível durante o envio
  bool _isLoading = false;

  // Libera os controladores da memória quando a tela é fechada (evita memory leaks)
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Envia os dados do formulário ao backend para criar a conta.
  // Só executa se todos os campos passarem na validação.
  Future<void> _cadastrarUsuario() async {
    // validate() checa todos os campos — retorna false se algum tiver erro
    if (!_formKey.currentState!.validate()) return;

    // Ativa o spinner de carregamento enquanto aguarda a resposta do servidor
    setState(() { _isLoading = true; });

    final url = Uri.parse('http://localhost:3000/api/cadastro');

    try {
      // Envia os dados via POST para o endpoint de cadastro
      final resposta = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nomeCompleto': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          // replaceAll remove qualquer caractere não-numérico do CPF e telefone
          // Ex: "123.456.789-01" → "12345678901"
          'cpf': _cpfController.text.replaceAll(RegExp(r'\D'), ''),
          'telefone': _phoneController.text.replaceAll(RegExp(r'\D'), ''),
          'senha': _passwordController.text,
        }),
      );

      // Decodifica a resposta JSON do backend
      final dados = jsonDecode(resposta.body);

      // HTTP 201 = Created (conta criada com sucesso)
      if (resposta.statusCode == 201) {
        if (!mounted) return;
        // Exibe mensagem de sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta criada com sucesso! Faça seu login.'),
            backgroundColor: Colors.green,
          ),
        );
        // Volta para a tela anterior (tela de Login)
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        // Exibe o erro retornado pelo servidor (ex: "e-mail já cadastrado")
        _mostrarErro(dados['error'] ?? 'Erro ao realizar o cadastro.');
      }
    } catch (e) {
      // Erro de conexão — backend offline ou sem internet
      _mostrarErro('Não foi possível conectar ao servidor backend.');
    } finally {
      // Desativa o spinner independente do resultado
      setState(() { _isLoading = false; });
    }
  }

  // Exibe uma mensagem de erro como SnackBar na parte inferior da tela
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
      // Barra superior apenas com o botão de voltar (sem título)
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0, // Remove a sombra da barra
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context), // Volta para o Login
        ),
      ),
      body: SingleChildScrollView(
        // Permite rolar caso o teclado cubra parte dos campos
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey, // Vincula o formulário à chave para validação
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título da tela
              const Text(
                'Criar Conta',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cadastre-se para começar a simular seus investimentos.',
                style: TextStyle(fontSize: 16, color: AppColors.textLight),
              ),
              const SizedBox(height: 32),

              // Campo: Nome Completo
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
                  return null; // null = campo válido
                },
              ),
              const SizedBox(height: 16),

              // Campo: E-mail (com validação de formato)
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
                  // RegExp verifica se o e-mail tem o formato correto (ex: user@domain.com)
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Informe um e-mail válido (exemplo@email.com).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo: Telefone (somente números, máximo 11 dígitos)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11, // Limite de 11 dígitos (DDD + número)
                // FilteringTextInputFormatter.digitsOnly rejeita letras e símbolos
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                  hintText: 'DDD + Número (ex: 19999999999)',
                  counterText: '', // Oculta o contador padrão do Flutter
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

              // Campo: CPF (somente números, exatamente 11 dígitos)
              TextFormField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                maxLength: 11, // CPF tem exatamente 11 dígitos
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'CPF',
                  prefixIcon: Icon(Icons.badge, color: AppColors.primary),
                  hintText: 'Apenas os 11 números',
                  counterText: '',
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

              // Campo: Senha (oculta por padrão, mínimo 6 caracteres)
              TextFormField(
                controller: _passwordController,
                obscureText: true, // Exibe asteriscos em vez do texto real
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

              // Botão de cadastro — desabilitado durante o carregamento
              ElevatedButton(
                onPressed: _isLoading ? null : _cadastrarUsuario,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                // Exibe spinner durante loading ou texto "Cadastrar"
                child: _isLoading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Cadastrar', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
