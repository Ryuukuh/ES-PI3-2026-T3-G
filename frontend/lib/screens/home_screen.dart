import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Captura os argumentos enviados pela tela de Login adaptado para o Flutter Web
    final argumentos = ModalRoute.of(context)?.settings.arguments;

    String nomeUsuario = 'Investidor';
    String email = 'E-mail não informado';
    String cpf = 'CPF não informado';
    String telefone = 'Telefone não informado';
    double saldoFicticio = 0.0;
    Map<String, dynamic> tokens = {};

    if (argumentos is Map) {
      nomeUsuario = argumentos['nomeCompleto']?.toString() ?? nomeUsuario;
      email = argumentos['email']?.toString() ?? email;
      cpf = argumentos['cpf']?.toString() ?? cpf;
      telefone = argumentos['telefone']?.toString() ?? telefone;
      saldoFicticio =
          double.tryParse(argumentos['saldoFicticio']?.toString() ?? '0.0') ??
              0.0;
      if (argumentos['tokens'] is Map) {
        tokens = Map<String, dynamic>.from(argumentos['tokens'] as Map);
      }
    }

    double calcTotalInvested() {
      double total = 0.0;
      for (final tokenData in tokens.values) {
        if (tokenData is Map) {
          total += double.tryParse(tokenData['valor']?.toString() ?? '0.0') ?? 0.0;
        }
      }
      return total;
    }

    final totalInvested = calcTotalInvested();
    final availableBalance = (saldoFicticio - totalInvested).clamp(0.0, double.infinity);
    final allocation = saldoFicticio > 0 ? (totalInvested / saldoFicticio) : 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'MesclaInvest',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.indigo[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            tooltip: 'Perfil',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/perfil',
                arguments: {
                  'nomeCompleto': nomeUsuario,
                  'email': email,
                  'cpf': cpf,
                  'telefone': telefone,
                  'saldoFicticio': saldoFicticio,
                  'tokens': tokens,
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            tooltip: 'Sair da Conta',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bloco Azul de Boas-vindas e exibição do Saldo do Firebase
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.indigo[900],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Olá, $nomeUsuario 👋',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Seu Saldo Disponível',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'R\$ ${saldoFicticio.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Cartão de Resumo da Carteira (Base para as Issues #14 e #15)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pie_chart, color: Colors.indigo[900]),
                          const SizedBox(width: 10),
                          const Text(
                            'Minha Carteira',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        totalInvested > 0
                            ? 'Você possui R\$ ${totalInvested.toStringAsFixed(2).replaceAll('.', ',')} investidos em startups.'
                            : 'Você ainda não possui tokens de startups contratados.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: allocation.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Saldo livre: R\$ ${availableBalance.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${(allocation * 100).toStringAsFixed(0)}% alocado',
                            style: const TextStyle(color: Colors.indigo),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/carteira',
                              arguments: {
                                'nomeCompleto': nomeUsuario,
                                'email': email,
                                'cpf': cpf,
                                'telefone': telefone,
                                'saldoFicticio': saldoFicticio,
                                'tokens': tokens,
                              },
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.indigo),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Ver Carteira', style: TextStyle(color: Colors.indigo)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Ações: Botão de Destaque para abrir o Catálogo (Issue #12)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'O que deseja fazer hoje?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      // Direciona para a rota do catálogo geral quando iniciarmos a Issue #12
                      Navigator.pushNamed(context, '/catalogo');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.indigo[800]!, Colors.blue[700]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(33, 150, 243, 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.business_center,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Explorar Mercado',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Conheça as 8 startups e invista em tokens oficiais.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
