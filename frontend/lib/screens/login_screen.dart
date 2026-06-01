// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Tela de Login com suporte a MFA
//
// Esta tela gerencia o acesso ao app. Possui dois modos:
//   1. Modo normal: formulário de e-mail + senha
//   2. Modo MFA: campo para código de 6 dígitos (quando autenticação em dois fatores está ativa)

// Importa o kit de widgets visuais do Flutter
import 'package:flutter/material.dart';

// Importa o pacote para fazer chamadas HTTP ao backend
import 'package:http/http.dart' as http;

// Importa ferramentas para codificar/decodificar JSON
import 'dart:convert';

// Importa o serviço de sessão para salvar os dados do usuário localmente após login
import '../services/session_service.dart';

// Importa as cores do tema do projeto
import '../theme/app_colors.dart';

// StatefulWidget porque a tela muda de estado: loading, modo MFA, visibilidade de senha
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Chave global do formulário — permite validar todos os campos de uma vez
  final _formKey = GlobalKey<FormState>();

  // Controladores dos campos de texto — permitem ler e limpar o texto digitado
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController(); // Código de 6 dígitos do MFA

  bool _isLoading = false;    // Controla se o spinner de carregamento está visível
  bool _showMfaStep = false;  // Se true, exibe o campo de código MFA em vez do formulário de login
  bool _showPassword = false; // Controla se a senha está visível ou oculta (asteriscos)
  String _pendingUid = '';    // Guarda o UID temporariamente durante o fluxo MFA

  // dispose: libera os controladores da memória quando a tela é fechada.
  // Evitar memory leaks (vazamentos de memória) é uma boa prática.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  // Realiza o login enviando e-mail e senha para o backend.
  // Se o servidor retornar mfaRequired: true, exibe a etapa de código MFA.
  Future<void> _fazerLogin() async {
    // Valida o formulário — se algum campo falhar na validação, para aqui
    if (!_formKey.currentState!.validate()) return;

    // Ativa o spinner de carregamento
    setState(() => _isLoading = true);

    final url = Uri.parse('http://localhost:3000/api/login');

    try {
      // Envia e-mail e senha para o backend via POST
      final resposta = await http.post(
        url,
        headers: {'Content-Type': 'application/json'}, // Informa que o corpo é JSON
        body: jsonEncode({
          'email': _emailController.text.trim(), // .trim() remove espaços extras
          'senha': _passwordController.text,
        }),
      );

      // Decodifica a resposta JSON do servidor
      final dados = jsonDecode(resposta.body);

      // Proteção: verifica se o widget ainda está ativo na tela
      if (!mounted) return;

      if (resposta.statusCode == 200) {
        // O servidor pediu MFA — exibe a etapa de código
        if (dados['mfaRequired'] == true) {
          setState(() {
            _pendingUid = dados['uid']?.toString() ?? ''; // Guarda o UID para a próxima etapa
            _showMfaStep = true; // Troca o formulário pelo campo de código MFA
          });
          // Avisa o usuário que o código foi enviado por e-mail
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Código de verificação enviado para seu e-mail.'),
              backgroundColor: Colors.blue,
            ),
          );
          return;
        }

        // Login sem MFA: finaliza normalmente
        await _finalizarLogin(dados);
      } else {
        // O servidor retornou um erro (e-mail ou senha incorretos, etc.)
        _mostrarErro(dados['error'] ?? 'Erro ao efetuar login.');
      }
    } catch (_) {
      // Erro de conexão — servidor offline ou sem internet
      if (!mounted) return;
      _mostrarErro('Não foi possível conectar ao servidor backend.');
    } finally {
      // Desativa o spinner independente do resultado (sucesso ou erro)
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Valida o código MFA digitado pelo usuário.
  // Chamado quando o usuário está na etapa de segundo fator.
  Future<void> _verificarMfa() async {
    final codigo = _mfaCodeController.text.trim();

    // O código MFA deve ter exatamente 6 dígitos
    if (codigo.length != 6) {
      _mostrarErro('O código deve ter 6 dígitos.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Envia o UID e o código para o endpoint de verificação MFA
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/mfa/verificar-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': _pendingUid, 'codigo': codigo}),
      );

      final dados = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Código válido — finaliza o login normalmente
        await _finalizarLogin(dados);
      } else {
        // Código inválido ou expirado
        _mostrarErro(dados['error'] ?? 'Código inválido.');
      }
    } catch (_) {
      if (!mounted) return;
      _mostrarErro('Não foi possível conectar ao servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Conclui o processo de login: salva a sessão localmente e navega para a Home.
  // Chamado tanto no login normal quanto após validação do MFA.
  Future<void> _finalizarLogin(Map<String, dynamic> dados) async {
    // Extrai e converte os dados do usuário da resposta do servidor
    final usuarioRaw = dados['usuario'] as Map<String, dynamic>;
    final usuarioData = Map<String, dynamic>.from(usuarioRaw);

    // Converte o saldo para double (número decimal) de forma segura
    // (pode vir como int, double ou string dependendo do servidor)
    final saldoFicticioValue = usuarioData['saldoFicticio'];
    final saldoFicticio = saldoFicticioValue is num
        ? saldoFicticioValue.toDouble()
        : double.tryParse(saldoFicticioValue?.toString() ?? '0.0') ?? 0.0;

    // Monta o mapa de dados do usuário que será salvo localmente
    final currentUser = {
      'uid': dados['uid']?.toString() ?? '',
      'nomeCompleto': usuarioData['nomeCompleto']?.toString() ?? 'Investidor',
      'email': usuarioData['email']?.toString() ?? '',
      'cpf': usuarioData['cpf']?.toString() ?? '',
      'telefone': usuarioData['telefone']?.toString() ?? '',
      'saldoFicticio': saldoFicticio,
      'tokens': usuarioData['tokens'] ?? {},             // Carteira de tokens
      'historicoAportes': usuarioData['historicoAportes'] ?? [], // Histórico de transações
      'mfaEnabled': usuarioData['mfaEnabled'] ?? false,
    };

    // Salva os dados da sessão no armazenamento local do dispositivo
    await SessionService.saveUser(currentUser);

    if (!mounted) return;

    // Exibe mensagem de boas-vindas
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bem-vindo, ${usuarioData['nomeCompleto']}!'),
        backgroundColor: Colors.green,
      ),
    );

    // Navega para a Home substituindo a tela de Login na pilha de navegação
    // (o usuário não consegue voltar para o login pressionando "voltar")
    Navigator.pushReplacementNamed(context, '/home', arguments: currentUser);
  }

  // Exibe uma mensagem de erro como SnackBar (faixa na parte inferior da tela)
  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  // Constrói a interface visual da tela.
  // Exibe o formulário de login normal OU a etapa de MFA conforme o estado.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        // SingleChildScrollView permite rolar o conteúdo se o teclado cobrir parte da tela
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          // Condicional: exibe MFA ou login normal dependendo do estado atual
          child: _showMfaStep ? _buildMfaStep() : _buildLoginStep(),
        ),
      ),
    );
  }

  // Constrói o formulário principal de login (e-mail + senha)
  Widget _buildLoginStep() {
    return Form(
      key: _formKey, // Associa o formulário à chave global para validação
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch, // Botões ocupam toda a largura
        children: [
          // Ícone do app
          const Icon(Icons.trending_up_rounded, size: 80, color: AppColors.primary),
          const SizedBox(height: 16),

          // Nome do app
          const Text(
            'MesclaInvest',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 8),

          // Subtítulo descritivo
          const Text(
            'Simulador de Tokenização de Startups',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textLight),
          ),
          const SizedBox(height: 48),

          // Campo de e-mail com validação
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress, // Teclado com @ e .com
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.email, color: AppColors.primary),
            ),
            validator: (value) {
              // Retorna mensagem de erro se vazio; null significa que passou na validação
              if (value == null || value.trim().isEmpty) return 'Por favor, informe seu e-mail.';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Campo de senha com opção de mostrar/ocultar
          TextFormField(
            controller: _passwordController,
            obscureText: !_showPassword, // true = senha oculta com asteriscos
            decoration: InputDecoration(
              labelText: 'Senha',
              prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
              // Botão de olho para alternar visibilidade da senha
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

          // Link para recuperação de senha (alinhado à direita)
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

          // Botão principal de login — desabilitado durante carregamento
          ElevatedButton(
            onPressed: _isLoading ? null : _fazerLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            // Exibe spinner durante loading ou texto "Entrar"
            child: _isLoading
                ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Entrar', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
          const SizedBox(height: 24),

          // Link para criar nova conta
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

  // Constrói a etapa de verificação MFA (código de 6 dígitos)
  // Exibida após login bem-sucedido quando o MFA está ativo
  Widget _buildMfaStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ícone de segurança
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

        // Campo grande para o código MFA — teclado numérico, máximo 6 dígitos
        TextField(
          controller: _mfaCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          // Fonte grande com espaçamento entre dígitos para facilitar leitura
          style: const TextStyle(fontSize: 32, letterSpacing: 10, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            labelText: 'Código MFA',
            counterText: '', // Oculta o contador "0/6" padrão do Flutter
          ),
        ),
        const SizedBox(height: 24),

        // Botão para verificar o código
        ElevatedButton(
          onPressed: _isLoading ? null : _verificarMfa,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 22, width: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Verificar', style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
        const SizedBox(height: 12),

        // Botão para voltar ao formulário de login (cancelar MFA)
        TextButton(
          onPressed: () => setState(() {
            _showMfaStep = false;        // Volta para o formulário de login
            _mfaCodeController.clear();  // Limpa o campo de código
          }),
          child: const Text('Voltar ao login'),
        ),
      ],
    );
  }
}
