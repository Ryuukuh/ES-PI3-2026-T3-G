// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Tela de Catálogo de Startups com filtros por estágio e setor
//
// Esta tela exibe todas as startups cadastradas no sistema.
// Permite filtrar por estágio de desenvolvimento e por setor de atuação.
// Ao clicar em uma startup, abre a tela de detalhes.

// Importa o kit de widgets visuais do Flutter
import 'package:flutter/material.dart';

// Importa o pacote HTTP para buscar startups do backend
import 'package:http/http.dart' as http;

// Importa ferramentas para decodificar JSON
import 'dart:convert';

// StatefulWidget porque a lista de startups é carregada após a tela abrir
// e o usuário pode aplicar filtros que mudam a exibição
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  // Dados do usuário logado — recebidos via argumentos de navegação
  Map<String, dynamic> _userData = {
    'uid': '',
    'nomeCompleto': 'Investidor',
    'email': 'E-mail não informado',
    'cpf': 'CPF não informado',
    'telefone': 'Telefone não informado',
    'saldoFicticio': 0.0,
    'tokens': {},
  };

  List<dynamic> _allStartups = [];       // Lista completa de startups (sem filtro)
  List<dynamic> _filteredStartups = [];  // Lista filtrada exibida na tela
  bool _isLoading = true;                // Controla o spinner de carregamento
  String _errorMessage = '';             // Mensagem de erro caso o carregamento falhe

  String _selectedStage = 'Todos';   // Filtro de estágio selecionado atualmente
  String _selectedSector = 'Todos';  // Filtro de setor selecionado atualmente

  // Lista fixa de estágios disponíveis para filtro
  final List<String> _stages = ['Todos', 'Ideação', 'Validação', 'Operação', 'Tração'];

  // Lista de setores — preenchida dinamicamente com os setores das startups carregadas
  List<String> _sectors = ['Todos'];

  // didChangeDependencies: lê os argumentos de navegação (dados do usuário).
  // Executado logo após a tela ter acesso ao contexto.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final argumentos = ModalRoute.of(context)?.settings.arguments;
    if (argumentos is Map) {
      // Mescla com os valores padrão — dados recebidos têm prioridade
      _userData = {
        ..._userData,
        ...Map<String, dynamic>.from(argumentos),
      };
    }
  }

  // Busca o primeiro campo não vazio de uma lista de campos candidatos em um objeto.
  // Usado para lidar com variações nos nomes de campos das startups.
  // Ex: _getFirstNonEmptyField(startup, ['nome', 'nome_startup', 'name'], 'Sem nome')
  String _getFirstNonEmptyField(dynamic item, List<String> keys, String fallback) {
    if (item is Map) {
      for (final key in keys) {
        if (item.containsKey(key) && item[key] != null) {
          final text = item[key].toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    }
    return fallback; // Retorna o valor padrão se nenhum campo for encontrado
  }

  // Similar ao anterior, mas para campos numéricos (retorna double).
  // Tenta converter cada campo para double até encontrar um válido.
  double _getFirstNumericField(dynamic item, List<String> keys, double fallback) {
    if (item is Map) {
      for (final key in keys) {
        if (item.containsKey(key) && item[key] != null) {
          final value = item[key].toString().trim();
          // .replaceAll(',', '.') converte vírgula decimal para ponto (padrão Dart)
          final parsed = double.tryParse(value.replaceAll(',', '.'));
          if (parsed != null) return parsed;
        }
      }
    }
    return fallback;
  }

  // Calcula o preço de um token da startup.
  // Tenta primeiro campos explícitos de preço; se não encontrar,
  // calcula como: capital_aportado ÷ tokens_emitidos
  double _getTokenPrice(dynamic item) {
    // Tenta campos diretos de preço primeiro
    final explicit = _getFirstNumericField(item, ['precoToken', 'valorToken', 'preco', 'valor'], 0.0);
    if (explicit > 0) return explicit;

    // Calcula a partir do capital aportado e quantidade de tokens emitidos
    final capital = _getFirstNumericField(item, ['capital_aportado', 'capitalAportado', 'capital'], 0.0);
    final tokens = _getFirstNumericField(item, ['tokens_emitidos', 'tokensEmitidos', 'tokens'], 0.0);
    if (capital > 0 && tokens > 0) {
      return capital / tokens; // Preço unitário = capital total ÷ total de tokens
    }
    return 0.0;
  }

  // Busca todas as startups do backend e extrai os setores únicos para os filtros.
  Future<void> _fetchStartups() async {
    final url = Uri.parse('http://localhost:3000/api/startups');
    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final startups = data ?? [];

        // Coleta todos os setores únicos usando um Set (sem duplicatas)
        final sectors = <String>{'Todos'};
        for (final item in startups) {
          final sector = _getFirstNonEmptyField(item, ['setor', 'area', 'segmento'], '');
          if (sector.isNotEmpty) sectors.add(sector);
        }

        setState(() {
          _allStartups = startups;
          _filteredStartups = startups; // Inicialmente exibe todas sem filtro
          _sectors = sectors.toList()..sort(); // Ordena alfabeticamente
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

  // Converte o valor bruto do estágio (sem acento) para o nome correto exibido.
  // O Firestore guarda 'ideacao', mas exibimos 'Ideação'.
  String _displayStage(String raw) {
    const map = {
      'ideacao': 'Ideação',
      'validacao': 'Validação',
      'operacao': 'Operação',
      'tracao': 'Tração',
    };
    return map[raw.toLowerCase().trim()] ?? raw;
  }

  // Remove acentos e converte para minúsculas para comparação de filtros.
  // Permite filtrar 'Ideação' mesmo que o dado venha como 'ideacao'.
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

  // Aplica os filtros de estágio e/ou setor à lista de startups.
  // Chamado sempre que o usuário seleciona um filtro diferente.
  void _filterStartups({String? stage, String? sector}) {
    // Atualiza os filtros selecionados se foram alterados
    if (stage != null) _selectedStage = stage;
    if (sector != null) _selectedSector = sector;

    setState(() {
      // .where() cria uma nova lista contendo apenas as startups que passam nos filtros
      _filteredStartups = _allStartups.where((startup) {
        // Normaliza o estágio e setor da startup para comparação sem acentos
        final startupStage = _normalizeText(
          _getFirstNonEmptyField(startup, ['estagio', 'fase', 'stage'], ''),
        );
        final startupSector = _normalizeText(
          _getFirstNonEmptyField(startup, ['setor', 'area', 'segmento'], ''),
        );

        // 'Todos' aceita qualquer valor; caso contrário, compara normalizado
        final stageMatch = _selectedStage == 'Todos' || startupStage == _normalizeText(_selectedStage);
        final sectorMatch = _selectedSector == 'Todos' || startupSector == _normalizeText(_selectedSector);

        // A startup aparece apenas se passar em AMBOS os filtros
        return stageMatch && sectorMatch;
      }).toList();
    });
  }

  // initState: executado uma vez quando a tela é criada.
  // Inicia o carregamento das startups imediatamente.
  @override
  void initState() {
    super.initState();
    _fetchStartups();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope: intercepta o botão "voltar" para retornar _userData atualizado à tela anterior.
    // Isso garante que saldo e tokens do usuário ficam sincronizados após compras.
    return PopScope(
      canPop: false, // Impede o pop automático — controlamos manualmente
      onPopInvokedWithResult: (didPop, result) {
        // Quando o usuário pressiona "voltar", retorna os dados atualizados do usuário
        if (!didPop) Navigator.pop(context, _userData);
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text(
            'Catálogo de Startups',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.indigo[900],
          iconTheme: const IconThemeData(color: Colors.white), // Botão voltar branco
          elevation: 0,
        ),
        body: Column(
          children: [
            // ===== BARRA DE FILTROS =====
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filtro por estágio de desenvolvimento
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Estágio', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    height: 44,
                    // ListView horizontal para os chips de filtro de estágio
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _stages.length,
                      itemBuilder: (context, index) {
                        final stage = _stages[index];
                        final isSelected = _selectedStage == stage;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          // ChoiceChip: chip de seleção única (como botão de rádio visual)
                          child: ChoiceChip(
                            label: Text(stage, style: const TextStyle(fontSize: 13)),
                            selected: isSelected,
                            selectedColor: Colors.indigo[900], // Cor quando selecionado
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) => _filterStartups(stage: stage), // Aplica filtro
                          ),
                        );
                      },
                    ),
                  ),

                  // Filtro por setor — só aparece se houver mais de um setor disponível
                  if (_sectors.length > 1) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text('Setor', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
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
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

            // ===== LISTA DE STARTUPS (ou estado de loading/erro) =====
            Expanded(
              child: _isLoading
                  // Estado: carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                      // Estado: erro ao carregar
                      ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 16)))
                      : _filteredStartups.isEmpty
                          // Estado: nenhuma startup corresponde aos filtros
                          ? Center(
                              child: Text(
                                'Nenhuma startup encontrada para: $_selectedStage / $_selectedSector',
                                style: const TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            )
                          // Estado: lista de cards de startups
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredStartups.length,
                              itemBuilder: (context, index) {
                                final startup = _filteredStartups[index];

                                // Busca o nome tentando vários campos possíveis
                                final startupName = _getFirstNonEmptyField(startup,
                                  ['nome', 'nome_startup', 'nomeStartup', 'startupNome', 'name', 'titulo', 'startup'],
                                  'Startup Sem Nome');

                                // Converte estágio para texto com acentuação e em maiúsculas
                                final stageDisplay = _displayStage(
                                  _getFirstNonEmptyField(startup, ['estagio', 'fase', 'stage'], ''),
                                ).toUpperCase();

                                final description = _getFirstNonEmptyField(startup,
                                  ['descricao', 'description', 'resumo', 'sobre'],
                                  'Sem descrição disponível.');

                                final tokenValue = _getTokenPrice(startup);

                                // Card clicável para cada startup
                                return Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: InkWell(
                                    onTap: () async {
                                      // Navega para a tela de detalhes passando dados da startup e do usuário
                                      final result = await Navigator.pushNamed(
                                        context,
                                        '/startup-detalhes',
                                        arguments: {'startup': startup, 'user': _userData},
                                      );
                                      // Se o usuário comprou tokens, atualiza os dados locais
                                      if (result is Map<String, dynamic> && result['user'] is Map<String, dynamic>) {
                                        _userData = Map<String, dynamic>.from(result['user']);
                                        setState(() {});
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Linha superior: nome + badge de estágio
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(startupName,
                                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo),
                                                  overflow: TextOverflow.ellipsis),
                                              ),
                                              const SizedBox(width: 8),
                                              // Badge do estágio (ex: IDEAÇÃO, VALIDAÇÃO)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: Colors.blue),
                                                ),
                                                child: Text(stageDisplay,
                                                  style: TextStyle(color: Colors.blue[800], fontSize: 12, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),

                                          // Descrição resumida (máximo 2 linhas)
                                          Text(description, maxLines: 2, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const SizedBox(height: 8),

                                          // Linha inferior: valor do token + seta de navegação
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('Valor do Token', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    tokenValue > 0
                                                        ? 'R\$ ${tokenValue.toStringAsFixed(2).replaceAll('.', ',')}'
                                                        : 'Não disponível',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  ),
                                                ],
                                              ),
                                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
