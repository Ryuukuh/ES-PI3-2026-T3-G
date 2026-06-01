// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: SessionService — gerenciamento de sessão local via shared_preferences
//
// Este serviço é responsável por manter o usuário logado entre sessões do app.
// "Sessão" significa: lembrar quem está logado mesmo após fechar o aplicativo.
//
// Como funciona?
//   1. Ao fazer login, os dados do usuário são salvos no armazenamento do celular.
//   2. Na próxima abertura do app, esses dados são lidos automaticamente.
//   3. Ao fazer logout, os dados são apagados — próxima abertura pede login novamente.
//
// 'shared_preferences' é uma biblioteca que salva dados simples no dispositivo,
// funcionando como um mini banco de dados chave-valor local (similar ao localStorage do navegador).

// Importa ferramentas para converter objetos Dart ↔ texto JSON
import 'dart:convert';

// Importa o pacote de armazenamento local persistente do Flutter
import 'package:shared_preferences/shared_preferences.dart';

// Classe com métodos estáticos para gerenciar a sessão do usuário.
// Métodos 'static' podem ser chamados diretamente: SessionService.saveUser(...)
// sem precisar criar um objeto da classe primeiro.
class SessionService {
  // Chave usada para identificar o dado salvo — funciona como o "nome da gaveta"
  static const _userKey = 'mesclainvest_user';

  // Salva os dados do usuário no armazenamento local do dispositivo.
  // Chamado logo após o login bem-sucedido.
  //
  // 'Map<String, dynamic>' é um dicionário chave:valor que pode guardar
  // qualquer tipo de dado — ex: {'nome': 'Ana', 'saldo': 1000.0, 'tokens': {}}
  //
  // 'Future<void>' indica que a operação é assíncrona (pode demorar um pouco)
  // e não retorna nenhum valor ao terminar.
  static Future<void> saveUser(Map<String, dynamic> user) async {
    // Obtém acesso ao armazenamento local do dispositivo
    final prefs = await SharedPreferences.getInstance();

    // jsonEncode transforma o mapa em uma string JSON para poder salvar como texto
    // Ex: {'nome':'Ana'} → '{"nome":"Ana"}'
    await prefs.setString(_userKey, jsonEncode(user));
  }

  // Carrega os dados do usuário salvo no dispositivo.
  // Retorna o mapa com os dados se existir sessão salva, ou null se não houver.
  //
  // O '?' no tipo de retorno indica que pode retornar null (nenhum usuário logado).
  static Future<Map<String, dynamic>?> loadUser() async {
    // Obtém acesso ao armazenamento local
    final prefs = await SharedPreferences.getInstance();

    // Tenta ler a string JSON salva — será null se nunca houve login ou após logout
    final raw = prefs.getString(_userKey);

    // Se não há dados salvos, retorna null (ninguém logado)
    if (raw == null || raw.isEmpty) return null;

    // Tenta converter a string JSON de volta para um mapa Dart
    // O try/catch protege contra dados corrompidos ou em formato inválido
    try {
      // jsonDecode converte a string JSON de volta para um objeto Dart
      final data = jsonDecode(raw);

      // Garante que o resultado é um mapa (não uma lista ou outro tipo)
      if (data is Map) {
        // Converte para o tipo exato exigido e retorna
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {
      // Se os dados estiverem corrompidos, descarta silenciosamente
      // O '_' ignora o erro — o app simplesmente pedirá login novamente
      // ignore invalid saved data
    }

    // Se chegou aqui, a leitura falhou — retorna null por segurança
    return null;
  }

  // Apaga os dados do usuário do armazenamento local.
  // Chamado quando o usuário faz logout — na próxima abertura do app,
  // loadUser() retornará null e o app redirecionará para a tela de login.
  static Future<void> clearUser() async {
    // Obtém acesso ao armazenamento local
    final prefs = await SharedPreferences.getInstance();

    // Remove a entrada associada à chave '_userKey', limpando a sessão
    await prefs.remove(_userKey);
  }
}
