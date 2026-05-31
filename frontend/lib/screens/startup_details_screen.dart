// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Tela de Detalhes da Startup com sócios, Q&A e simulador

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

class StartupDetailsScreen extends StatefulWidget {
  const StartupDetailsScreen({super.key});

  @override
  State<StartupDetailsScreen> createState() => _StartupDetailsScreenState();
}

class _StartupDetailsScreenState extends State<StartupDetailsScreen> {
  final _amountController = TextEditingController();
  final _perguntaController = TextEditingController();

  double _simulatedTokens = 0.0;
  String _simulationMessage = '';
  double _walletBalance = 10000.0;
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _startupData = {};

  List<Map<String, dynamic>> _perguntas = [];
  bool _loadingPerguntas = false;
  bool _perguntaPrivada = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map) {
      _startupData = Map<String, dynamic>.from(arguments['startup'] ?? arguments);
      _userData = Map<String, dynamic>.from(arguments['user'] ?? {});
      final saldo = _userData['saldoFicticio'];
      if (saldo is String) {
        _walletBalance = double.tryParse(saldo.replaceAll(',', '.')) ?? _walletBalance;
      } else if (saldo is num) {
        _walletBalance = saldo.toDouble();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarPerguntas());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _perguntaController.dispose();
    super.dispose();
  }

  String _displayStage(String raw) {
    const map = {
      'ideacao': 'Ideação',
      'validacao': 'Validação',
      'operacao': 'Operação',
      'tracao': 'Tração',
    };
    return map[raw.toLowerCase().trim()] ?? raw;
  }

  double _getFirstNumericField(dynamic item, List<String> keys, double fallback) {
    if (item is Map) {
      for (final key in keys) {
        if (item.containsKey(key) && item[key] != null) {
          final text = item[key].toString().trim();
          final parsed = double.tryParse(text.replaceAll(',', '.'));
          if (parsed != null) return parsed;
        }
      }
    }
    return fallback;
  }

  String _getFirstNonEmptyField(dynamic item, List<String> keys, String fallback) {
    if (item is Map) {
      for (final key in keys) {
        if (item.containsKey(key) && item[key] != null) {
          final text = item[key].toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    }
    return fallback;
  }

  double _inferTokenPrice(dynamic startup) {
    final explicitPrice = _getFirstNumericField(startup, ['precoToken', 'valorToken', 'preco', 'valor'], 0.0);
    if (explicitPrice > 0) return explicitPrice;
    final capital = _getFirstNumericField(startup, ['capital_aportado', 'capitalAportado', 'capital'], 0.0);
    final tokens = _getFirstNumericField(startup, ['tokens_emitidos', 'tokensEmitidos', 'tokens'], 0.0);
    if (capital > 0 && tokens > 0) return capital / tokens;
    return 0.0;
  }

  String _formatCurrency(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  String _extractPitchUrl(dynamic startup) =>
      _getFirstNonEmptyField(startup, ['pitchUrl', 'videoUrl', 'linkPitch', 'pitch_link', 'video_demo', 'url'], '');

  bool _ehInvestidor() {
    final tokens = _userData['tokens'];
    if (tokens is Map && tokens.isNotEmpty) {
      final startupId = _getFirstNonEmptyField(_startupData, ['id', 'uid', 'startupId'], '');
      return tokens.containsKey(startupId);
    }
    return false;
  }

  Future<void> _carregarPerguntas() async {
    final startupId = _getFirstNonEmptyField(_startupData, ['id', 'uid', 'startupId'], '');
    if (startupId.isEmpty) return;

    setState(() => _loadingPerguntas = true);

    try {
      final uid = _userData['uid']?.toString() ?? '';
      final url = Uri.parse(
          'http://localhost:3000/api/perguntas/$startupId${uid.isNotEmpty ? '?uid=$uid' : ''}');
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _perguntas = data.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {
      // silencioso — perguntas não críticas
    } finally {
      if (mounted) setState(() => _loadingPerguntas = false);
    }
  }

  Future<void> _enviarPergunta() async {
    final pergunta = _perguntaController.text.trim();
    if (pergunta.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A pergunta deve ter pelo menos 5 caracteres.'), backgroundColor: Colors.red),
      );
      return;
    }

    final uid = _userData['uid']?.toString() ?? '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para enviar perguntas.'), backgroundColor: Colors.red),
      );
      return;
    }

    final startupId = _getFirstNonEmptyField(_startupData, ['id', 'uid', 'startupId'], '');

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/perguntas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'startupId': startupId,
          'pergunta': pergunta,
          'tipo': _perguntaPrivada ? 'privada' : 'publica',
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        _perguntaController.clear();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pergunta enviada com sucesso!'), backgroundColor: Colors.green),
        );
        await _carregarPerguntas();
      } else {
        final body = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['error'] ?? 'Erro ao enviar pergunta.'), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor.'), backgroundColor: Colors.red),
      );
    }
  }

  void _abrirDialogPergunta() {
    _perguntaPrivada = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Enviar pergunta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _perguntaController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Digite sua pergunta para os empreendedores...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_ehInvestidor())
                Row(
                  children: [
                    Checkbox(
                      value: _perguntaPrivada,
                      onChanged: (v) => setDialogState(() => _perguntaPrivada = v ?? false),
                    ),
                    const Expanded(child: Text('Pergunta privada (só você vê)', style: TextStyle(fontSize: 13))),
                  ],
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _perguntaController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _enviarPergunta,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Enviar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPitch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link de pitch inválido ou não disponível.'), backgroundColor: Colors.red),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _simulateInvestment(double tokenPrice) async {
    final text = _amountController.text.replaceAll(RegExp(r'[^0-9,\.]'), '');
    final amount = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) {
      setState(() { _simulatedTokens = 0.0; _simulationMessage = 'Informe um valor válido.'; });
      return;
    }
    if (amount > _walletBalance) {
      setState(() { _simulatedTokens = 0.0; _simulationMessage = 'Valor superior ao saldo disponível.'; });
      return;
    }
    if (tokenPrice <= 0) {
      setState(() { _simulatedTokens = 0.0; _simulationMessage = 'Preço de token não disponível.'; });
      return;
    }
    setState(() {
      _simulatedTokens = amount / tokenPrice;
      _simulationMessage = 'Com ${_formatCurrency(amount)} você pode adquirir ${_simulatedTokens.toStringAsFixed(2)} tokens.';
    });
  }

  Future<void> _confirmInvestment(double tokenPrice) async {
    final text = _amountController.text.replaceAll(RegExp(r'[^0-9,\.]'), '');
    final amount = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0 || amount > _walletBalance || tokenPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirme os dados antes de finalizar o aporte.'), backgroundColor: Colors.red),
      );
      return;
    }

    final uid = _userData['uid']?.toString() ?? '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados do usuário ausentes. Faça login novamente.'), backgroundColor: Colors.red),
      );
      return;
    }

    final startupId = _getFirstNonEmptyField(_startupData, ['id', 'uid', 'startupId'], _startupData['nome']?.toString() ?? 'startup');
    final amountTokens = amount / tokenPrice;

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/aporte'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': uid,
          'startupId': startupId,
          'startupNome': _startupData['nome_startup'] ?? _startupData['nome'] ?? 'Startup',
          'amount': amount,
          'tokenPrice': tokenPrice,
          'tokensQuantity': amountTokens,
        }),
      );

      if (!mounted) return;
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final newBalance = double.tryParse(body['saldoFicticio']?.toString() ?? '') ?? (_walletBalance - amount);
        setState(() {
          _walletBalance = newBalance;
          _amountController.clear();
          _simulatedTokens = 0.0;
          _simulationMessage = 'Aporte realizado! Saldo atualizado.';
        });
        _userData['saldoFicticio'] = newBalance;
        _userData['tokens'] = body['tokens'] ?? _userData['tokens'] ?? {};
        await SessionService.saveUser(_userData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aporte de ${_formatCurrency(amount)} confirmado!'), backgroundColor: AppColors.primary),
        );
        Navigator.pop(context, {'user': _userData});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['error'] ?? 'Erro ao registrar aporte.'), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor backend.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final startupName = _getFirstNonEmptyField(_startupData, ['nome_startup', 'nome', 'nomeStartup', 'name', 'titulo'], 'Startup Sem Nome');
    final stage = _displayStage(_getFirstNonEmptyField(_startupData, ['estagio', 'fase', 'stage'], ''));
    final description = _getFirstNonEmptyField(_startupData, ['descricao', 'description', 'resumo', 'sobre'], 'Descrição não disponível.');
    final sector = _getFirstNonEmptyField(_startupData, ['setor', 'area', 'segmento'], 'Setor não informado');
    final mentors = _getFirstNonEmptyField(_startupData, ['mentores_conselho', 'mentores', 'mentoria'], 'Não informados');
    final capital = _getFirstNumericField(_startupData, ['capital_aportado', 'capitalAportado', 'capital'], 0.0);
    final tokensIssued = _getFirstNumericField(_startupData, ['tokens_emitidos', 'tokensEmitidos', 'tokens'], 0.0);
    final tokenPrice = _inferTokenPrice(_startupData);
    final pitchLink = _extractPitchUrl(_startupData);

    // Sócios e participações societárias
    final sociosRaw = _getFirstNonEmptyField(_startupData, ['socios', 'socios_fundadores', 'founders'], '');
    final participacaoRaw = _getFirstNonEmptyField(_startupData, ['participacao_societaria', 'participacao', 'equity'], '');
    final listaSocios = sociosRaw.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final listaParticipacoes = participacaoRaw.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(startupName),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card principal
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10, offset: Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(startupName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(stage),
                        backgroundColor: AppColors.primary.withAlpha(31),
                        labelStyle: const TextStyle(color: AppColors.primary),
                      ),
                      if (tokenPrice > 0)
                        Text(_formatCurrency(tokenPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Resumo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description, style: const TextStyle(fontSize: 15, height: 1.6)),
                  if (pitchLink.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchPitch(pitchLink),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                        icon: const Icon(Icons.play_circle_outline, color: Colors.white),
                        label: const Text('Assistir Pitch', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Detalhes financeiros
            const Text('Detalhes financeiros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoTile('Capital', capital > 0 ? _formatCurrency(capital) : 'Não informado'),
                const SizedBox(width: 12),
                _infoTile('Tokens', tokensIssued > 0 ? tokensIssued.toStringAsFixed(0) : 'Não informado'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoTile('Setor', sector),
                const SizedBox(width: 12),
                _infoTile('Preço/token', tokenPrice > 0 ? _formatCurrency(tokenPrice) : 'N/D'),
              ],
            ),
            const SizedBox(height: 22),

            // Estrutura societária
            const Text('Estrutura Societária', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: listaSocios.isEmpty
                  ? const Text('Informação societária não disponível.', style: TextStyle(color: Colors.grey))
                  : Column(
                      children: List.generate(listaSocios.length, (i) {
                        final participacao = i < listaParticipacoes.length ? listaParticipacoes[i] : '—';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(31),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    listaSocios[i].isNotEmpty ? listaSocios[i][0].toUpperCase() : '?',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(listaSocios[i], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Participação: $participacao', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(31),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(participacao, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
            ),
            const SizedBox(height: 22),

            // Governança e Mentoria
            const Text('Governança e Mentoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _detailCard('Mentores e Conselho', mentors),
            const SizedBox(height: 22),

            // Q&A - Perguntas e Respostas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Perguntas e Respostas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _abrirDialogPergunta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.add_comment, color: Colors.white, size: 18),
                  label: const Text('Perguntar', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildQaSection(),
            const SizedBox(height: 22),

            // Simulador de Investimento
            Text('Simulador de Investimento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor do aporte',
                      hintText: 'Ex: 1500,00',
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Disponível: ${_formatCurrency(_walletBalance)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _simulateInvestment(tokenPrice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.calculate_outlined, color: Colors.white),
                    label: const Text('Simular aporte', style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                  if (_simulationMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.indigo.shade100),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_simulationMessage, style: TextStyle(color: Colors.grey[800], fontSize: 14))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _confirmInvestment(tokenPrice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Confirmar Aporte', style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQaSection() {
    if (_loadingPerguntas) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    }

    if (_perguntas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: const Text('Nenhuma pergunta ainda. Seja o primeiro a perguntar!', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: _perguntas.map((p) {
        final isPrivada = p['tipo'] == 'privada';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isPrivada ? Colors.amber.shade200 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(p['nomeAutor'] ?? 'Anônimo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  if (isPrivada)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Privada', style: TextStyle(fontSize: 11, color: Colors.amber)),
                    ),
                  const SizedBox(width: 4),
                  Text(p['criadoEm'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              Text(p['pergunta'] ?? '', style: const TextStyle(fontSize: 14)),
              if (p['resposta'] != null && p['resposta'].toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(p['resposta'].toString(), style: const TextStyle(fontSize: 13, color: Colors.black87))),
                    ],
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Aguardando resposta...', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _infoTile(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }
}
