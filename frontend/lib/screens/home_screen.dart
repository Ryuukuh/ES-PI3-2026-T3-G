// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Tela de Dashboard Principal (Home) pós-login
//
// Esta é a tela principal do app após o login.
// Exibe: saldo do usuário, resumo da carteira, últimos aportes,
// startups em destaque e atalho para explorar o mercado.

// Importa o kit de widgets visuais do Flutter
import 'package:flutter/material.dart';

// Importa o pacote HTTP para buscar startups do backend
import 'package:http/http.dart' as http;

// Importa ferramentas para decodificar a resposta JSON do servidor
import 'dart:convert';

// Importa o serviço de sessão para salvar dados atualizados do usuário
import '../services/session_service.dart';

// StatefulWidget porque os dados do usuário e startups podem mudar durante o uso
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Dados do usuário logado — inicializado com valores padrão
  // que serão substituídos pelos dados reais ao carregar a tela
  Map<String, dynamic> _userData = {
    'uid': '',
    'nomeCompleto': 'Investidor',
    'email': 'E-mail não informado',
    'cpf': 'CPF não informado',
    'telefone': 'Telefone não informado',
    'saldoFicticio': 0.0,
    'tokens': {},
  };

  bool _initialized = false;       // Garante que a inicialização acontece apenas uma vez
  bool _isLoadingStartups = true;  // Controla o spinner enquanto carrega as startups
  String _startupError = '';       // Mensagem de erro caso o carregamento falhe
  List<dynamic> _featuredStartups = []; // Lista das 3 primeiras startups para destaque

  // didChangeDependencies: executado após o widget ter acesso ao contexto de navegação.
  // Usado para ler os argumentos passados pela tela anterior (dados do usuário logado).
  // A flag '_initialized' garante que este código rode apenas uma vez.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      // Lê os argumentos passados pela tela de Login (ou SplashScreen)
      final argumentos = ModalRoute.of(context)?.settings.arguments;
      if (argumentos is Map) {
        // Mescla os argumentos com os valores padrão — argumentos têm prioridade
        _userData = {
          ..._userData,
          ...Map<String, dynamic>.from(argumentos),
        };
      }
      _normalizeUserData(); // Garante tipos de dados corretos
      _fetchStartups();     // Busca startups do backend
      _initialized = true;  // Marca como inicializado para não repetir
    }
  }

  // Garante que os dados do usuário estão nos tipos corretos (double, Map, etc.).
  // Necessário porque dados vindos de JSON podem chegar como String.
  void _normalizeUserData() {
    final saldoRaw = _userData['saldoFicticio'];
    // Se o saldo veio como String (ex: "1000.0"), converte para double
    if (saldoRaw is String) {
      _userData['saldoFicticio'] = double.tryParse(saldoRaw.replaceAll(',', '.')) ?? 0.0;
    }
    // Garante que 'tokens' é sempre um Map (nunca null ou outro tipo)
    if (_userData['tokens'] is! Map) {
      _userData['tokens'] = {};
    }
  }

  // Salva os dados atuais do usuário no armazenamento local do dispositivo.
  // Chamado sempre que os dados mudam para manter a sessão sincronizada.
  void _saveSession() {
    SessionService.saveUser(_userData);
  }

  // Atualiza os dados do usuário na tela após retornar de outra tela
  // (ex: após comprar tokens na tela de detalhes da startup).
  void _updateUser(Map<String, dynamic> updatedUser) {
    if (updatedUser.isEmpty) return; // Ignora se não há dados para atualizar
    setState(() {
      _userData.addAll(updatedUser); // Substitui apenas os campos que mudaram
      _normalizeUserData();
    });
    _saveSession(); // Persiste as mudanças no dispositivo
  }

  // Busca dados atualizados do usuário diretamente no servidor.
  // Chamado pelo botão de atualizar na AppBar.
  Future<void> _fetchUserFromServer() async {
    final uid = _userData['uid']?.toString() ?? '';
    if (uid.isEmpty) return; // Sem UID não é possível buscar

    final url = Uri.parse('http://localhost:3000/api/usuario/$uid');
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final usuario = body['usuario'] ?? {};
        setState(() {
          // Mescla dados locais com os dados frescos do servidor
          _userData = {..._userData, ...Map<String, dynamic>.from(usuario)};
          _normalizeUserData();
        });
        _saveSession();
      }
    } catch (e) {
      // Falha silenciosa — mantém os dados que já estão na tela
    }
  }

  // Exibe um diálogo de confirmação antes de fazer logout.
  // Retorna true se o usuário confirmou, false se cancelou.
  Future<bool> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar logout'),
          content: const Text('Deseja realmente sair da conta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Retorna false (cancelou)
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Retorna true (confirmou)
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    // Se confirmou, apaga a sessão local
    if (result == true) {
      await SessionService.clearUser();
    }
    return result == true;
  }

  // Busca as startups disponíveis no backend para exibir na seção de destaques.
  // Usa apenas as 3 primeiras para não sobrecarregar a Home.
  Future<void> _fetchStartups() async {
    final url = Uri.parse('http://localhost:3000/api/startups');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final startups = data is List ? data : [];
        setState(() {
          // .take(3) pega apenas as 3 primeiras startups para o destaque
          _featuredStartups = List<dynamic>.from(startups.take(3));
          _isLoadingStartups = false;
          _startupError = '';
        });
      } else {
        setState(() {
          _startupError = 'Erro ao carregar startups (${response.statusCode})';
          _isLoadingStartups = false;
        });
      }
    } catch (e) {
      setState(() {
        _startupError = 'Não foi possível carregar o catálogo de startups.';
        _isLoadingStartups = false;
      });
    }
  }

  // Calcula o valor total investido somando o valor de todos os tokens na carteira.
  double _calcTotalInvested() {
    double total = 0.0;
    final tokens = _userData['tokens'];
    if (tokens is Map) {
      for (final tokenData in tokens.values) {
        if (tokenData is Map) {
          // Soma o campo 'valor' de cada investimento (valor em R$ investido naquela startup)
          total += double.tryParse(tokenData['valor']?.toString() ?? '0.0') ?? 0.0;
        }
      }
    }
    return total;
  }

  // Retorna os 3 aportes mais recentes do histórico de transações.
  // Usado para exibir o resumo de "Últimos aportes" na Home.
  List<Map<String, dynamic>> _getRecentAportes() {
    final recent = <Map<String, dynamic>>[];
    final historico = _userData['historicoAportes'];
    if (historico is List) {
      // .reversed percorre a lista de trás para frente (mais recente primeiro)
      for (final entry in historico.reversed) {
        if (entry is Map) {
          recent.add({
            'startupNome': entry['startupNome']?.toString() ?? 'Startup',
            'amount': double.tryParse(entry['amount']?.toString() ?? '0.0') ?? 0.0,
            'createdAt': entry['createdAt']?.toString() ?? '',
          });
        }
        if (recent.length >= 3) break; // Limita a 3 itens
      }
    }
    return recent;
  }

  // Formata um número double como moeda brasileira: R$ 1.234,56
  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // Converte o valor bruto do estágio (sem acento) para o nome correto com acentuação.
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

  @override
  Widget build(BuildContext context) {
    // Extrai e converte dados do usuário para uso na interface
    final nomeUsuario = _userData['nomeCompleto']?.toString() ?? 'Investidor';
    final saldoFicticio = _userData['saldoFicticio'] is double
        ? _userData['saldoFicticio'] as double
        : double.tryParse(_userData['saldoFicticio']?.toString() ?? '0.0') ?? 0.0;

    final totalInvested = _calcTotalInvested();
    // Saldo disponível = saldo total − valor investido (mínimo 0)
    final availableBalance = (saldoFicticio - totalInvested).clamp(0.0, double.infinity);
    // Percentual alocado em investimentos (entre 0.0 e 1.0)
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
          // Botão para atualizar dados do servidor manualmente
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Atualizar dados',
            onPressed: () async { await _fetchUserFromServer(); },
          ),
          // Botão para acessar a tela de perfil
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            tooltip: 'Perfil',
            onPressed: () async {
              final result = await Navigator.pushNamed(
                context, '/perfil', arguments: _userData,
              );
              // Se o perfil retornar dados atualizados, aplica na Home
              if (result is Map<String, dynamic>) { _updateUser(result); }
            },
          ),
          // Botão de logout com confirmação
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            tooltip: 'Sair da Conta',
            onPressed: () async {
              final confirmed = await _confirmLogout();
              if (!context.mounted) return;
              if (confirmed) {
                // Remove toda a pilha de navegação e abre o Login
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
            // ===== CABEÇALHO: saudação e saldo =====
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
                  // Saudação personalizada com o nome do usuário
                  Text(
                    'Olá, $nomeUsuario 👋',
                    style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text('Seu Saldo Disponível', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 4),
                  // Saldo total em destaque
                  Text(
                    'R\$ ${saldoFicticio.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ===== CARD: MINHA CARTEIRA =====
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
                      // Título da seção
                      Row(
                        children: [
                          Icon(Icons.pie_chart, color: Colors.indigo[900]),
                          const SizedBox(width: 10),
                          const Text('Minha Carteira', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Texto descritivo — muda conforme se tem investimentos ou não
                      Text(
                        totalInvested > 0
                            ? 'Você possui R\$ ${totalInvested.toStringAsFixed(2).replaceAll('.', ',')} investidos em startups.'
                            : 'Você ainda não possui tokens de startups contratados.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 12),

                      // Barra de progresso visual mostrando % alocado
                      LinearProgressIndicator(
                        value: allocation.clamp(0.0, 1.0), // Garante valor entre 0 e 1
                        backgroundColor: Colors.grey[200],
                      ),
                      const SizedBox(height: 16),

                      // Linha com saldo livre e percentual alocado
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Saldo livre', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(_formatCurrency(availableBalance), style: const TextStyle(fontWeight: FontWeight.bold)),
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

                      // Seção de últimos aportes
                      const Text('Últimos aportes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      // Lista dos 3 aportes mais recentes
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
                                    Text(ap['startupNome'] ?? 'Startup', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(ap['createdAt']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Text(_formatCurrency(ap['amount'] as double), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }),

                      // Mensagem quando não há aportes ainda
                      if (_getRecentAportes().isEmpty) ...[
                        const Text(
                          'Nenhum aporte registrado ainda. Invista em uma startup para ver o histórico aqui.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Botão para ir à tela de carteira completa
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final result = await Navigator.pushNamed(context, '/carteira', arguments: _userData);
                            if (result is Map<String, dynamic>) { _updateUser(result); }
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

            // ===== SEÇÃO: STARTUPS EM DESTAQUE =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Startups em Destaque', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // Estados possíveis: carregando, erro, vazio, ou lista de cards
                  if (_isLoadingStartups)
                    const Center(child: CircularProgressIndicator())
                  else if (_startupError.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Text(_startupError, style: const TextStyle(color: Colors.red)),
                    )
                  else if (_featuredStartups.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: const Text('Nenhuma startup encontrada no catálogo no momento.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    // Lista horizontal de cards de startups
                    SizedBox(
                      height: 230,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _featuredStartups.length,
                        itemBuilder: (context, index) {
                          final startup = _featuredStartups[index];

                          // Tenta vários nomes de campo possíveis para o nome da startup
                          final startupName = startup['nome_startup']?.toString() ??
                              startup['nome']?.toString() ??
                              startup['title']?.toString() ??
                              startup['startupNome']?.toString() ?? 'Startup';

                          // Converte o estágio para nome com acentuação
                          final stage = _displayStage(
                            startup['estagio']?.toString() ??
                            startup['fase']?.toString() ??
                            startup['stage']?.toString() ?? '',
                          );

                          final description = startup['descricao']?.toString() ??
                              startup['description']?.toString() ??
                              startup['resumo']?.toString() ?? 'Descrição não disponível.';

                          // Tenta vários campos para o preço do token
                          final tokenPrice = double.tryParse(
                            startup['precoToken']?.toString() ??
                            startup['valorToken']?.toString() ??
                            startup['preco']?.toString() ??
                            startup['valor']?.toString() ?? '0') ?? 0.0;

                          // Card clicável de startup em destaque
                          return GestureDetector(
                            onTap: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/startup-detalhes',
                                arguments: {'startup': startup, 'user': _userData},
                              );
                              // Atualiza dados do usuário se a tela de detalhes retornar dados novos
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
                                  BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.08), blurRadius: 10, offset: Offset(0, 6)),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(startupName, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 10),
                                    Text(stage, style: const TextStyle(color: Colors.indigo)),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Text(description, maxLines: 4, overflow: TextOverflow.ellipsis,
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

                  // Botão para ver todas as startups no catálogo
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(context, '/catalogo', arguments: _userData);
                        if (result is Map<String, dynamic>) { _updateUser(result); }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.indigo),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Ver todas as startups', style: TextStyle(color: Colors.indigo)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ===== SEÇÃO: ATALHO "EXPLORAR MERCADO" =====
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('O que deseja fazer hoje?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  // Card grande com gradiente — atalho para o catálogo completo
                  InkWell(
                    onTap: () async {
                      final result = await Navigator.pushNamed(context, '/catalogo', arguments: _userData);
                      if (result is Map<String, dynamic>) { _updateUser(result); }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        // Gradiente de azul escuro para azul médio
                        gradient: LinearGradient(
                          colors: [Colors.indigo[800]!, Colors.blue[700]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: const Color.fromRGBO(33, 150, 243, 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Ícone com fundo semi-transparente
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withAlpha(51), shape: BoxShape.circle),
                            child: const Icon(Icons.business_center, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Explorar Mercado', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Conheça as 8 startups e invista em tokens oficiais.', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
