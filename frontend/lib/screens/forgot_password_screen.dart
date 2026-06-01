// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Tela de Recuperação de Senha
//
// Implementa um fluxo de 3 etapas para redefinição de senha:
//   Etapa 0 — Usuário informa o e-mail cadastrado
//   Etapa 1 — Usuário digita o código de 6 dígitos recebido por e-mail
//   Etapa 2 — Usuário cria e confirma a nova senha
//
// Um indicador visual de progresso (bolinhas numeradas) mostra em qual etapa o usuário está.

// Importa o kit de widgets visuais do Flutter
import 'package:flutter/material.dart';

// Importa o pacote para fazer requisições HTTP ao backend
import 'package:http/http.dart' as http;

// Importa ferramentas para codificar/decodificar JSON
import 'dart:convert';

// Importa as cores do tema do projeto
import '../theme/app_colors.dart';

// StatefulWidget porque a tela muda de etapa (0 → 1 → 2) e tem estados de carregamento
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Controla qual etapa está sendo exibida: 0 = e-mail, 1 = código, 2 = nova senha
  int _step = 0;

  // Controladores dos campos de texto
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();      // Campo do código de 6 dígitos
  final _novaSenhaController = TextEditingController();
  final _confirmSenhaController = TextEditingController(); // Campo de confirmação da nova senha

  bool _isLoading = false;        // Controla o spinner de carregamento
  bool _showNovaSenha = false;    // Alterna visibilidade do campo de nova senha
  bool _showConfirmSenha = false; // Alterna visibilidade do campo de confirmação
  String _email = '';             // Guarda o e-mail para usar nas etapas seguintes

  // Libera os controladores da memória ao fechar a tela
  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _novaSenhaController.dispose();
    _confirmSenhaController.dispose();
    super.dispose();
  }

  // ETAPA 0 → 1: Envia o e-mail ao backend que gera e manda o código por e-mail.
  // Por segurança, o servidor retorna sucesso mesmo que o e-mail não exista.
  Future<void> _solicitarCodigo() async {
    final email = _emailController.text.trim();

    // Validação básica do formato do e-mail
    if (email.isEmpty || !email.contains('@')) {
      _showError('Informe um e-mail válido.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Chama o endpoint que envia o código de recuperação por e-mail
      await http.post(
        Uri.parse('http://localhost:3000/api/esqueci-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (!mounted) return;

      // Avança para a etapa 1 (inserir código) independente da resposta do servidor
      // (o servidor retorna 200 mesmo que o e-mail não exista — por segurança)
      setState(() {
        _email = email; // Guarda o e-mail para usar na etapa 2
        _step = 1;      // Exibe a tela de inserção do código
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

  // ETAPA 1 → 2: Valida o formato do código (6 dígitos) e avança para criar a nova senha.
  // A validação real do código ocorre apenas no momento de salvar a nova senha.
  Future<void> _verificarCodigo() async {
    final codigo = _codigoController.text.trim();

    // Verifica se o código tem exatamente 6 dígitos
    if (codigo.length != 6) {
      _showError('O código deve ter 6 dígitos.');
      return;
    }

    // Avança para a etapa de nova senha — a validação real acontece na etapa 2
    setState(() => _step = 2);
  }

  // ETAPA 2: Envia e-mail, código e nova senha ao backend para concluir a redefinição.
  Future<void> _redefinirSenha() async {
    final novaSenha = _novaSenhaController.text;
    final confirmSenha = _confirmSenhaController.text;

    // Valida o tamanho mínimo da senha
    if (novaSenha.length < 6) {
      _showError('A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    // Garante que os dois campos de senha são iguais
    if (novaSenha != confirmSenha) {
      _showError('As senhas não conferem.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Envia e-mail, código e nova senha para o backend validar e salvar
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/resetar-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _email,                          // E-mail guardado na etapa 0
          'codigo': _codigoController.text.trim(),  // Código da etapa 1
          'novaSenha': novaSenha,
        }),
      );

      if (!mounted) return;

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Senha redefinida com sucesso — volta para o login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha redefinida com sucesso! Faça login.'),
            backgroundColor: Colors.green,
          ),
        );
        // pushNamedAndRemoveUntil limpa toda a pilha de navegação e abre o Login
        // O usuário não pode voltar para a tela de recuperação com o botão "voltar"
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        // Código inválido ou expirado — volta para a etapa de código para tentar novamente
        _showError(body['error'] ?? 'Erro ao redefinir senha.');
        setState(() => _step = 1);
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Não foi possível conectar ao servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Exibe mensagem de erro como SnackBar vermelho na parte inferior da tela
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
              // Ícone de cadeado com seta (representa redefinição)
              const Icon(Icons.lock_reset, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),

              // Indicador de progresso das etapas (bolinhas animadas)
              _buildStepIndicator(),
              const SizedBox(height: 32),

              // Exibe apenas o conteúdo da etapa atual
              if (_step == 0) _buildStepEmail(),
              if (_step == 1) _buildStepCodigo(),
              if (_step == 2) _buildStepNovaSenha(),
            ],
          ),
        ),
      ),
    );
  }

  // Constrói o indicador visual de progresso: 3 bolinhas numeradas conectadas por linhas.
  // A bolinha da etapa atual é maior e colorida; etapas concluídas mostram um check.
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      // Gera 3 bolinhas (uma por etapa)
      children: List.generate(3, (i) {
        final active = i == _step;  // Etapa atual
        final done = i < _step;     // Etapa já concluída
        return Row(
          children: [
            // Bolinha animada: muda de tamanho e cor conforme o estado
            AnimatedContainer(
              duration: const Duration(milliseconds: 300), // Animação suave de 300ms
              width: active ? 36 : 28,   // Etapa atual é maior
              height: active ? 36 : 28,
              decoration: BoxDecoration(
                // Azul para etapa atual/concluída, cinza para as próximas
                color: done || active ? AppColors.primary : Colors.grey[300],
                shape: BoxShape.circle, // Formato circular
              ),
              child: Center(
                // Concluída: exibe ícone de check; outras: exibe o número da etapa
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
            // Linha de conexão entre bolinhas (exceto após a última)
            if (i < 2)
              Container(
                width: 40,
                height: 2,
                // Azul se a etapa foi concluída, cinza se ainda não chegou
                color: i < _step ? AppColors.primary : Colors.grey[300],
              ),
          ],
        );
      }),
    );
  }

  // Etapa 0: campo de e-mail para solicitar o código de redefinição
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
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Enviar código', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }

  // Etapa 1: campo para digitar o código de 6 dígitos recebido por e-mail
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
        // Exibe o e-mail para que o usuário saiba onde o código foi enviado
        Text(
          'Verifique o e-mail enviado para $_email.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 28),
        // Campo de código com fonte grande e espaçamento entre dígitos
        TextField(
          controller: _codigoController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            labelText: 'Código de 6 dígitos',
            counterText: '', // Oculta o contador padrão
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
        // Botão para voltar à etapa do e-mail e solicitar novo código
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: const Text('Não recebi o código — tentar novamente'),
        ),
      ],
    );
  }

  // Etapa 2: campos para digitar e confirmar a nova senha
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

        // Campo de nova senha com opção de mostrar/ocultar
        TextField(
          controller: _novaSenhaController,
          obscureText: !_showNovaSenha, // Oculta por padrão
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

        // Campo de confirmação da senha (deve ser idêntico ao anterior)
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

        // Botão final — verde para indicar conclusão do fluxo
        ElevatedButton(
          onPressed: _isLoading ? null : _redefinirSenha,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Redefinir senha', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }
}
