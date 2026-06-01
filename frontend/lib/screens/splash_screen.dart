// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: SplashScreen — verificador de sessão persistente
//
// Esta tela é a PRIMEIRA exibida quando o app abre.
// Sua função é verificar se o usuário já estava logado anteriormente:
//   - Se SIM: busca dados atualizados no servidor e vai direto para a Home
//   - Se NÃO: redireciona para a tela de Login
//
// O usuário vê um indicador de carregamento enquanto a verificação ocorre.

// Importa ferramentas para decodificar JSON (texto → objeto Dart)
import 'dart:convert';

// Importa o kit de widgets visuais do Flutter
import 'package:flutter/material.dart';

// Importa o pacote HTTP para fazer requisições ao servidor backend
import 'package:http/http.dart' as http;

// Importa o serviço que gerencia a sessão salva no dispositivo
import '../services/session_service.dart';

// Importa as cores do tema do projeto
import '../theme/app_colors.dart';

// StatefulWidget porque a tela precisa executar código assíncrono (verificação de sessão)
// durante seu ciclo de vida
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // initState: executado automaticamente uma vez, logo após a tela ser criada.
  // É o lugar certo para iniciar operações de carregamento.
  @override
  void initState() {
    super.initState();
    // Inicia a verificação de sessão assim que a tela aparece
    _checkSession();
  }

  // Verifica se há uma sessão de usuário salva localmente e valida com o servidor.
  // Decide para qual tela navegar com base no resultado.
  Future<void> _checkSession() async {
    // Tenta carregar os dados do usuário salvos no dispositivo (após login anterior)
    final storedUser = await SessionService.loadUser();

    // Se não há dados salvos → usuário nunca logou ou fez logout
    if (storedUser == null) {
      _navigateToLogin();
      return;
    }

    // Extrai o UID (identificador único) do usuário salvo
    final uid = storedUser['uid']?.toString() ?? '';

    // Se o UID estiver vazio, os dados salvos são inválidos → limpa e vai para login
    if (uid.isEmpty) {
      await SessionService.clearUser();
      _navigateToLogin();
      return;
    }

    // Tenta buscar dados atualizados no servidor (saldo, tokens, etc. podem ter mudado)
    try {
      final url = Uri.parse('http://localhost:3000/api/usuario/$uid');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Decodifica a resposta JSON do servidor
        final body = jsonDecode(response.body);
        final usuario = body['usuario'] ?? {};

        // Mescla dados locais com dados do servidor (servidor tem prioridade)
        // '...' é o operador spread — copia todos os campos do mapa
        final updatedUser = {
          ...storedUser,                           // Dados locais (base)
          ...Map<String, dynamic>.from(usuario),   // Dados do servidor (sobrescreve se houver conflito)
        };

        // Salva os dados atualizados localmente para a próxima abertura
        await SessionService.saveUser(updatedUser);

        // Verifica se o widget ainda está na tela antes de navegar
        // (proteção contra erros se o usuário fechar o app durante o carregamento)
        if (!mounted) return;

        // Vai para a Home passando os dados atualizados como argumento
        Navigator.pushReplacementNamed(context, '/home', arguments: updatedUser);
        return;
      }
    } catch (_) {
      // Se o servidor estiver offline ou ocorrer erro de rede,
      // usa os dados salvos localmente como fallback (app funciona offline)
    }

    // Fallback: vai para a Home com os dados locais (servidor inacessível)
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home', arguments: storedUser);
  }

  // Navega para a tela de Login substituindo a SplashScreen na pilha de navegação.
  // 'pushReplacementNamed' impede que o usuário volte para a Splash pressionando "voltar".
  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Interface visual da SplashScreen: um spinner de carregamento centralizado
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            // Indicador circular de carregamento na cor primária do app
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            // Texto informativo abaixo do spinner
            Text('Carregando sessão...', style: TextStyle(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
