// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Tela de Perfil com edição de dados e toggle de MFA
//
// Esta tela permite ao usuário:
//   - Visualizar e editar seus dados cadastrais (nome, e-mail, telefone, CPF)
//   - Ver o saldo fictício disponível
//   - Habilitar ou desabilitar autenticação em dois fatores (MFA)
//   - Fazer logout da conta

// Importa o kit de widgets visuais do Flutter
import 'package:flutter/material.dart';

// Importa o pacote HTTP para enviar alterações ao backend
import 'package:http/http.dart' as http;

// Importa ferramentas para codificar/decodificar JSON
import 'dart:convert';

// Importa o serviço de sessão para atualizar os dados salvos localmente
import '../services/session_service.dart';

// Importa as cores do tema do projeto
import '../theme/app_colors.dart';

// StatefulWidget porque os campos do formulário e o estado do MFA mudam
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Chave do formulário para validação centralizada
  final _formKey = GlobalKey<FormState>();

  // Controladores dos campos editáveis
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cpfController = TextEditingController();

  bool _isLoading = false;     // Spinner do botão "Salvar alterações"
  bool _isMfaLoading = false;  // Spinner do toggle de MFA (operação separada)
  bool _mfaEnabled = false;    // Estado atual do MFA (ligado/desligado)
  Map<String, dynamic> _user = {}; // Dados completos do usuário logado

  // Libera os controladores da memória ao fechar a tela
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  // didChangeDependencies: lê os dados do usuário passados como argumento de navegação
  // e preenche os campos do formulário. Executa apenas uma vez (_user.isEmpty).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_user.isEmpty) {
      // Lê os argumentos passados pela tela anterior (dados do usuário logado)
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is Map) {
        _user = Map<String, dynamic>.from(arguments);
      }

      // Preenche os campos de texto com os dados atuais do usuário
      _nameController.text = _user['nomeCompleto']?.toString() ?? '';
      _emailController.text = _user['email']?.toString() ?? '';
      _phoneController.text = _user['telefone']?.toString() ?? '';
      _cpfController.text = _user['cpf']?.toString() ?? '';

      // Lê o estado atual do MFA
      _mfaEnabled = _user['mfaEnabled'] == true;
    }
  }

  // Envia as alterações do perfil para o backend e atualiza a sessão local.
  // Usa o método HTTP PATCH (atualização parcial de dados).
  Future<void> _updateProfile() async {
    // Valida todos os campos do formulário antes de enviar
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // O UID é obrigatório para identificar qual usuário atualizar no banco
    final uid = _user['uid']?.toString() ?? '';
    if (uid.isEmpty) {
      _showError('UID do usuário ausente. Faça login novamente.');
      setState(() => _isLoading = false);
      return;
    }

    final url = Uri.parse('http://localhost:3000/api/usuario/$uid');
    try {
      // PATCH: envia apenas os campos que podem ser atualizados
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nomeCompleto': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'telefone': _phoneController.text.trim(),
          'cpf': _cpfController.text.trim(),
        }),
      );

      final body = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200) {
        // Monta o usuário atualizado combinando a resposta do servidor com dados locais
        final usuario = body['usuario'] ?? {};
        final updatedUser = Map<String, dynamic>.from(usuario);
        updatedUser['uid'] = uid;           // Mantém o UID
        updatedUser['mfaEnabled'] = _mfaEnabled; // Mantém o estado do MFA

        // Salva os dados atualizados no armazenamento local
        await SessionService.saveUser(updatedUser);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!'), backgroundColor: Colors.green),
        );

        // Retorna os dados atualizados para a tela anterior (Home) atualizar
        Navigator.pop(context, updatedUser);
      } else {
        _showError(body['error'] ?? 'Erro ao atualizar perfil.');
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Não foi possível conectar ao servidor backend.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Liga ou desliga o MFA enviando a requisição ao backend.
  // Chamado pelo Switch na seção de Segurança.
  Future<void> _toggleMfa(bool habilitar) async {
    final uid = _user['uid']?.toString() ?? '';
    if (uid.isEmpty) {
      _showError('Faça login novamente para alterar o MFA.');
      return;
    }

    setState(() => _isMfaLoading = true); // Exibe spinner no lugar do switch

    try {
      // Envia o novo estado do MFA (true/false) para o backend
      final response = await http.patch(
        Uri.parse('http://localhost:3000/api/mfa/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'habilitar': habilitar}),
      );

      final body = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200) {
        // Atualiza o estado visual do switch e os dados locais
        setState(() => _mfaEnabled = habilitar);
        _user['mfaEnabled'] = habilitar;
        await SessionService.saveUser(_user); // Persiste a mudança

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MFA ${habilitar ? 'habilitado' : 'desabilitado'} com sucesso!'),
            backgroundColor: habilitar ? Colors.green : Colors.orange,
          ),
        );
      } else {
        _showError(body['error'] ?? 'Erro ao alterar MFA.');
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Não foi possível conectar ao servidor.');
    } finally {
      if (mounted) setState(() => _isMfaLoading = false);
    }
  }

  // Exibe diálogo de confirmação antes de fazer logout.
  // Se confirmado, apaga a sessão e redireciona para o Login.
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar logout'),
        content: const Text('Deseja realmente sair da conta?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sair')),
        ],
      ),
    );

    if (confirmed == true) {
      await SessionService.clearUser(); // Apaga a sessão salva no dispositivo
      if (!mounted) return;
      // Vai para o Login limpando toda a pilha de navegação
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // Exibe uma mensagem de erro como SnackBar vermelho
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Converte o saldo para double de forma segura para exibição
    final balance = double.tryParse(_user['saldoFicticio']?.toString() ?? '0.0') ?? 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Form(
          key: _formKey, // Vincula ao formulário para validação em lote
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== CARD: EDIÇÃO DE DADOS CADASTRAIS =====
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10, offset: Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Editar Perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 18),

                    // Campo: Nome Completo
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nome Completo'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome completo.' : null,
                    ),
                    const SizedBox(height: 12),

                    // Campo: E-mail com validação de formato
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe seu e-mail.';
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(v.trim())) return 'Informe um e-mail válido.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Campo: Telefone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe seu telefone.';
                        if (v.trim().length < 10) return 'Telefone incompleto.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Campo: CPF com validação de 11 dígitos
                    TextFormField(
                      controller: _cpfController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'CPF'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe seu CPF.';
                        // Remove pontos e traços antes de contar os dígitos
                        if (v.replaceAll(RegExp(r'\D'), '').length != 11) return 'O CPF deve conter 11 dígitos.';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ===== CARD: RESUMO DE INVESTIMENTOS (saldo) =====
              Text('Resumo de Investimentos', style: TextStyle(fontSize: 18, color: Colors.grey[900], fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo Disponível', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    // Saldo formatado em reais
                    Text(
                      'R\$ ${balance.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ===== CARD: SEGURANÇA (MFA) =====
              const Text('Segurança', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  // Borda verde quando MFA ativo, cinza quando inativo
                  border: Border.all(color: _mfaEnabled ? Colors.green.shade200 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Ícone muda de cor conforme o estado do MFA
                        Icon(Icons.security, color: _mfaEnabled ? Colors.green : Colors.grey),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Autenticação em dois fatores (MFA)', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text('Um código será enviado ao seu e-mail a cada login.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        // Exibe spinner durante a operação ou o switch de toggle
                        _isMfaLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : Switch(
                                value: _mfaEnabled,
                                activeThumbColor: Colors.green,
                                onChanged: _toggleMfa, // Chama _toggleMfa ao mudar
                              ),
                      ],
                    ),

                    // Banner de confirmação — aparece apenas quando MFA está ativo
                    if (_mfaEnabled) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Text('MFA ativo — sua conta está protegida', style: TextStyle(color: Colors.green, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // ===== BOTÃO: SALVAR ALTERAÇÕES =====
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Salvar alterações', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 14),

              // ===== BOTÃO: SAIR DA CONTA (logout) =====
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Sair da conta', style: TextStyle(color: Colors.red, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
