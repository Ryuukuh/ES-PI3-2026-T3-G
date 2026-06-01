// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor: Rafael Elias Correa | RA: 18726497
// Carteira do investidor: saldo, gráfico de valorização, pizza de distribuição,
// lista de investimentos com venda e histórico de transações.

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/session_service.dart';
import '../theme/app_colors.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  Map<String, dynamic> _userData = {};
  bool _initialized = false;
  bool _isProcessingSale = false;

  // Mantém o último total investido para exibir o gráfico mesmo após vender tudo
  double _lastTotalInvested = 0.0;

  // 0=Diário 1=Semanal 2=Mensal 3=6meses 4=Anual
  int _selectedPeriod = 2;
  final List<String> _periods = ['Diário', 'Semanal', 'Mensal', '6 meses', 'Anual'];

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  List<Map<String, dynamic>> _extractInvestments(Map<String, dynamic> tokens) {
    final investments = <Map<String, dynamic>>[];
    for (final entry in tokens.entries) {
      final tokenData = entry.value;
      if (tokenData is Map) {
        final qtd = _parseDouble(tokenData['tokens']);
        if (qtd < 1) continue; // ignora entradas sem tokens inteiros (resíduo de floating point)
        investments.add({
          'startupId': entry.key.toString(),
          'name': tokenData['startupNome'] ?? entry.key,
          'valor': _parseDouble(tokenData['valor']),
          'tokens': qtd,
          'tokenPrice': _parseDouble(tokenData['tokenPrice']),
          'updatedAt': tokenData['updatedAt']?.toString() ?? '',
        });
      }
    }
    return investments;
  }

  List<Map<String, dynamic>> _extractHistory(
      dynamic rawHistory, Map<String, dynamic> tokens) {
    final history = <Map<String, dynamic>>[];

    if (rawHistory is List) {
      for (final entry in rawHistory.reversed) {
        if (entry is Map) {
          history.add({
            'startupNome': entry['startupNome']?.toString() ?? 'Startup',
            'amount': _parseDouble(entry['amount']),
            'tokens': _parseDouble(entry['tokensQuantity'] ?? entry['tokens']),
            'createdAt': entry['createdAt']?.toString() ?? '',
            'tipo': entry['tipo']?.toString() ?? 'aporte',
          });
        }
      }
    }

    // Fallback: reconstrói histórico a partir dos tokens ativos se não há histórico salvo
    if (history.isEmpty && tokens.isNotEmpty) {
      for (final entry in tokens.entries) {
        final tokenData = entry.value;
        if (tokenData is Map) {
          history.add({
            'startupNome': tokenData['startupNome']?.toString() ?? entry.key.toString(),
            'amount': _parseDouble(tokenData['valor']),
            'tokens': _parseDouble(tokenData['tokens']),
            'createdAt': tokenData['updatedAt']?.toString() ?? '',
            'tipo': 'aporte',
          });
        }
      }
    }
    return history;
  }

  // Gera pontos simulados com seed determinístico (mesmo período+total = mesmos pontos).
  // Variação entre -3% e +5% por ponto (leve viés de alta).
  List<FlSpot> _gerarPontosGrafico(double totalInvestido, int periodo) {
    if (totalInvestido <= 0) return [];

    final int numPontos;
    switch (periodo) {
      case 0: numPontos = 24; break;
      case 1: numPontos = 7;  break;
      case 2: numPontos = 30; break;
      case 3: numPontos = 26; break;
      case 4:
        final agora = DateTime.now();
        numPontos = ((agora.difference(DateTime(agora.year, 1, 1)).inDays) / 7)
            .ceil()
            .clamp(1, 52);
        break;
      default: numPontos = 30;
    }

    final rng = Random(periodo * 1000 + totalInvestido.toInt());
    final spots = <FlSpot>[];
    double valor = totalInvestido;

    for (int i = 0; i < numPontos; i++) {
      final variacao = (rng.nextDouble() * 8 - 3) / 100;
      valor = valor * (1 + variacao);
      spots.add(FlSpot(i.toDouble(), double.parse(valor.toStringAsFixed(2))));
    }
    return spots;
  }

  Future<Map<String, dynamic>?> _fetchUserFromServer(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final resp =
          await http.get(Uri.parse('http://localhost:3000/api/usuario/$uid'));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        return Map<String, dynamic>.from(body['usuario'] ?? {});
      }
    } catch (_) {}
    return null;
  }

  Future<void> _sellTokens(
      String startupId, String startupName, double availableTokens, double quantity) async {
    if (quantity <= 0 || quantity > availableTokens) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Quantidade inválida para venda.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessingSale = true);

    final uid = _userData['uid']?.toString() ?? '';
    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/venda'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'startupId': startupId, 'tokenQuantity': quantity}),
      );
      final body = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _userData = {
            ..._userData,
            'saldoFicticio': body['saldoFicticio'] ?? _userData['saldoFicticio'],
            'tokens': body['tokens'] ?? _userData['tokens'],
            'historicoAportes': body['historicoAportes'] ?? _userData['historicoAportes'],
          };
        });
        await SessionService.saveUser(_userData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Venda de $quantity tokens de $startupName realizada!'),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(body['error'] ?? 'Erro ao registrar venda.'),
              backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível conectar ao servidor.'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessingSale = false);
    }
  }

  Future<void> _showSellDialog(
      String startupId, String startupName, double availableTokens) async {
    final maxTokens = availableTokens.floor();
    final quantityController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vender tokens de $startupName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tokens disponíveis: $maxTokens'),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number, // apenas inteiros
              decoration: InputDecoration(
                labelText: 'Quantidade a vender',
                hintText: 'Ex: 1 a $maxTokens',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final q = int.tryParse(quantityController.text.trim()) ?? 0;
              if (q >= 1 && q <= maxTokens) Navigator.of(context).pop(true);
            },
            child: const Text('Vender'),
          ),
        ],
      ),
    );

    if (result == true) {
      final q = int.tryParse(quantityController.text.trim()) ?? 0;
      await _sellTokens(startupId, startupName, availableTokens, q.toDouble());
    }
  }

  // Limite de R$50.000 por depósito conforme regra de negócio do simulador.
  Future<void> _showDepositDialog() async {
    final valorController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Depositar Saldo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adicione saldo à sua carteira para realizar investimentos.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: valorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Valor (máx. R\$ 50.000)', prefixText: 'R\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
              if (v > 0 && v <= 50000) Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Depositar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      final valor = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
      await _realizarDeposito(valor);
    }
  }

  Future<void> _realizarDeposito(double valor) async {
    final uid = _userData['uid']?.toString() ?? '';
    if (uid.isEmpty || valor <= 0) return;
    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/depositar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'valor': valor}),
      );
      final body = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() => _userData['saldoFicticio'] = _parseDouble(body['saldoFicticio']));
        await SessionService.saveUser(_userData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Depósito de R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')} realizado!'),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(body['error'] ?? 'Erro ao realizar depósito.'),
              backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível conectar ao servidor.'),
            backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildAllocationChart(List<Map<String, dynamic>> investments) {
    final totalInvested = investments.fold<double>(
        0.0, (sum, item) => sum + _parseDouble(item['valor']));
    final colors = [
      Colors.indigo, Colors.green, Colors.orange,
      Colors.purple, Colors.blue, Colors.teal, Colors.red
    ];

    final sections = investments.asMap().entries.map((entry) {
      final i = entry.key;
      final inv = entry.value;
      final value = _parseDouble(inv['valor']);
      final percent = totalInvested > 0 ? (value / totalInvested) * 100 : 0.0;
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: value,
        title: '${inv['name']?.toString().split(' ').first ?? ''}\n${percent.toStringAsFixed(0)}%',
        radius: 70,
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return PieChart(PieChartData(sections: sections, centerSpaceRadius: 36, sectionsSpace: 4));
  }

  String _xLabel(int i) {
    switch (_selectedPeriod) {
      case 0: return i % 4 == 0 ? '${i}h' : '';
      case 1:
        const dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
        return i < dias.length ? dias[i] : '';
      case 2:
        if (i == 0) return '1';
        if ((i + 1) % 5 == 0) return '${i + 1}';
        return '';
      case 3:
        if (i % 4 != 0) return '';
        final date3 = DateTime.now().subtract(Duration(days: (25 - i) * 7));
        const m3 = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
        return m3[date3.month - 1];
      case 4:
        if (i % 4 != 0) return '';
        final date4 = DateTime(DateTime.now().year, 1, 1).add(Duration(days: i * 7));
        const m4 = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
        return m4[(date4.month - 1) % 12];
      default: return '';
    }
  }

  Widget _buildValorizacaoChart(double totalInvestido, {bool hasActiveInvestments = true}) {
    final spots = _gerarPontosGrafico(totalInvestido, _selectedPeriod);

    if (spots.isEmpty) {
      return const Center(
          child: Text('Realize um investimento para ver a valorização.',
              style: TextStyle(color: Colors.grey)));
    }

    final minY = spots.map((s) => s.y).reduce(min);
    final maxY = spots.map((s) => s.y).reduce(max);
    final padding = (maxY - minY) * 0.15;

    final variacao = spots.first.y > 0
        ? ((spots.last.y - spots.first.y) / spots.first.y) * 100
        : 0.0;
    final isPositivo = variacao >= 0;
    final lineColor = isPositivo ? Colors.green : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasActiveInvestments)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.history, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Sem investimentos ativos — exibindo histórico do último período',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Text(
              '${isPositivo ? '+' : ''}${variacao.toStringAsFixed(2)}%',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: lineColor),
            ),
            const SizedBox(width: 8),
            Icon(isPositivo ? Icons.trending_up : Icons.trending_down, color: lineColor),
          ],
        ),
        const SizedBox(height: 4),
        Text('no período selecionado',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: minY - padding,
              maxY: maxY + padding,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final label = _xLabel(value.toInt());
                      if (label.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(label,
                            style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchSpotThreshold: 20,
                getTouchedSpotIndicator: (barData, spotIndexes) =>
                    spotIndexes.map((_) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                        color: lineColor.withAlpha(120),
                        strokeWidth: 1.5,
                        dashArray: [4, 4]),
                    FlDotData(
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 5,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: lineColor,
                      ),
                    ),
                  );
                }).toList(),
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.indigo.shade900,
                  tooltipPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                    final label = _xLabel(s.x.toInt());
                    return LineTooltipItem(
                      label.isNotEmpty ? '$label\n' : '',
                      const TextStyle(color: Colors.white60, fontSize: 10),
                      children: [
                        TextSpan(
                          text: 'R\$ ${s.y.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: lineColor,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: lineColor.withAlpha(30)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final user = (arguments is Map) ? arguments : <String, dynamic>{};
    if (!_initialized && user.isNotEmpty) {
      _userData = {...user};
      _initialized = true;
    }
    final populatedUser = _initialized ? _userData : user;

    final name = populatedUser['nomeCompleto']?.toString() ?? 'Investidor';
    final balance = _parseDouble(populatedUser['saldoFicticio']);

    final tokens = <String, dynamic>{};
    final rawTokens = populatedUser['tokens'];
    if (rawTokens is Map) {
      for (final entry in rawTokens.entries) {
        tokens[entry.key.toString()] = entry.value;
      }
    }

    final investments = _extractInvestments(tokens);
    final totalInvested =
        investments.fold<double>(0.0, (sum, item) => sum + _parseDouble(item['valor']));

    if (totalInvested > 0) _lastTotalInvested = totalInvested;
    final chartTotal = _lastTotalInvested;

    final allocation =
        balance > 0 ? (totalInvested / balance).clamp(0.0, 1.0) : 0.0;
    final history = _extractHistory(populatedUser['historicoAportes'], tokens);

    // PopScope retorna _userData atualizado ao sair da tela
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _userData);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Minha Carteira'),
          backgroundColor: AppColors.primary,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar',
              onPressed: () async {
                final uid = populatedUser['uid']?.toString() ?? '';
                final latest = await _fetchUserFromServer(uid);
                if (!mounted || latest == null) return;
                setState(() => _userData = {...populatedUser, ...latest});
                await SessionService.saveUser(_userData);
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Olá, $name',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Card Saldo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.05),
                        blurRadius: 10,
                        offset: Offset(0, 6))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo disponível', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      'R\$ ${balance.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    _infoRow('Total investido',
                        'R\$ ${totalInvested.toStringAsFixed(2).replaceAll('.', ',')}'),
                    const SizedBox(height: 8),
                    _infoRow('Saldo livre',
                        'R\$ ${(balance - totalInvested).toStringAsFixed(2).replaceAll('.', ',')}'),
                    const SizedBox(height: 18),
                    const Text('Alocação da carteira',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: allocation),
                    const SizedBox(height: 8),
                    Text('${(allocation * 100).toStringAsFixed(0)}% alocado',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showDepositDialog,
                        icon: const Icon(Icons.add_card, color: AppColors.primary),
                        label: const Text('Depositar Saldo',
                            style: TextStyle(color: AppColors.primary)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Gráfico de valorização
              const Text('Valorização dos investimentos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.05),
                        blurRadius: 10,
                        offset: Offset(0, 6))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(_periods.length, (i) {
                          final selected = i == _selectedPeriod;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_periods[i]),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _selectedPeriod = i),
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : Colors.black,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildValorizacaoChart(chartTotal,
                        hasActiveInvestments: totalInvested > 0),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Gráfico de pizza (só exibe com investimentos ativos)
              if (investments.isNotEmpty) ...[
                const Text('Distribuição da Carteira',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.05),
                          blurRadius: 10,
                          offset: Offset(0, 6))
                    ],
                  ),
                  child: SizedBox(
                      height: 200, child: _buildAllocationChart(investments)),
                ),
                const SizedBox(height: 24),
              ],

              // Lista de investimentos
              const Text('Investimentos em Carteira',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              if (investments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Você ainda não realizou nenhum aporte.',
                          style: TextStyle(fontSize: 16)),
                      SizedBox(height: 12),
                      Text(
                          'Explore o catálogo de startups e simule seu primeiro investimento.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else
                Column(
                  children: investments.map((inv) {
                    final availableTokens = _parseDouble(inv['tokens']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv['name']?.toString() ?? 'Startup',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                              'Valor aportado: R\$ ${_parseDouble(inv['valor']).toStringAsFixed(2).replaceAll('.', ',')}'),
                          const SizedBox(height: 6),
                          Text('Tokens: ${availableTokens.floor()}'),
                          if (inv['updatedAt']?.toString().isNotEmpty ?? false) ...[
                            const SizedBox(height: 6),
                            Text('Atualizado em: ${inv['updatedAt']}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isProcessingSale
                                  ? null
                                  : () => _showSellDialog(
                                      inv['startupId']?.toString() ?? '',
                                      inv['name']?.toString() ?? '',
                                      availableTokens),
                              child: Text(
                                _isProcessingSale ? 'Processando...' : 'Vender Tokens',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 28),

              // Histórico de transações
              const Text('Histórico de Transações',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              if (history.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text(
                      'Seu histórico aparecerá aqui após o primeiro investimento.',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                Column(
                  children: history.map((entry) {
                    final tipo = entry['tipo']?.toString() ?? 'aporte';
                    final isVenda = tipo == 'venda';
                    final isDeposito = tipo == 'deposito';
                    final iconData = isDeposito
                        ? Icons.add_card
                        : (isVenda ? Icons.arrow_upward : Icons.arrow_downward);
                    final iconColor = isDeposito
                        ? Colors.blue
                        : (isVenda ? Colors.green : Colors.red);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: iconColor.withAlpha(30),
                                shape: BoxShape.circle),
                            child: Icon(iconData, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry['startupNome']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                if (entry['createdAt']?.toString().isNotEmpty ?? false)
                                  Text(entry['createdAt'].toString(),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isVenda || isDeposito ? '+' : '-'}R\$ ${_parseDouble(entry['amount']).toStringAsFixed(2).replaceAll('.', ',')}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isVenda || isDeposito
                                        ? Colors.green
                                        : Colors.red),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: iconColor.withAlpha(20),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                    isDeposito ? 'depósito' : tipo,
                                    style: TextStyle(
                                        fontSize: 11, color: iconColor)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context, _userData),
                  child: const Text('Voltar para Home',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
