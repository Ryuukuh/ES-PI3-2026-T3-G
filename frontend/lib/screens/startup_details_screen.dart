import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StartupDetailsScreen extends StatefulWidget {
  const StartupDetailsScreen({Key? key}) : super(key: key);

  @override
  State<StartupDetailsScreen> createState() => _StartupDetailsScreenState();
}

class _StartupDetailsScreenState extends State<StartupDetailsScreen> {
  final _amountController = TextEditingController();
  double _simulatedTokens = 0.0;
  String _simulationMessage = '';
  double _walletBalance = 10000.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  } 

  double _getFirstNumericField(
    dynamic item,
    List<String> keys,
    double fallback,
  ) {
    if (item is Map) {
      for (final key in keys) {
        if (item.containsKey(key) && item[key] != null) {
          final text = item[key].toString().trim();
          final parsed = double.tryParse(text.replaceAll(',', '.'));
          if (parsed != null) {
            return parsed;
          }
        }
      }
    }
    return fallback;
  }

  String _getFirstNonEmptyField(
    dynamic item,
    List<String> keys,
    String fallback,
  ) {
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
    final explicitPrice = _getFirstNumericField(startup, [
      'precoToken',
      'valorToken',
      'preco',
      'valor',
    ], 0.0);
    if (explicitPrice > 0) return explicitPrice;

    final capital = _getFirstNumericField(startup, [
      'capital_aportado',
      'capitalAportado',
      'capital',
    ], 0.0);
    final tokens = _getFirstNumericField(startup, [
      'tokens_emitidos',
      'tokensEmitidos',
      'tokens',
    ], 0.0);
    if (capital > 0 && tokens > 0) {
      return capital / tokens;
    }
    return 0.0;
  }

  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  void _simulateInvestment(double tokenPrice) {
    final text = _amountController.text.replaceAll(RegExp(r'[^0-9,\.]'), '');
    final amount = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) {
      setState(() {
        _simulatedTokens = 0.0;
        _simulationMessage =
            'Informe um valor válido para simular a compra de tokens.';
      });
      return;
    }
    if (amount > _walletBalance) {
      setState(() {
        _simulatedTokens = 0.0;
        _simulationMessage = 'Valor superior ao saldo disponível.';
      });
      return;
    }
    if (tokenPrice <= 0) {
      setState(() {
        _simulatedTokens = 0.0;
        _simulationMessage = 'Preço de token não disponível para esta startup.';
      });
      return;
    }

    setState(() {
      _simulatedTokens = amount / tokenPrice;
      _simulationMessage =
          'Com R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')} você pode adquirir ${_simulatedTokens.toStringAsFixed(2)} tokens.';
    });
  }

  void _confirmInvestment(double tokenPrice) {
    final text = _amountController.text.replaceAll(RegExp(r'[^0-9,\.]'), '');
    final amount = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0 || amount > _walletBalance || tokenPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirme os dados antes de finalizar a simulação.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _walletBalance -= amount;
      _amountController.clear();
      _simulatedTokens = 0.0;
      _simulationMessage =
          'Simulação finalizada. Boa sorte com a sua carteira!';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Simulação confirmada! Investimento de ${_formatCurrency(amount)} registrado localmente.',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final startup = (arguments is Map) ? arguments : <String, dynamic>{};

    final startupName = _getFirstNonEmptyField(startup, [
      'nome',
      'nome_startup',
      'nomeStartup',
      'startupNome',
      'name',
      'titulo',
      'startup',
    ], 'Startup Sem Nome');
    final subtitle = _getFirstNonEmptyField(startup, [
      'subtitulo',
      'tagline',
      'pitch',
      'descricao_curta',
      'headline',
    ], '');
    final stage = _getFirstNonEmptyField(startup, [
      'estagio',
      'fase',
      'stage',
    ], 'Estágio desconhecido');
    final description = _getFirstNonEmptyField(startup, [
      'descricao',
      'description',
      'resumo',
      'sobre',
    ], 'Descrição não disponível.');
    final sector = _getFirstNonEmptyField(startup, [
      'setor',
      'area',
      'segmento',
    ], 'Setor não informado');
    final governance = _getFirstNonEmptyField(startup, [
      'governanca',
      'governance',
      'gestao',
    ], 'Governança não informada.');
    final mentors = _getFirstNonEmptyField(startup, [
      'mentores',
      'mentoria',
      'mentoredBy',
    ], 'Mentores não informados.');
    final capital = _getFirstNumericField(startup, [
      'capital_aportado',
      'capitalAportado',
      'capital',
    ], 0.0);
    final tokensIssued = _getFirstNumericField(startup, [
      'tokens_emitidos',
      'tokensEmitidos',
      'tokens',
    ], 0.0);
    final tokenPrice = _inferTokenPrice(startup);
    final equity = _getFirstNonEmptyField(startup, [
      'participacao_societaria',
      'participacao',
      'equity',
    ], 'Informação não disponível');

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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  const BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    startupName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(stage),
                        backgroundColor: AppColors.primary.withAlpha(31),
                        labelStyle: const TextStyle(color: AppColors.primary),
                      ),
                      Text(
                        _formatCurrency(tokenPrice),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Resumo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Descrição completa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                description,
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Detalhes financeiros',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoTile(
                  'Capital',
                  capital > 0 ? _formatCurrency(capital) : 'Não informado',
                ),
                const SizedBox(width: 12),
                _infoTile(
                  'Tokens',
                  tokensIssued > 0
                      ? tokensIssued.toStringAsFixed(0)
                      : 'Não informado',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoTile('Setor', sector),
                const SizedBox(width: 12),
                _infoTile('Equity', equity),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Governança e Mentoria',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _detailCard('Governança', governance),
            const SizedBox(height: 10),
            _detailCard('Mentores', mentors),
            const SizedBox(height: 20),
            Text(
              'Simulador de Investimento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
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
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor do aporte',
                      hintText: 'Ex: 1500,00',
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _simulateInvestment(tokenPrice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Simular aporte'),
                  ),
                  if (_simulationMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _simulationMessage,
                      style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _confirmInvestment(tokenPrice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                    ),
                    child: const Text('Confirmar simulação'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Saldo disponível: ${_formatCurrency(_walletBalance)}',
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }
}
