import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({Key? key}) : super(key: key);

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  List<Map<String, dynamic>> _extractInvestments(Map<String, dynamic> tokens) {
    final investments = <Map<String, dynamic>>[];
    for (final item in tokens.entries) {
      final tokenData = item.value;
      if (tokenData is Map) {
        investments.add({
          'name': tokenData['startupNome'] ?? item.key,
          'valor': _parseDouble(tokenData['valor']),
          'tokens': _parseDouble(tokenData['tokens']),
          'invested': _parseDouble(tokenData['invested']),
        });
      }
    }
    return investments;
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final user = (arguments is Map) ? arguments : <String, dynamic>{};

    final name = user['nomeCompleto']?.toString() ?? 'Investidor';
    final balance = _parseDouble(user['saldoFicticio']);
    final tokens = <String, dynamic>{};
    final rawTokens = user['tokens'];
    if (rawTokens is Map<dynamic, dynamic>) {
      for (final entry in rawTokens.entries) {
        tokens[entry.key.toString()] = entry.value;
      }
    }

    final investments = _extractInvestments(tokens);
    final totalInvested = investments.fold<double>(0.0, (sum, item) {
      final valor = item['valor'];
      final parsed = valor is double
          ? valor
          : double.tryParse(valor?.toString() ?? '0.0') ?? 0.0;
      return sum + parsed;
    });
    final availableBalance = balance - totalInvested;
    final allocation = balance > 0 ? (totalInvested / balance) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Minha Carteira'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, $name',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
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
                    offset: Offset(0, 6),
                  ),
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
                  _infoRow('Total investido', 'R\$ ${totalInvested.toStringAsFixed(2).replaceAll('.', ',')}'),
                  const SizedBox(height: 8),
                  _infoRow('Saldo livre', 'R\$ ${availableBalance.toStringAsFixed(2).replaceAll('.', ',')}'),
                  const SizedBox(height: 18),
                  const Text('Alocação da carteira', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: allocation.clamp(0.0, 1.0)),
                  const SizedBox(height: 8),
                  Text('${(allocation * 100).toStringAsFixed(0)}% alocado', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Investimentos em Carteira',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            if (investments.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Você ainda não realizou nenhum aporte.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Explore o catálogo de startups e simule seu primeiro investimento.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: investments.map((investment) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          investment['name']?.toString() ?? 'Startup',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Valor aportado: R\$ ${investment['valor'].toStringAsFixed(2).replaceAll('.', ',')}'),
                        const SizedBox(height: 6),
                        Text('Tokens estimados: ${investment['tokens'].toStringAsFixed(2)}'),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar para Home', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
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
