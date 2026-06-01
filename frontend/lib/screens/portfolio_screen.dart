// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Tela de Carteira com gráfico de valorização, depósito e histórico
//
// Esta tela exibe o portfólio completo do investidor:
//   - Saldo disponível e total investido
//   - Gráfico de valorização com 5 períodos e tooltip interativo
//   - Gráfico de pizza com distribuição da carteira por startup
//   - Lista de investimentos ativos com botão de venda
//   - Histórico completo de transações (aportes, vendas, depósitos)

// Importa funções matemáticas (min, max) para calcular escala do gráfico
import 'dart:math';

// Importa o pacote de gráficos fl_chart para LineChart e PieChart
import 'package:fl_chart/fl_chart.dart';

// Importa o kit de widgets visuais do Flutter
import 'package:flutter/material.dart';

// Importa o pacote HTTP para comunicação com o backend
import 'package:http/http.dart' as http;

// Importa ferramentas para codificar/decodificar JSON
import 'dart:convert';

// Importa o serviço de sessão para salvar atualizações localmente
import '../services/session_service.dart';

// Importa as cores do tema do projeto
import '../theme/app_colors.dart';

// StatefulWidget porque os dados do usuário, período do gráfico e transações mudam
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  Map<String, dynamic> _userData = {};  // Dados do usuário logado
  bool _initialized = false;             // Garante inicialização única
  bool _isProcessingSale = false;        // Bloqueia múltiplos cliques em "Vender"

  // Guarda o último valor investido para manter o gráfico visível mesmo após vender tudo
  double _lastTotalInvested = 0.0;

  // Período selecionado para o gráfico de valorização
  // 0=Diário, 1=Semanal, 2=Mensal, 3=6 meses, 4=Anual (YTD)
  int _selectedPeriod = 2;
  final List<String> _periods = ['Diário', 'Semanal', 'Mensal', '6 meses', 'Anual'];

  // Converte qualquer valor (int, double, String) para double de forma segura.
  // Evita erros caso o backend retorne números como strings.
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  // Transforma o mapa de tokens do usuário em uma lista de investimentos estruturados.
  // Cada entrada representa uma startup na qual o usuário possui tokens.
  List<Map<String, dynamic>> _extractInvestments(Map<String, dynamic> tokens) {
    final investments = <Map<String, dynamic>>[];
    for (final entry in tokens.entries) {
      final tokenData = entry.value;
      if (tokenData is Map) {
        investments.add({
          'startupId': entry.key.toString(),                        // ID da startup (chave do mapa)
          'name': tokenData['startupNome'] ?? entry.key,           // Nome da startup
          'valor': _parseDouble(tokenData['valor']),               // Valor total investido em R$
          'tokens': _parseDouble(tokenData['tokens']),             // Quantidade de tokens em posse
          'tokenPrice': _parseDouble(tokenData['tokenPrice']),     // Preço unitário do token
          'updatedAt': tokenData['updatedAt']?.toString() ?? '',   // Data da última atualização
        });
      }
    }
    return investments;
  }

  // Transforma o histórico de aportes em uma lista de transações para exibição.
  // Se não houver histórico, cria entradas a partir dos tokens existentes como fallback.
  List<Map<String, dynamic>> _extractHistory(dynamic rawHistory, Map<String, dynamic> tokens) {
    final history = <Map<String, dynamic>>[];

    if (rawHistory is List) {
      // Percorre o histórico do mais recente para o mais antigo (.reversed)
      for (final entry in rawHistory.reversed) {
        if (entry is Map) {
          history.add({
            'startupNome': entry['startupNome']?.toString() ?? 'Startup',
            'amount': _parseDouble(entry['amount']),
            'tokens': _parseDouble(entry['tokensQuantity'] ?? entry['tokens']),
            'createdAt': entry['createdAt']?.toString() ?? '',
            'tipo': entry['tipo']?.toString() ?? 'aporte', // 'aporte', 'venda' ou 'deposito'
          });
        }
      }
    }

    // Fallback: se não há histórico mas há tokens, exibe os tokens como aportes
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

  // Gera pontos simulados do gráfico de valorização baseados no total investido.
  // Usa um gerador de números aleatórios com seed fixo para ser consistente entre renders
  // (os pontos não mudam a cada reconstrução do widget).
  List<FlSpot> _gerarPontosGrafico(double totalInvestido, int periodo) {
    if (totalInvestido <= 0) return []; // Sem investimento → sem pontos

    // Define a quantidade de pontos conforme o período selecionado
    final int numPontos;
    switch (periodo) {
      case 0: numPontos = 24; break; // Diário: 24 pontos = 24 horas
      case 1: numPontos = 7;  break; // Semanal: 7 pontos = 7 dias
      case 2: numPontos = 30; break; // Mensal: 30 pontos = 30 dias
      case 3: numPontos = 26; break; // 6 meses: 26 pontos = 26 semanas
      case 4:                        // Anual (YTD): semanas desde 1° de janeiro até hoje
        final agora = DateTime.now();
        numPontos = ((agora.difference(DateTime(agora.year, 1, 1)).inDays) / 7).ceil().clamp(1, 52);
        break;
      default: numPontos = 30;
    }

    // Random com seed determinístico: mesmo período + mesmo total = mesmos pontos
    final rng = Random(periodo * 1000 + totalInvestido.toInt());
    final spots = <FlSpot>[];
    double valor = totalInvestido;

    for (int i = 0; i < numPontos; i++) {
      // Simula variação entre -3% e +5% — leve tendência de alta (viés realista)
      final variacao = (rng.nextDouble() * 8 - 3) / 100;
      valor = valor * (1 + variacao);
      // FlSpot: ponto do gráfico com coordenadas (x, y)
      spots.add(FlSpot(i.toDouble(), double.parse(valor.toStringAsFixed(2))));
    }
    return spots;
  }

  // Busca os dados mais recentes do usuário no servidor.
  // Chamado pelo botão de atualizar na AppBar.
  Future<Map<String, dynamic>?> _fetchUserFromServer(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final resp = await http.get(Uri.parse('http://localhost:3000/api/usuario/$uid'));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        return Map<String, dynamic>.from(body['usuario'] ?? {});
      }
    } catch (_) {}
    return null; // Retorna null se houver erro de conexão
  }

  // Envia a requisição de venda de tokens ao backend e atualiza o estado local.
  Future<void> _sellTokens(String startupId, String startupName, double availableTokens, double quantity) async {
    // Validação: quantidade deve ser positiva e não exceder o disponível
    if (quantity <= 0 || quantity > availableTokens) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade inválida para venda.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessingSale = true); // Bloqueia novos cliques

    final uid = _userData['uid']?.toString() ?? '';
    try {
      // POST para o endpoint de venda com os dados da transação
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/venda'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'startupId': startupId, 'tokenQuantity': quantity}),
      );

      final body = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200) {
        // Atualiza o estado local com os dados retornados pelo servidor
        setState(() {
          _userData = {
            ..._userData,
            'saldoFicticio': body['saldoFicticio'] ?? _userData['saldoFicticio'],
            'tokens': body['tokens'] ?? _userData['tokens'],
            'historicoAportes': body['historicoAportes'] ?? _userData['historicoAportes'],
          };
        });
        await SessionService.saveUser(_userData); // Persiste localmente
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Venda de $quantity tokens de $startupName realizada!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['error'] ?? 'Erro ao registrar venda.'), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessingSale = false); // Libera novos cliques
    }
  }

  // Exibe o diálogo de venda de tokens com campo para informar a quantidade.
  Future<void> _showSellDialog(String startupId, String startupName, double availableTokens) async {
    final quantityController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vender tokens de $startupName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tokens disponíveis: ${availableTokens.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantidade a vender', hintText: 'Ex: 10'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final q = double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 0.0;
              if (q > 0) Navigator.of(context).pop(true); // Confirma apenas se quantidade válida
            },
            child: const Text('Vender'),
          ),
        ],
      ),
    );

    // Se o usuário confirmou, executa a venda
    if (result == true) {
      final q = double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 0.0;
      await _sellTokens(startupId, startupName, availableTokens, q);
    }
  }

  // Exibe o diálogo de depósito de saldo fictício.
  // Limite máximo de R$50.000 por depósito conforme regra de negócio.
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
            const Text('Adicione saldo à sua carteira para realizar investimentos.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: valorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor (máx. R\$ 50.000)', prefixText: 'R\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
              // Confirma apenas se o valor estiver no intervalo válido (0 a 50.000)
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

  // Envia a requisição de depósito ao backend e atualiza o saldo exibido.
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
        // Atualiza o saldo exibido com o novo valor retornado pelo servidor
        final novoSaldo = _parseDouble(body['saldoFicticio']);
        setState(() { _userData['saldoFicticio'] = novoSaldo; });
        await SessionService.saveUser(_userData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Depósito de R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')} realizado!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(body['error'] ?? 'Erro ao realizar depósito.'), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível conectar ao servidor.'), backgroundColor: Colors.red),
      );
    }
  }

  // Constrói o gráfico de pizza mostrando a distribuição do portfólio por startup.
  // Cada fatia representa o percentual de uma startup no total investido.
  Widget _buildAllocationChart(List<Map<String, dynamic>> investments) {
    final totalInvested = investments.fold<double>(0.0, (sum, item) => sum + _parseDouble(item['valor']));
    // Paleta de cores para as fatias — ciclica para suportar qualquer número de startups
    final colors = [Colors.indigo, Colors.green, Colors.orange, Colors.purple, Colors.blue, Colors.teal, Colors.red];

    // Cria uma fatia (PieChartSectionData) para cada investimento
    final sections = investments.asMap().entries.map((entry) {
      final i = entry.key;
      final inv = entry.value;
      final value = _parseDouble(inv['valor']);
      final percent = totalInvested > 0 ? (value / totalInvested) * 100 : 0.0;
      return PieChartSectionData(
        color: colors[i % colors.length],    // Cor ciclica da paleta
        value: value,                          // Valor em R$ (tamanho da fatia)
        title: '${inv['name']?.toString().split(' ').first ?? ''}\n${percent.toStringAsFixed(0)}%',
        radius: 70,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return PieChart(PieChartData(sections: sections, centerSpaceRadius: 36, sectionsSpace: 4));
  }

  // Gera o label (rótulo) do eixo X do gráfico conforme o período e o índice do ponto.
  // Retorna string vazia para pontos sem rótulo (espaçamento adequado).
  String _xLabel(int i) {
    switch (_selectedPeriod) {
      case 0: // Diário: mostra a hora a cada 4 pontos (0h, 4h, 8h...)
        return i % 4 == 0 ? '${i}h' : '';
      case 1: // Semanal: mostra o nome abreviado de cada dia
        const dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
        return i < dias.length ? dias[i] : '';
      case 2: // Mensal: mostra o número do dia a cada 5 dias
        if (i == 0) return '1';
        if ((i + 1) % 5 == 0) return '${i + 1}';
        return '';
      case 3: // 6 meses: mostra o mês a cada 4 semanas (~1 mês)
        if (i % 4 != 0) return '';
        final date3 = DateTime.now().subtract(Duration(days: (25 - i) * 7));
        const m3 = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
        return m3[date3.month - 1];
      case 4: // Anual: mostra o mês a cada 4 semanas desde janeiro
        if (i % 4 != 0) return '';
        final date4 = DateTime(DateTime.now().year, 1, 1).add(Duration(days: i * 7));
        const m4 = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
        return m4[(date4.month - 1) % 12];
      default:
        return '';
    }
  }

  // Constrói o gráfico de linha de valorização com tooltip interativo.
  // hasActiveInvestments: se false, exibe banner informando que é dado histórico.
  Widget _buildValorizacaoChart(double totalInvestido, {bool hasActiveInvestments = true}) {
    final spots = _gerarPontosGrafico(totalInvestido, _selectedPeriod);

    // Se não há dados para exibir, mostra mensagem amigável
    if (spots.isEmpty) {
      return const Center(child: Text('Realize um investimento para ver a valorização.', style: TextStyle(color: Colors.grey)));
    }

    // Calcula os limites Y para a escala do gráfico
    final minY = spots.map((s) => s.y).reduce(min);
    final maxY = spots.map((s) => s.y).reduce(max);
    final padding = (maxY - minY) * 0.15; // 15% de margem acima e abaixo

    // Calcula a variação percentual entre o primeiro e o último ponto
    final ultimo = spots.last.y;
    final primeiro = spots.first.y;
    final variacao = primeiro > 0 ? ((ultimo - primeiro) / primeiro) * 100 : 0.0;
    final isPositivo = variacao >= 0;
    final lineColor = isPositivo ? Colors.green : Colors.red; // Verde = alta, Vermelho = baixa

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner informativo quando exibe dados históricos (usuário não tem investimentos ativos)
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

        // Exibe a variação percentual do período com ícone direcional
        Row(
          children: [
            Text(
              '${isPositivo ? '+' : ''}${variacao.toStringAsFixed(2)}%',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: lineColor),
            ),
            const SizedBox(width: 8),
            Icon(isPositivo ? Icons.trending_up : Icons.trending_down, color: lineColor),
          ],
        ),
        const SizedBox(height: 4),
        Text('no período selecionado', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 16),

        // O gráfico de linha propriamente dito (fl_chart LineChart)
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: minY - padding, // Limite inferior do eixo Y com margem
              maxY: maxY + padding, // Limite superior do eixo Y com margem
              clipData: const FlClipData.all(), // Corta a linha nos limites do gráfico

              // Grade de fundo: apenas linhas horizontais sutis
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),

              borderData: FlBorderData(show: false), // Remove a borda do gráfico

              // Configuração dos rótulos dos eixos
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),   // Sem rótulos à esquerda
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),    // Sem rótulos no topo
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),  // Sem rótulos à direita
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28, // Espaço reservado para os rótulos do eixo X
                    interval: 1,      // Verifica cada ponto (a função _xLabel decide o que mostrar)
                    getTitlesWidget: (value, meta) {
                      final label = _xLabel(value.toInt());
                      if (label.isEmpty) return const SizedBox.shrink(); // Não exibe se vazio
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),

              // Configuração do tooltip que aparece ao tocar no gráfico
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,  // Habilita detecção de toque nativa do fl_chart
                touchSpotThreshold: 20,      // Raio de sensibilidade do toque em pixels

                // Indicador visual no ponto tocado: linha tracejada vertical + círculo
                getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes.map((_) {
                  return TouchedSpotIndicatorData(
                    FlLine(color: lineColor.withAlpha(120), strokeWidth: 1.5, dashArray: [4, 4]), // Linha tracejada
                    FlDotData(
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 5,
                        color: Colors.white,        // Centro branco
                        strokeWidth: 2.5,
                        strokeColor: lineColor,     // Borda colorida
                      ),
                    ),
                  );
                }).toList(),

                // Tooltip (caixa de informação) que aparece ao tocar
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.indigo.shade900, // Fundo azul escuro
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  fitInsideHorizontally: true, // Garante que o tooltip não sai pela lateral
                  fitInsideVertically: true,   // Garante que o tooltip não sai pelo topo/base
                  getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                    final label = _xLabel(s.x.toInt());
                    return LineTooltipItem(
                      label.isNotEmpty ? '$label\n' : '',       // Rótulo do eixo X (hora/dia/mês)
                      const TextStyle(color: Colors.white60, fontSize: 10),
                      children: [
                        TextSpan(
                          text: 'R\$ ${s.y.toStringAsFixed(2).replaceAll('.', ',')}', // Valor em R$
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              // A linha do gráfico propriamente dita
              lineBarsData: [
                LineChartBarData(
                  spots: spots,       // Os pontos gerados por _gerarPontosGrafico
                  isCurved: true,     // Suaviza a linha (curva bezier)
                  color: lineColor,   // Verde para alta, vermelho para baixa
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false), // Não mostra pontos individuais

                  // Área preenchida abaixo da linha (semi-transparente)
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor.withAlpha(30),
                  ),
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
    // Lê os argumentos de navegação se a tela não foi inicializada ainda
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final user = (arguments is Map) ? arguments : <String, dynamic>{};
    if (!_initialized && user.isNotEmpty) {
      _userData = {...user};
      _initialized = true;
    }
    final populatedUser = _initialized ? _userData : user;

    // Extrai dados do usuário para uso na interface
    final name = populatedUser['nomeCompleto']?.toString() ?? 'Investidor';
    final balance = _parseDouble(populatedUser['saldoFicticio']);

    // Converte o mapa de tokens para tipo seguro
    final tokens = <String, dynamic>{};
    final rawTokens = populatedUser['tokens'];
    if (rawTokens is Map) {
      for (final entry in rawTokens.entries) {
        tokens[entry.key.toString()] = entry.value;
      }
    }

    final investments = _extractInvestments(tokens);
    final totalInvested = investments.fold<double>(0.0, (sum, item) => sum + _parseDouble(item['valor']));

    // Guarda o total investido para manter o gráfico visível mesmo após vender tudo
    if (totalInvested > 0) _lastTotalInvested = totalInvested;
    final chartTotal = _lastTotalInvested;

    // Percentual do saldo alocado em investimentos (entre 0 e 1)
    final allocation = balance > 0 ? (totalInvested / balance).clamp(0.0, 1.0) : 0.0;
    final history = _extractHistory(populatedUser['historicoAportes'], tokens);

    // PopScope: intercepta o botão "voltar" para retornar _userData atualizado
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
            // Botão para buscar dados frescos do servidor
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
              // Saudação personalizada
              Text('Olá, $name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // ===== CARD: SALDO E ALOCAÇÃO =====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10, offset: Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Saldo disponível', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    // Saldo total em destaque com fonte grande
                    Text(
                      'R\$ ${balance.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    _infoRow('Total investido', 'R\$ ${totalInvested.toStringAsFixed(2).replaceAll('.', ',')}'),
                    const SizedBox(height: 8),
                    _infoRow('Saldo livre', 'R\$ ${(balance - totalInvested).toStringAsFixed(2).replaceAll('.', ',')}'),
                    const SizedBox(height: 18),
                    const Text('Alocação da carteira', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    // Barra de progresso visual do percentual alocado
                    LinearProgressIndicator(value: allocation),
                    const SizedBox(height: 8),
                    Text('${(allocation * 100).toStringAsFixed(0)}% alocado', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    // Botão para abrir o diálogo de depósito
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showDepositDialog,
                        icon: const Icon(Icons.add_card, color: AppColors.primary),
                        label: const Text('Depositar Saldo', style: TextStyle(color: AppColors.primary)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ===== SEÇÃO: GRÁFICO DE VALORIZAÇÃO =====
              const Text('Valorização dos investimentos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10, offset: Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seletor de período — chips horizontais roláveis
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
                              // Ao selecionar, atualiza o período e reconstrói o gráfico
                              onSelected: (_) => setState(() => _selectedPeriod = i),
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : Colors.black,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // O gráfico de linha — usa chartTotal para manter visível após vendas
                    _buildValorizacaoChart(chartTotal, hasActiveInvestments: totalInvested > 0),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ===== SEÇÃO: DISTRIBUIÇÃO DA CARTEIRA (pizza) =====
              // Só aparece se o usuário tiver investimentos ativos
              if (investments.isNotEmpty) ...[
                const Text('Distribuição da Carteira', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.05), blurRadius: 10, offset: Offset(0, 6))],
                  ),
                  child: SizedBox(height: 200, child: _buildAllocationChart(investments)),
                ),
                const SizedBox(height: 24),
              ],

              // ===== SEÇÃO: INVESTIMENTOS EM CARTEIRA =====
              const Text('Investimentos em Carteira', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),

              // Mensagem quando não há investimentos
              if (investments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Você ainda não realizou nenhum aporte.', style: TextStyle(fontSize: 16)),
                      SizedBox(height: 12),
                      Text('Explore o catálogo de startups e simule seu primeiro investimento.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else
                // Card para cada startup na carteira com botão de venda
                Column(
                  children: investments.map((inv) {
                    final availableTokens = _parseDouble(inv['tokens']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv['name']?.toString() ?? 'Startup', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Valor aportado: R\$ ${_parseDouble(inv['valor']).toStringAsFixed(2).replaceAll('.', ',')}'),
                          const SizedBox(height: 6),
                          Text('Tokens: ${availableTokens.toStringAsFixed(2)}'),
                          if (inv['updatedAt']?.toString().isNotEmpty ?? false) ...[
                            const SizedBox(height: 6),
                            Text('Atualizado em: ${inv['updatedAt']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                          const SizedBox(height: 12),
                          // Botão de venda — desabilitado durante processamento
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isProcessingSale
                                  ? null
                                  : () => _showSellDialog(inv['startupId']?.toString() ?? '', inv['name']?.toString() ?? '', availableTokens),
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

              // ===== SEÇÃO: HISTÓRICO DE TRANSAÇÕES =====
              const Text('Histórico de Transações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),

              if (history.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Seu histórico aparecerá aqui após o primeiro investimento.', style: TextStyle(color: Colors.grey)),
                )
              else
                // Lista de transações com ícone e cor conforme o tipo (aporte/venda/depósito)
                Column(
                  children: history.map((entry) {
                    final tipo = entry['tipo']?.toString() ?? 'aporte';
                    final isVenda = tipo == 'venda';
                    final isDeposito = tipo == 'deposito';
                    // Ícone e cor variam conforme o tipo de transação
                    final iconData = isDeposito ? Icons.add_card : (isVenda ? Icons.arrow_upward : Icons.arrow_downward);
                    final iconColor = isDeposito ? Colors.blue : (isVenda ? Colors.green : Colors.red);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          // Ícone circular colorido indicando o tipo da transação
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: iconColor.withAlpha(30), shape: BoxShape.circle),
                            child: Icon(iconData, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry['startupNome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (entry['createdAt']?.toString().isNotEmpty ?? false)
                                  Text(entry['createdAt'].toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Valor com sinal: + para depósito/venda, - para aporte
                              Text(
                                '${isVenda ? '+' : isDeposito ? '+' : '-'}R\$ ${_parseDouble(entry['amount']).toStringAsFixed(2).replaceAll('.', ',')}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: isVenda || isDeposito ? Colors.green : Colors.red),
                              ),
                              // Badge do tipo de transação
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: iconColor.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                                child: Text(isDeposito ? 'depósito' : tipo, style: TextStyle(fontSize: 11, color: iconColor)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 28),

              // Botão para voltar à Home retornando os dados atualizados
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context, _userData),
                  child: const Text('Voltar para Home', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para exibir uma linha label: valor lado a lado
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
