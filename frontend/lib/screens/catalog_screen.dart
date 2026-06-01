// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor: Rafael Elias Correa | RA: 18726497
// Catálogo de startups com filtros por estágio e setor.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  Map<String, dynamic> _userData = {
    'uid': '',
    'nomeCompleto': 'Investidor',
    'email': 'E-mail não informado',
    'cpf': 'CPF não informado',
    'telefone': 'Telefone não informado',
    'saldoFicticio': 0.0,
    'tokens': {},
  };

  List<dynamic> _allStartups = [];
  List<dynamic> _filteredStartups = [];
  bool _isLoading = true;
  String _errorMessage = '';

  String _selectedStage = 'Todos';
  String _selectedSector = 'Todos';

  final List<String> _stages = ['Todos', 'Ideação', 'Validação', 'Operação', 'Tração'];
  List<String> _sectors = ['Todos'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final argumentos = ModalRoute.of(context)?.settings.arguments;
    if (argumentos is Map) {
      _userData = {..._userData, ...Map<String, dynamic>.from(argumentos)};
    }
  }

  // Lê o primeiro campo não-vazio de uma lista de candidatos.
  // Necessário porque o Firestore não tem campo único padronizado para nome/estágio/setor.
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

  double _getFirstNumericField(dynamic item, List<String> keys, double fallback) {
    if (item is Map) {
      for (final key in keys) {
        if (item.containsKey(key) && item[key] != null) {
          final parsed = double.tryParse(item[key].toString().trim().replaceAll(',', '.'));
          if (parsed != null) return parsed;
        }
      }
    }
    return fallback;
  }

  double _getTokenPrice(dynamic item) {
    final explicit = _getFirstNumericField(
        item, ['precoToken', 'valorToken', 'preco', 'valor'], 0.0);
    if (explicit > 0) return explicit;
    // Fallback: calcula preço unitário = capital_aportado / tokens_emitidos
    final capital = _getFirstNumericField(
        item, ['capital_aportado', 'capitalAportado', 'capital'], 0.0);
    final tokens = _getFirstNumericField(
        item, ['tokens_emitidos', 'tokensEmitidos', 'tokens'], 0.0);
    if (capital > 0 && tokens > 0) return capital / tokens;
    return 0.0;
  }

  Future<void> _fetchStartups() async {
    try {
      final response = await http.get(
          Uri.parse('http://localhost:3000/api/startups'),
          headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final startups = data ?? [];

        final sectors = <String>{'Todos'};
        for (final item in startups) {
          final sector =
              _getFirstNonEmptyField(item, ['setor', 'area', 'segmento'], '');
          if (sector.isNotEmpty) sectors.add(sector);
        }

        setState(() {
          _allStartups = startups;
          _filteredStartups = startups;
          _sectors = sectors.toList()..sort();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Erro ao carregar startups (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'Não foi possível conectar ao servidor backend.';
        _isLoading = false;
      });
    }
  }

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

  // Remove acentos para comparação normalizada dos filtros.
  String _normalizeText(String text) {
    var str = text.toLowerCase().trim();
    str = str.replaceAll(RegExp(r'[àáâãäå]'), 'a');
    str = str.replaceAll(RegExp(r'[èéêë]'), 'e');
    str = str.replaceAll(RegExp(r'[ìíîï]'), 'i');
    str = str.replaceAll(RegExp(r'[òóôõö]'), 'o');
    str = str.replaceAll(RegExp(r'[ùúûü]'), 'u');
    str = str.replaceAll(RegExp(r'[ç]'), 'c');
    return str;
  }

  void _filterStartups({String? stage, String? sector}) {
    if (stage != null) _selectedStage = stage;
    if (sector != null) _selectedSector = sector;

    setState(() {
      _filteredStartups = _allStartups.where((startup) {
        final startupStage = _normalizeText(
            _getFirstNonEmptyField(startup, ['estagio', 'fase', 'stage'], ''));
        final startupSector = _normalizeText(
            _getFirstNonEmptyField(startup, ['setor', 'area', 'segmento'], ''));

        final stageMatch =
            _selectedStage == 'Todos' || startupStage == _normalizeText(_selectedStage);
        final sectorMatch =
            _selectedSector == 'Todos' || startupSector == _normalizeText(_selectedSector);

        return stageMatch && sectorMatch;
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchStartups();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope retorna _userData atualizado à tela anterior após compras de tokens
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _userData);
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('Catálogo de Startups',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.indigo[900],
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Column(
          children: [
            // Barra de filtros
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Estágio',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _stages.length,
                      itemBuilder: (context, index) {
                        final stage = _stages[index];
                        final isSelected = _selectedStage == stage;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(stage, style: const TextStyle(fontSize: 13)),
                            selected: isSelected,
                            selectedColor: Colors.indigo[900],
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) => _filterStartups(stage: stage),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_sectors.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text('Setor',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _sectors.length,
                        itemBuilder: (context, index) {
                          final sector = _sectors[index];
                          final isSelected = _selectedSector == sector;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(sector, style: const TextStyle(fontSize: 13)),
                              selected: isSelected,
                              selectedColor: Colors.indigo[900],
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (_) => _filterStartups(sector: sector),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Lista de startups
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Text(_errorMessage,
                              style: const TextStyle(color: Colors.red, fontSize: 16)))
                      : _filteredStartups.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhuma startup encontrada para: $_selectedStage / $_selectedSector',
                                style: const TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredStartups.length,
                              itemBuilder: (context, index) {
                                final startup = _filteredStartups[index];

                                final startupName = _getFirstNonEmptyField(startup,
                                    ['nome', 'nome_startup', 'nomeStartup', 'startupNome', 'name', 'titulo', 'startup'],
                                    'Startup Sem Nome');

                                final stageDisplay = _displayStage(
                                  _getFirstNonEmptyField(
                                      startup, ['estagio', 'fase', 'stage'], ''),
                                ).toUpperCase();

                                final description = _getFirstNonEmptyField(startup,
                                    ['descricao', 'description', 'resumo', 'sobre'],
                                    'Sem descrição disponível.');

                                final tokenValue = _getTokenPrice(startup);

                                return Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  child: InkWell(
                                    onTap: () async {
                                      final result = await Navigator.pushNamed(
                                        context,
                                        '/startup-detalhes',
                                        arguments: {'startup': startup, 'user': _userData},
                                      );
                                      if (result is Map<String, dynamic> &&
                                          result['user'] is Map<String, dynamic>) {
                                        _userData =
                                            Map<String, dynamic>.from(result['user']);
                                        setState(() {});
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(startupName,
                                                    style: const TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.indigo),
                                                    overflow: TextOverflow.ellipsis),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: Colors.blue),
                                                ),
                                                child: Text(stageDisplay,
                                                    style: TextStyle(
                                                        color: Colors.blue[800],
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: Colors.grey[700], fontSize: 14)),
                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text('Valor do Token',
                                                      style: TextStyle(
                                                          color: Colors.grey, fontSize: 12)),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    tokenValue > 0
                                                        ? 'R\$ ${tokenValue.toStringAsFixed(2).replaceAll('.', ',')}'
                                                        : 'Não disponível',
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15),
                                                  ),
                                                ],
                                              ),
                                              const Icon(Icons.arrow_forward_ios,
                                                  size: 16, color: Colors.grey),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
