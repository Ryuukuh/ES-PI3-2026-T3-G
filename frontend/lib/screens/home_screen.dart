// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor: Rafael Elias Correa | RA: 18726497
// Dashboard principal pós-login: saldo, carteira resumida e startups em destaque.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/session_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> _userData = {
    'uid': '',
    'nomeCompleto': 'Investidor',
    'email': 'E-mail não informado',
    'cpf': 'CPF não informado',
    'telefone': 'Telefone não informado',
    'saldoFicticio': 0.0,
    'tokens': {},
  };

  bool _initialized = false;
  bool _isLoadingStartups = true;
  String _startupError = '';
  List<dynamic> _featuredStartups = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final argumentos = ModalRoute.of(context)?.settings.arguments;
      if (argumentos is Map) {
        _userData = {..._userData, ...Map<String, dynamic>.from(argumentos)};
      }
      _normalizeUserData();
      _fetchStartups();
      _initialized = true;
    }
  }

  void _normalizeUserData() {
    final saldoRaw = _userData['saldoFicticio'];
    // JSON pode entregar saldo como String
    if (saldoRaw is String) {
      _userData['saldoFicticio'] = double.tryParse(saldoRaw.replaceAll(',', '.')) ?? 0.0;
    }
    if (_userData['tokens'] is! Map) _userData['tokens'] = {};
  }

  void _saveSession() => SessionService.saveUser(_userData);

  void _updateUser(Map<String, dynamic> updatedUser) {
    if (updatedUser.isEmpty) return;
    setState(() {
      _userData.addAll(updatedUser);
      _normalizeUserData();
    });
    _saveSession();
  }

  Future<void> _fetchUserFromServer() async {
    final uid = _userData['uid']?.toString() ?? '';
    if (uid.isEmpty) return;
    try {
      final resp = await http.get(Uri.parse('http://localhost:3000/api/usuario/$uid'));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        setState(() {
          _userData = {..._userData, ...Map<String, dynamic>.from(body['usuario'] ?? {})};
          _normalizeUserData();
        });
        _saveSession();
      }
    } catch (_) {}
  }

  Future<bool> _confirmLogout() async {
    final result = await showDialog<bool>(
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
    if (result == true) await SessionService.clearUser();
    return result == true;
  }

  Future<void> _fetchStartups() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/api/startups'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final startups = data is List ? data : [];
        setState(() {
          _featuredStartups = List<dynamic>.from(startups.take(3));
          _isLoadingStartups = false;
        });
      } else {
        setState(() {
          _startupError = 'Erro ao carregar startups (${response.statusCode})';
          _isLoadingStartups = false;
        });
      }
    } catch (_) {
      setState(() {
        _startupError = 'Não foi possível carregar o catálogo de startups.';
        _isLoadingStartups = false;
      });
    }
  }

  double _calcTotalInvested() {
    double total = 0.0;
    final tokens = _userData['tokens'];
    if (tokens is Map) {
      for (final tokenData in tokens.values) {
        if (tokenData is Map) {
          total += double.tryParse(tokenData['valor']?.toString() ?? '0.0') ?? 0.0;
        }
      }
    }
    return total;
  }

  List<Map<String, dynamic>> _getRecentAportes() {
    final recent = <Map<String, dynamic>>[];
    final historico = _userData['historicoAportes'];
    if (historico is List) {
      for (final entry in historico.reversed) {
        if (entry is Map) {
          recent.add({
            'startupNome': entry['startupNome']?.toString() ?? 'Startup',
            'amount': double.tryParse(entry['amount']?.toString() ?? '0.0') ?? 0.0,
            'createdAt': entry['createdAt']?.toString() ?? '',
          });
        }
        if (recent.length >= 3) break;
      }
    }
    return recent;
  }

  String _formatCurrency(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  // Firestore armazena estágios sem acento ('ideacao'); exibimos com acento.
  String _displayStage(String raw) {
    const map = {
      'ideacao': 'Ideação',
      'validacao': 'Validação',
      'operacao': 'Operação',
      'tracao': 'Tração',
    };
    return map[raw.toLowerCase().trim()] ?? raw;
  }

  @override
  Widget build(BuildContext context) {
    final nomeUsuario = _userData['nomeCompleto']?.toString() ?? 'Investidor';
    final saldoFicticio = _userData['saldoFicticio'] is double
        ? _userData['saldoFicticio'] as double
        : double.tryParse(_userData['saldoFicticio']?.toString() ?? '0.0') ?? 0.0;

    final totalInvested = _calcTotalInvested();
    final availableBalance = (saldoFicticio - totalInvested).clamp(0.0, double.infinity);
    final allocation = saldoFicticio > 0 ? (totalInvested / saldoFicticio) : 0.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('MesclaInvest',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.indigo[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Atualizar dados',
            onPressed: () async { await _fetchUserFromServer(); },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            tooltip: 'Perfil',
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/perfil', arguments: _userData);
              if (result is Map<String, dynamic>) _updateUser(result);
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            tooltip: 'Sair da Conta',
            onPressed: () async {
              final confirmed = await _confirmLogout();
              if (!context.mounted) return;
              if (confirmed) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com saldo
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
                  Text('Olá, $nomeUsuario 👋',
                      style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  const Text('Seu Saldo Disponível', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    'R\$ ${saldoFicticio.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card Minha Carteira
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pie_chart, color: Colors.indigo[900]),
                          const SizedBox(width: 10),
                          const Text('Minha Carteira',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Saldo livre', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(_formatCurrency(availableBalance),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Alocação', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                '${(allocation * 100).toStringAsFixed(0)}% alocado',
                                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text('Últimos aportes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ..._getRecentAportes().map((ap) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ap['startupNome'] ?? 'Startup',
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(ap['createdAt']?.toString() ?? '',
                                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text(_formatCurrency(ap['amount'] as double),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }),
                      if (_getRecentAportes().isEmpty) ...[
                        const Text(
                          'Nenhum aporte registrado ainda. Invista em uma startup para ver o histórico aqui.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final result = await Navigator.pushNamed(
                                context, '/carteira', arguments: _userData);
                            if (result is Map<String, dynamic>) _updateUser(result);
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
            const SizedBox(height: 24),

            // Startups em Destaque
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Startups em Destaque',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_isLoadingStartups)
                    const Center(child: CircularProgressIndicator())
                  else if (_startupError.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Text(_startupError, style: const TextStyle(color: Colors.red)),
                    )
                  else if (_featuredStartups.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: const Text('Nenhuma startup encontrada no catálogo no momento.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    SizedBox(
                      height: 230,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _featuredStartups.length,
                        itemBuilder: (context, index) {
                          final startup = _featuredStartups[index];

                          // Tenta múltiplos nomes de campo para compatibilidade com o Firestore
                          final startupName = startup['nome_startup']?.toString() ??
                              startup['nome']?.toString() ??
                              startup['title']?.toString() ??
                              startup['startupNome']?.toString() ?? 'Startup';

                          final stage = _displayStage(
                            startup['estagio']?.toString() ??
                            startup['fase']?.toString() ??
                            startup['stage']?.toString() ?? '',
                          );

                          final description = startup['descricao']?.toString() ??
                              startup['description']?.toString() ??
                              startup['resumo']?.toString() ?? 'Descrição não disponível.';

                          final tokenPrice = double.tryParse(
                            startup['precoToken']?.toString() ??
                            startup['valorToken']?.toString() ??
                            startup['preco']?.toString() ??
                            startup['valor']?.toString() ?? '0') ?? 0.0;

                          return GestureDetector(
                            onTap: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/startup-detalhes',
                                arguments: {'startup': startup, 'user': _userData},
                              );
                              if (result is Map<String, dynamic>) {
                                _updateUser(result['user'] ?? {});
                              }
                            },
                            child: Container(
                              width: 260,
                              margin: const EdgeInsets.only(right: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color.fromRGBO(0, 0, 0, 0.08),
                                      blurRadius: 10,
                                      offset: Offset(0, 6)),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(startupName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 10),
                                    Text(stage, style: const TextStyle(color: Colors.indigo)),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Text(description,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.grey)),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      tokenPrice > 0
                                          ? 'Token: R\$ ${tokenPrice.toStringAsFixed(2).replaceAll('.', ',')}'
                                          : 'Preço do token não informado',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                            context, '/catalogo', arguments: _userData);
                        if (result is Map<String, dynamic>) _updateUser(result);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.indigo),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Ver todas as startups',
                          style: TextStyle(color: Colors.indigo)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Atalho Explorar Mercado
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('O que deseja fazer hoje?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                          context, '/catalogo', arguments: _userData);
                      if (result is Map<String, dynamic>) _updateUser(result);
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
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51), shape: BoxShape.circle),
                            child: const Icon(Icons.business_center,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Explorar Mercado',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Conheça as 8 startups e invista em tokens oficiais.',
                                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
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
