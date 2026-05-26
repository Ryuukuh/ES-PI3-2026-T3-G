import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({Key? key}) : super(key: key);

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<dynamic> _allStartups = [];
  List<dynamic> _filteredStartups = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedStage = 'Todos';

  // Lista de estágios exibida nos botões
  final List<String> _stages = [
    'Todos',
    'Ideação',
    'Validação',
    'Operação',
    'Tração',
  ];

  @override
  void initState() {
    super.initState();
    _fetchStartups();
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
          if (text.isNotEmpty) {
            return text;
          }
        }
      }
    }
    return fallback;
  }

  double _getFirstNumericField(
    dynamic item,
    List<String> keys,
    double fallback,
  ) {
    if (item is Map) {
      for (final key in keys) {
        if (item.containsKey(key) && item[key] != null) {
          final value = item[key].toString().trim();
          final parsed = double.tryParse(value.replaceAll(',', '.'));
          if (parsed != null) {
            return parsed;
          }
        }
      }
    }
    return fallback;
  }

  double _getTokenPrice(dynamic item) {
    final explicit = _getFirstNumericField(item, [
      'precoToken',
      'valorToken',
      'preco',
      'valor',
    ], 0.0);
    if (explicit > 0) return explicit;

    final capital = _getFirstNumericField(item, [
      'capital_aportado',
      'capitalAportado',
      'capital',
    ], 0.0);
    final tokens = _getFirstNumericField(item, [
      'tokens_emitidos',
      'tokensEmitidos',
      'tokens',
    ], 0.0);
    if (capital > 0 && tokens > 0) {
      return capital / tokens;
    }
    return 0.0;
  }

  Future<void> _fetchStartups() async {
    final url = Uri.parse('http://localhost:3000/api/startups');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _allStartups = data ?? [];
          _filteredStartups = data ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Erro ao carregar startups (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Não foi possível conectar ao servidor backend.';
        _isLoading = false;
      });
    }
  }

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

  void _filterStartups(String stage) {
    setState(() {
      _selectedStage = stage;
      if (stage == 'Todos') {
        _filteredStartups = _allStartups;
      } else {
        final normalizedFilter = _normalizeText(stage);
        _filteredStartups = _allStartups.where((startup) {
          final startupStage = _normalizeText(
            _getFirstNonEmptyField(startup, ['estagio', 'fase', 'stage'], ''),
          );
          return startupStage == normalizedFilter;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Catálogo de Startups',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.indigo[900],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Barra Horizontal de Filtros por Estágio
          Container(
            color: Colors.white,
            height: 60,
            width: double.infinity,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: _stages.length,
              itemBuilder: (context, index) {
                final stage = _stages[index];
                final isSelected = _selectedStage == stage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text(stage),
                    selected: isSelected,
                    selectedColor: Colors.indigo[900],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (_) => _filterStartups(stage),
                  ),
                );
              },
            ),
          ),

          // 2. Área de Exibição dos Cards das Startups
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  )
                : _filteredStartups.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma startup encontrada para: $_selectedStage',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredStartups.length,
                    itemBuilder: (context, index) {
                      final startup = _filteredStartups[index];

                      final startupName = _getFirstNonEmptyField(startup, [
                        'nome',
                        'nome_startup',
                        'nomeStartup',
                        'startupNome',
                        'name',
                        'titulo',
                        'startup',
                      ], 'Startup Sem Nome');

                      final stageDisplay = _getFirstNonEmptyField(startup, [
                        'estagio',
                        'fase',
                        'stage',
                      ], 'Estágio Desconhecido').toUpperCase();

                      final description = _getFirstNonEmptyField(startup, [
                        'descricao',
                        'description',
                        'resumo',
                        'sobre',
                      ], 'Sem descrição disponível.');

                      final tokenValue = _getTokenPrice(startup);

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/startup-detalhes',
                              arguments: startup,
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cabeçalho do card com nome e estágio
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        startupName,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.blue),
                                      ),
                                      child: Text(
                                        stageDisplay,
                                        style: TextStyle(
                                          color: Colors.blue[800],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),

                                // Exibe o valor do token
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Valor do Token',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tokenValue > 0
                                              ? 'R\$ ${tokenValue.toStringAsFixed(2).replaceAll('.', ',')}'
                                              : 'Não disponível',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
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
    );
  }
}
