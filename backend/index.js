/**
 * PROJETO INTEGRADOR 3 - MESCLAINVEST
 * Autor Principal: Rafael Elias Correa | RA: 18726497
 * Componente: Backend - API REST completa
 *
 * Este arquivo é o servidor do MesclaInvest.
 * Ele funciona como o "cérebro" do sistema: recebe pedidos do aplicativo (frontend),
 * processa a lógica de negócio e conversa com o banco de dados Firebase.
 *
 * Uma API REST é um conjunto de "endereços" (rotas) que o app pode chamar
 * para realizar ações como cadastrar usuário, fazer login, comprar tokens, etc.
 */

// Carrega as variáveis de ambiente do arquivo .env (senhas, chaves de API)
// Isso mantém informações sensíveis fora do código-fonte
require('dotenv').config();

// Express: framework que facilita criar um servidor web em Node.js
const express = require('express');

// CORS: permite que o app Flutter (em outra porta/endereço) acesse este servidor
const cors = require('cors');

// bcrypt: biblioteca para criar e verificar hashes de senha (criptografia segura)
const bcrypt = require('bcrypt');

// Nodemailer: biblioteca para enviar e-mails (usada no MFA e recuperação de senha)
const nodemailer = require('nodemailer');

// Firebase SDK: ferramentas para conectar e operar no banco de dados Firestore
const { initializeApp } = require("firebase/app");
const {
  getFirestore,   // Obtém a referência ao banco de dados
  collection,     // Referencia uma coleção (tabela) no Firestore
  doc,            // Referencia um documento específico pelo ID
  setDoc,         // Cria ou sobrescreve um documento
  query,          // Cria uma consulta com filtros
  where,          // Filtro de consulta (ex: where("email", "==", "..."))
  getDocs,        // Executa uma consulta e retorna múltiplos documentos
  getDoc,         // Busca um documento específico pelo ID
  addDoc,         // Adiciona um novo documento com ID gerado automaticamente
  orderBy,        // Ordena resultados de uma consulta
} = require("firebase/firestore");

// Cria a instância do servidor Express
const app = express();

// Habilita CORS — sem isso, o app Flutter seria bloqueado ao tentar acessar o servidor
app.use(cors());

// Permite que o servidor entenda JSON no corpo das requisições
// (Ex: quando o app envia '{"email":"...", "senha":"..."}')
app.use(express.json());

// Middleware de log: registra no terminal cada requisição recebida
// Ajuda a monitorar o que está acontecendo durante o desenvolvimento
app.use((req, res, next) => {
  // Exibe o método HTTP (GET, POST, etc.), a data/hora e a rota acessada
  console.log(`📥 [${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
  // Para requisições que enviam dados (não GET), exibe o corpo da requisição
  if (req.method !== 'GET') {
    console.log('     Payload:', JSON.stringify(req.body));
  }
  // Chama o próximo middleware ou rota (sem isso, a requisição ficaria parada aqui)
  next();
});

// Configurações de conexão com o Firebase (identificadores do projeto)
// Esses valores são públicos — as regras de segurança ficam no painel do Firebase
const config = {
  apiKey: "AIzaSyA07tMa8LxgGPk4ah83yg4vF7aKUmAlmqU",
  authDomain: "mesclainvest-pi3.firebaseapp.com",
  projectId: "mesclainvest-pi3",
  storageBucket: "mesclainvest-pi3.firebasestorage.app",
  messagingSenderId: "234622831135",
  appId: "1:234622831135:web:74900b7b473ff9be1d632a",
  measurementId: "G-H87XRZ5H9R"
};

// Inicializa o Firebase com as configurações acima
const firebaseApp = initializeApp(config);

// Obtém a referência ao banco de dados Firestore (onde tudo é salvo)
const db = getFirestore(firebaseApp);

// Configura o serviço de envio de e-mail usando o Gmail
// As credenciais (usuário e senha) vêm do arquivo .env por segurança
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER, // E-mail do remetente (vem do .env)
    pass: process.env.GMAIL_PASS, // Senha de app do Gmail (vem do .env)
  },
});

/**
 * Gera um código numérico aleatório de 6 dígitos.
 * Usado no MFA (autenticação em dois fatores) e na recuperação de senha.
 * Ex: 482910, 173654
 */
function gerarCodigo6Digitos() {
  // Math.random() gera um número entre 0 e 1
  // Multiplicar por 900000 e somar 100000 garante que o número fique entre 100000 e 999999
  // .toString() converte para texto (string)
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * Envia um e-mail para o destinatário informado.
 * Se o servidor de e-mail não estiver configurado (ambiente de desenvolvimento),
 * apenas simula o envio imprimindo no terminal.
 *
 * @param {string} destinatario - Endereço de e-mail de quem vai receber
 * @param {string} assunto      - Assunto do e-mail
 * @param {string} corpo        - Texto do e-mail
 */
async function enviarEmail(destinatario, assunto, corpo) {
  // Se o e-mail do Gmail não estiver configurado no .env, apenas simula o envio
  if (!process.env.GMAIL_USER || process.env.GMAIL_USER === 'seu_email@gmail.com') {
    console.log(`📧 [SIMULADO] Para: ${destinatario} | Assunto: ${assunto} | ${corpo}`);
    return;
  }
  // Envia o e-mail de verdade usando o transporter configurado acima
  await transporter.sendMail({
    from: `"MesclaInvest" <${process.env.GMAIL_USER}>`, // Nome e e-mail do remetente
    to: destinatario,
    subject: assunto,
    text: corpo,
  });
}

// ============================================================
// ROTAS DE AUTENTICAÇÃO
// ============================================================

/**
 * ROTA POST: /api/cadastro
 * Cria uma nova conta de usuário no sistema.
 *
 * Recebe: { nomeCompleto, email, cpf, telefone, senha }
 * Retorna: { message, uid } em caso de sucesso
 *          { error } em caso de falha
 *
 * Passos: valida campos → verifica e-mail duplicado → criptografa senha → salva no Firestore
 */
app.post('/api/cadastro', async (req, res) => {
  // Extrai os campos enviados pelo app no corpo da requisição
  const { nomeCompleto, email, cpf, telefone, senha } = req.body;

  // Verifica se todos os campos obrigatórios foram enviados
  if (!nomeCompleto || !email || !cpf || !telefone || !senha) {
    return res.status(400).json({ error: "Campos obrigatórios ausentes. Informe nomeCompleto, email, cpf, telefone e senha." });
  }

  try {
    // Busca no banco se já existe um usuário com o mesmo e-mail
    const usuariosRef = collection(db, "users");
    const q = query(usuariosRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    // Se encontrou algum usuário com esse e-mail, bloqueia o cadastro
    if (!querySnapshot.empty) {
      return res.status(400).json({ error: "Este e-mail já está cadastrado no sistema." });
    }

    // Criptografa a senha antes de salvar (NUNCA salvamos senha em texto puro)
    // saltRounds = 10: define o "custo" da criptografia (quanto maior, mais seguro e mais lento)
    const saltRounds = 10;
    const senhaCriptografada = await bcrypt.hash(senha, saltRounds);

    // Monta o objeto com todos os dados do novo usuário
    const dadosUsuario = {
      nomeCompleto,
      email,
      cpf,
      telefone,
      senha: senhaCriptografada,           // Senha criptografada (nunca a original)
      dataCadastro: new Date().toLocaleString("pt-BR"),
      saldoFicticio: 10000.00,             // Saldo inicial de R$10.000 para simular investimentos
      tokens: {},                          // Carteira de tokens começa vazia
      historicoAportes: [],                // Histórico de transações começa vazio
      mfaEnabled: false,                   // MFA desabilitado por padrão
    };

    // Usa o CPF (apenas números) como ID único do documento no Firestore
    const customUid = cpf.replace(/\D/g, ""); // Remove tudo que não é dígito do CPF
    await setDoc(doc(db, "users", customUid), dadosUsuario);

    // Retorna sucesso (HTTP 201 = Created)
    return res.status(201).json({ message: "Usuário cadastrado com sucesso!", uid: customUid });
  } catch (error) {
    // Em caso de erro inesperado, retorna HTTP 500 (Internal Server Error)
    return res.status(500).json({ error: error.message });
  }
});

/**
 * ROTA POST: /api/login
 * Autentica um usuário com e-mail e senha.
 * Se o MFA estiver habilitado, envia um código por e-mail e retorna mfaRequired: true.
 *
 * Recebe: { email, senha }
 * Retorna (sem MFA): { message, uid, usuario }
 * Retorna (com MFA): { mfaRequired: true, uid }
 */
app.post('/api/login', async (req, res) => {
  const { email, senha } = req.body;

  // Valida se os campos obrigatórios foram enviados
  if (!email || !senha) {
    return res.status(400).json({ error: "Campos obrigatórios ausentes. Informe email e senha." });
  }

  try {
    // Busca o usuário pelo e-mail no banco de dados
    const usuariosRef = collection(db, "users");
    const q = query(usuariosRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    // Se não encontrou nenhum usuário com esse e-mail, retorna erro genérico
    // (não informamos se é o e-mail ou a senha que está errado — por segurança)
    if (querySnapshot.empty) {
      return res.status(401).json({ error: "E-mail ou senha incorretos." });
    }

    // Pega o primeiro (e único) documento encontrado
    const usuarioDoc = querySnapshot.docs[0];
    const dadosUsuario = usuarioDoc.data();
    const uid = usuarioDoc.id; // ID do documento = CPF do usuário

    // Compara a senha enviada com o hash salvo no banco
    // bcrypt.compare retorna true se a senha coincidir com o hash
    const senhaValida = await bcrypt.compare(senha, dadosUsuario.senha);
    if (!senhaValida) {
      return res.status(401).json({ error: "E-mail ou senha incorretos." });
    }

    // Se o usuário habilitou o MFA (autenticação em dois fatores)
    if (dadosUsuario.mfaEnabled) {
      // Gera um código de 6 dígitos e define que ele expira em 5 minutos
      const codigo = gerarCodigo6Digitos();
      const expiresAt = Date.now() + 5 * 60 * 1000; // Date.now() = milissegundos atuais

      // Salva o código e a data de expiração no documento do usuário
      await setDoc(doc(db, "users", uid), { mfaCode: codigo, mfaCodeExpires: expiresAt }, { merge: true });

      // Envia o código por e-mail para o usuário
      await enviarEmail(
        email,
        'MesclaInvest — Código de verificação',
        `Seu código de verificação é: ${codigo}\n\nEle expira em 5 minutos. Não compartilhe com ninguém.`
      );

      console.log(`🔐 [MFA] Código gerado para ${email}: ${codigo}`);

      // Retorna indicando que o MFA é necessário — o app vai mostrar a tela de código
      return res.status(200).json({ mfaRequired: true, uid });
    }

    // Login normal (sem MFA): retorna todos os dados do usuário para o app
    console.log(`✅ [LOGIN SUCESSO] Usuário ${dadosUsuario.nomeCompleto} logado.`);

    return res.status(200).json({
      message: "Login efetuado com sucesso!",
      uid,
      usuario: {
        nomeCompleto: dadosUsuario.nomeCompleto,
        email: dadosUsuario.email,
        cpf: dadosUsuario.cpf,
        telefone: dadosUsuario.telefone,
        saldoFicticio: dadosUsuario.saldoFicticio,
        tokens: dadosUsuario.tokens || {},
        historicoAportes: dadosUsuario.historicoAportes || [],
        mfaEnabled: dadosUsuario.mfaEnabled || false,
      }
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * ROTA POST: /api/mfa/verificar-login
 * Segunda etapa do login com MFA: valida o código enviado por e-mail.
 *
 * Recebe: { uid, codigo }
 * Retorna: { message, uid, usuario } em caso de sucesso
 */
app.post('/api/mfa/verificar-login', async (req, res) => {
  const { uid, codigo } = req.body;

  if (!uid || !codigo) {
    return res.status(400).json({ error: "uid e codigo são obrigatórios." });
  }

  try {
    // Busca o documento do usuário pelo ID
    const usuarioDocRef = doc(db, 'users', uid);
    const snapshot = await getDoc(usuarioDocRef);

    if (!snapshot.exists()) {
      return res.status(404).json({ error: "Usuário não encontrado." });
    }

    const data = snapshot.data();

    // Verifica se o código enviado pelo usuário bate com o código salvo no banco
    if (!data.mfaCode || data.mfaCode !== codigo) {
      return res.status(401).json({ error: "Código de verificação inválido." });
    }

    // Verifica se o código ainda está dentro do prazo de validade (5 minutos)
    if (Date.now() > (data.mfaCodeExpires || 0)) {
      return res.status(401).json({ error: "Código de verificação expirado. Faça login novamente." });
    }

    // Apaga o código do banco após uso bem-sucedido (evita reutilização)
    await setDoc(usuarioDocRef, { mfaCode: null, mfaCodeExpires: null }, { merge: true });

    console.log(`✅ [MFA OK] Usuário ${uid} autenticado com sucesso via MFA.`);

    // Retorna os dados completos do usuário — login concluído
    return res.status(200).json({
      message: "MFA verificado com sucesso!",
      uid,
      usuario: {
        nomeCompleto: data.nomeCompleto,
        email: data.email,
        cpf: data.cpf,
        telefone: data.telefone,
        saldoFicticio: data.saldoFicticio,
        tokens: data.tokens || {},
        historicoAportes: data.historicoAportes || [],
        mfaEnabled: data.mfaEnabled || false,
      }
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * ROTA PATCH: /api/mfa/toggle
 * Liga ou desliga o MFA (autenticação em dois fatores) do usuário.
 *
 * Recebe: { uid, habilitar } — habilitar é true para ligar, false para desligar
 * Retorna: { message, mfaEnabled }
 */
app.patch('/api/mfa/toggle', async (req, res) => {
  const { uid, habilitar } = req.body;

  // Garante que 'habilitar' é exatamente um booleano (true ou false)
  if (!uid || typeof habilitar !== 'boolean') {
    return res.status(400).json({ error: "uid e habilitar (boolean) são obrigatórios." });
  }

  try {
    const usuarioDocRef = doc(db, 'users', uid);
    const snapshot = await getDoc(usuarioDocRef);

    if (!snapshot.exists()) {
      return res.status(404).json({ error: "Usuário não encontrado." });
    }

    // Atualiza apenas o campo mfaEnabled no documento do usuário
    // { merge: true } garante que os outros campos não sejam apagados
    await setDoc(usuarioDocRef, { mfaEnabled: habilitar }, { merge: true });

    return res.status(200).json({
      message: `MFA ${habilitar ? 'habilitado' : 'desabilitado'} com sucesso.`,
      mfaEnabled: habilitar,
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * ROTA POST: /api/esqueci-senha
 * Inicia o processo de recuperação de senha.
 * Gera um código de 6 dígitos e envia por e-mail.
 *
 * Recebe: { email }
 * Retorna: sempre HTTP 200 (por segurança, não revela se o e-mail existe ou não)
 */
app.post('/api/esqueci-senha', async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: "E-mail é obrigatório." });
  }

  try {
    // Busca o usuário pelo e-mail
    const usuariosRef = collection(db, "users");
    const q = query(usuariosRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    // Retorna a mesma mensagem mesmo que o e-mail não exista
    // (evita que alguém descubra quais e-mails estão cadastrados por tentativa e erro)
    if (querySnapshot.empty) {
      return res.status(200).json({ message: "Se este e-mail estiver cadastrado, você receberá as instruções em breve." });
    }

    const usuarioDoc = querySnapshot.docs[0];
    const uid = usuarioDoc.id;

    // Gera o código e define validade de 15 minutos
    const codigo = gerarCodigo6Digitos();
    const expiresAt = Date.now() + 15 * 60 * 1000;

    // Salva o código de reset no banco vinculado ao usuário
    await setDoc(doc(db, "users", uid), {
      resetCode: codigo,
      resetCodeExpires: expiresAt,
    }, { merge: true });

    // Envia o código por e-mail
    await enviarEmail(
      email,
      'MesclaInvest — Redefinição de senha',
      `Você solicitou a redefinição de senha.\n\nSeu código de verificação é: ${codigo}\n\nEle expira em 15 minutos. Se não foi você, ignore este e-mail.`
    );

    console.log(`🔑 [RESET] Código gerado para ${email}: ${codigo}`);

    return res.status(200).json({ message: "Se este e-mail estiver cadastrado, você receberá as instruções em breve." });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * ROTA POST: /api/resetar-senha
 * Conclui a recuperação de senha: valida o código e salva a nova senha.
 *
 * Recebe: { email, codigo, novaSenha }
 * Retorna: { message } em caso de sucesso
 */
app.post('/api/resetar-senha', async (req, res) => {
  const { email, codigo, novaSenha } = req.body;

  if (!email || !codigo || !novaSenha) {
    return res.status(400).json({ error: "email, codigo e novaSenha são obrigatórios." });
  }

  // Garante que a nova senha tem pelo menos 6 caracteres
  if (novaSenha.length < 6) {
    return res.status(400).json({ error: "A nova senha deve ter pelo menos 6 caracteres." });
  }

  try {
    // Busca o usuário pelo e-mail
    const usuariosRef = collection(db, "users");
    const q = query(usuariosRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    if (querySnapshot.empty) {
      return res.status(400).json({ error: "Código inválido ou expirado." });
    }

    const usuarioDoc = querySnapshot.docs[0];
    const uid = usuarioDoc.id;
    const data = usuarioDoc.data();

    // Verifica se o código enviado bate com o salvo no banco
    if (!data.resetCode || data.resetCode !== codigo) {
      return res.status(400).json({ error: "Código inválido ou expirado." });
    }

    // Verifica se o código ainda está dentro do prazo de 15 minutos
    if (Date.now() > (data.resetCodeExpires || 0)) {
      return res.status(400).json({ error: "Código expirado. Solicite um novo." });
    }

    // Criptografa a nova senha antes de salvar
    const senhaCriptografada = await bcrypt.hash(novaSenha, 10);

    // Atualiza a senha e apaga o código de reset (não pode ser reutilizado)
    await setDoc(doc(db, "users", uid), {
      senha: senhaCriptografada,
      resetCode: null,
      resetCodeExpires: null,
    }, { merge: true });

    console.log(`✅ [RESET SENHA] Senha atualizada para ${email}`);

    return res.status(200).json({ message: "Senha redefinida com sucesso! Faça login com sua nova senha." });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// ============================================================
// ROTAS DE PERFIL DO USUÁRIO
// ============================================================

/**
 * ROTA GET: /api/usuario/:uid
 * Busca os dados atualizados de um usuário pelo seu ID (UID = CPF).
 * Usada na abertura do app para sincronizar os dados locais com o servidor.
 *
 * Parâmetro de URL: :uid — o ID do usuário
 * Retorna: { uid, usuario } — dados do usuário SEM campos sensíveis
 */
app.get('/api/usuario/:uid', async (req, res) => {
  const { uid } = req.params; // Extrai o uid da URL (ex: /api/usuario/12345678901)
  if (!uid) return res.status(400).json({ error: 'UID do usuário é obrigatório.' });

  try {
    // Busca o documento do usuário no Firestore
    const usuarioDocRef = doc(db, 'users', uid);
    const usuarioSnapshot = await getDoc(usuarioDocRef);
    if (!usuarioSnapshot.exists()) return res.status(404).json({ error: 'Usuário não encontrado.' });

    const data = usuarioSnapshot.data();

    // Remove campos sensíveis antes de enviar para o app
    // O app nunca deve receber a senha, mesmo que criptografada
    if (data) {
      delete data.senha;
      delete data.resetCode;
      delete data.resetCodeExpires;
      delete data.mfaCode;
      delete data.mfaCodeExpires;
    }

    return res.status(200).json({ uid: usuarioSnapshot.id, usuario: data });
  } catch (error) {
    return res.status(500).json({ error: 'Erro interno ao consultar usuário.' });
  }
});

/**
 * ROTA PATCH: /api/usuario/:uid
 * Atualiza os dados de perfil de um usuário (nome, e-mail, CPF ou telefone).
 * Verifica se o novo e-mail ou CPF já pertence a outro usuário antes de salvar.
 *
 * Parâmetro de URL: :uid
 * Recebe: { nomeCompleto?, email?, cpf?, telefone? } — ao menos um campo
 * Retorna: { uid, usuario } com os dados atualizados
 */
app.patch('/api/usuario/:uid', async (req, res) => {
  const { uid } = req.params;
  if (!uid) return res.status(400).json({ error: 'UID do usuário é obrigatório.' });

  const { nomeCompleto, email, cpf, telefone } = req.body;

  // Exige pelo menos um campo para atualizar
  if (!nomeCompleto && !email && !cpf && !telefone) {
    return res.status(400).json({ error: 'Informe ao menos um campo para atualizar.' });
  }

  try {
    const usuarioDocRef = doc(db, 'users', uid);
    const usuarioSnapshot = await getDoc(usuarioDocRef);
    if (!usuarioSnapshot.exists()) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    // Monta o objeto de atualização apenas com os campos enviados
    const updates = {};
    if (nomeCompleto) updates.nomeCompleto = nomeCompleto;
    if (email) updates.email = email;
    if (cpf) updates.cpf = cpf;
    if (telefone) updates.telefone = telefone;

    // Se está tentando mudar e-mail ou CPF, verifica se já existe outro usuário com esses dados
    if (email || cpf) {
      const usuariosRef = collection(db, 'users');
      const querySnapshot = await getDocs(query(usuariosRef, where(email ? 'email' : 'cpf', '==', email || cpf)));
      if (!querySnapshot.empty) {
        // Verifica se o conflito é com OUTRO usuário (não o próprio)
        const conflictingUser = querySnapshot.docs.find(d => d.id !== uid);
        if (conflictingUser) {
          return res.status(400).json({ error: 'O e-mail ou CPF informado já está em uso por outro usuário.' });
        }
      }
    }

    // Aplica as atualizações no Firestore (merge: true preserva os campos não alterados)
    await setDoc(usuarioDocRef, updates, { merge: true });

    // Busca os dados atualizados para retornar ao app
    const updatedSnapshot = await getDoc(usuarioDocRef);
    const updatedData = updatedSnapshot.data();

    // Remove novamente campos sensíveis antes de enviar
    if (updatedData) {
      delete updatedData.senha;
      delete updatedData.resetCode;
      delete updatedData.resetCodeExpires;
      delete updatedData.mfaCode;
      delete updatedData.mfaCodeExpires;
    }

    return res.status(200).json({ uid, usuario: updatedData });
  } catch (error) {
    return res.status(500).json({ error: 'Erro interno ao atualizar usuário.' });
  }
});

// ============================================================
// ROTAS DE STARTUPS E INVESTIMENTOS
// ============================================================

/**
 * ROTA GET: /api/startups
 * Retorna a lista completa de startups cadastradas no catálogo.
 * Usada na tela de catálogo e na home para exibir os cards de startups.
 *
 * Não recebe parâmetros.
 * Retorna: array com todos os documentos da coleção 'startups'
 */
app.get('/api/startups', async (req, res) => {
  try {
    // Busca todos os documentos da coleção 'startups' no Firestore
    const startupsRef = collection(db, "startups");
    const querySnapshot = await getDocs(startupsRef);

    // Transforma os documentos em um array de objetos, incluindo o ID de cada um
    const listaStartups = querySnapshot.docs.map(d => ({
      id: d.id,       // ID do documento no Firestore (ex: "eduthere")
      ...d.data()     // Todos os outros campos do documento (nome, descrição, etc.)
    }));

    return res.status(200).json(listaStartups);
  } catch (error) {
    return res.status(500).json({ error: "Erro interno ao consultar catálogo." });
  }
});

/**
 * ROTA POST: /api/aporte
 * Registra a compra de tokens de uma startup pelo usuário.
 * Debita o valor do saldo fictício e adiciona os tokens à carteira.
 *
 * Recebe: { uid, startupId, startupNome, amount, tokenPrice, tokensQuantity }
 * Retorna: { message, saldoFicticio, tokens, historicoAportes }
 */
app.post('/api/aporte', async (req, res) => {
  const { uid, startupId, startupNome, amount, tokenPrice, tokensQuantity } = req.body;

  // Todos os campos são obrigatórios para registrar a operação
  if (!uid || !startupId || !startupNome || !amount || !tokenPrice || !tokensQuantity) {
    return res.status(400).json({ error: "Dados insuficientes para registrar o aporte." });
  }

  try {
    // Busca o usuário no banco para verificar saldo e carteira atual
    const usuarioDocRef = doc(db, 'users', uid);
    const usuarioSnapshot = await getDoc(usuarioDocRef);

    if (!usuarioSnapshot.exists()) {
      return res.status(404).json({ error: "Usuário não encontrado." });
    }

    const usuarioData = usuarioSnapshot.data();
    const saldoAtual = Number(usuarioData.saldoFicticio || 0);
    const valorAporte = Number(amount);
    const quantidadeTokens = Number(tokensQuantity);

    // Impede aporte se o usuário não tem saldo suficiente
    if (valorAporte > saldoAtual) {
      return res.status(400).json({ error: "Saldo insuficiente para este aporte." });
    }

    // Pega a carteira atual de tokens do usuário
    const tokensAtuais = usuarioData.tokens || {};
    const tokenKey = startupId.toString(); // Chave no objeto de tokens (ex: "eduthere")

    // Se o usuário já tem tokens dessa startup, acumula com o que já existe
    const investimentoExistente = tokensAtuais[tokenKey] || {};

    // Monta o novo estado do investimento nessa startup
    const novoInvestimento = {
      startupNome,
      valor: Number(investimentoExistente.valor || 0) + valorAporte,         // Valor total investido
      tokens: Number(investimentoExistente.tokens || 0) + quantidadeTokens,  // Total de tokens
      tokenPrice,                                                              // Preço unitário atual
      updatedAt: new Date().toLocaleString('pt-BR'),
    };

    // Calcula o novo saldo após o débito
    const novoSaldo = saldoAtual - valorAporte;

    // Monta o registro para o histórico de transações
    const novoAporte = {
      uid, startupId, startupNome,
      amount: valorAporte, tokenPrice,
      tokensQuantity: quantidadeTokens,
      tipo: 'aporte',
      createdAt: new Date().toLocaleString('pt-BR'),
    };

    // Atualiza o histórico e a carteira com os novos dados
    const historicoAtualizado = [...(usuarioData.historicoAportes || []), novoAporte];
    const tokensAtualizados = { ...tokensAtuais, [tokenKey]: novoInvestimento };

    // Salva tudo no Firestore de uma vez
    await setDoc(usuarioDocRef, {
      saldoFicticio: novoSaldo,
      tokens: tokensAtualizados,
      historicoAportes: historicoAtualizado,
    }, { merge: true });

    // Retorna os dados atualizados para o app atualizar a tela imediatamente
    return res.status(200).json({
      message: 'Aporte registrado com sucesso.',
      saldoFicticio: novoSaldo,
      tokens: tokensAtualizados,
      historicoAportes: historicoAtualizado,
    });
  } catch (error) {
    return res.status(500).json({ error: 'Erro interno ao registrar o aporte.' });
  }
});

/**
 * ROTA POST: /api/venda
 * Registra a venda de tokens de uma startup pelo usuário.
 * Credita o valor no saldo fictício e remove os tokens da carteira.
 *
 * Recebe: { uid, startupId, tokenQuantity }
 * Retorna: { message, saldoFicticio, tokens, historicoAportes }
 */
app.post('/api/venda', async (req, res) => {
  const { uid, startupId, tokenQuantity } = req.body;

  if (!uid || !startupId || !tokenQuantity) {
    return res.status(400).json({ error: 'Dados insuficientes para registrar a venda.' });
  }

  try {
    const usuarioDocRef = doc(db, 'users', uid);
    const usuarioSnapshot = await getDoc(usuarioDocRef);

    if (!usuarioSnapshot.exists()) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    const usuarioData = usuarioSnapshot.data();
    const tokensAtuais = usuarioData.tokens || {};
    const tokenKey = startupId.toString();
    const investimentoExistente = tokensAtuais[tokenKey];

    // Verifica se o usuário realmente possui tokens dessa startup
    if (!investimentoExistente || Number(investimentoExistente.tokens || 0) <= 0) {
      return res.status(400).json({ error: 'Nenhum token disponível para venda nesta startup.' });
    }

    const quantidadeAtual = Number(investimentoExistente.tokens || 0);
    const quantidadeVenda = Number(tokenQuantity);

    // Valida a quantidade: deve ser positiva e não ultrapassar o que o usuário tem
    if (quantidadeVenda <= 0 || quantidadeVenda > quantidadeAtual) {
      return res.status(400).json({ error: 'Quantidade de tokens inválida para venda.' });
    }

    // Calcula o valor recebido pela venda (preço unitário × quantidade vendida)
    const precoToken = Number(investimentoExistente.tokenPrice || 0);
    const valorVenda = precoToken * quantidadeVenda;
    const novoSaldo = Number(usuarioData.saldoFicticio || 0) + valorVenda; // Credita no saldo
    const novoQuantidade = quantidadeAtual - quantidadeVenda; // Tokens restantes

    // Atualiza os dados do investimento na startup
    const novoInvestimento = {
      ...investimentoExistente,
      valor: Number(investimentoExistente.valor || 0) - valorVenda, // Subtrai valor vendido
      tokens: novoQuantidade,
      updatedAt: new Date().toLocaleString('pt-BR'),
    };

    // Atualiza a carteira: se vendeu todos os tokens, remove a entrada; senão atualiza
    const novoTokens = { ...tokensAtuais };
    if (novoQuantidade > 0) {
      novoTokens[tokenKey] = novoInvestimento; // Ainda tem tokens: atualiza
    } else {
      delete novoTokens[tokenKey]; // Vendeu tudo: remove da carteira
    }

    // Registra a venda no histórico de transações
    const vendaEntry = {
      uid, startupId,
      startupNome: investimentoExistente.startupNome || 'Startup',
      amount: valorVenda, tokenPrice: precoToken,
      tokensQuantity: quantidadeVenda,
      tipo: 'venda',
      createdAt: new Date().toLocaleString('pt-BR'),
    };

    const historicoAtualizado = [...(usuarioData.historicoAportes || []), vendaEntry];

    // Salva as alterações no Firestore
    await setDoc(usuarioDocRef, {
      saldoFicticio: novoSaldo,
      tokens: novoTokens,
      historicoAportes: historicoAtualizado,
    }, { merge: true });

    return res.status(200).json({
      message: 'Tokens vendidos com sucesso.',
      saldoFicticio: novoSaldo,
      tokens: novoTokens,
      historicoAportes: historicoAtualizado,
    });
  } catch (error) {
    return res.status(500).json({ error: 'Erro interno ao registrar venda.' });
  }
});

/**
 * ROTA POST: /api/depositar
 * Adiciona saldo fictício à carteira do usuário (simulação de depósito).
 * Limite máximo de R$50.000 por depósito.
 *
 * Recebe: { uid, valor }
 * Retorna: { message, saldoFicticio }
 */
app.post('/api/depositar', async (req, res) => {
  const { uid, valor } = req.body;

  if (!uid || !valor) {
    return res.status(400).json({ error: 'uid e valor são obrigatórios.' });
  }

  // Converte para número e valida o intervalo permitido
  const valorDeposito = Number(valor);
  if (isNaN(valorDeposito) || valorDeposito <= 0 || valorDeposito > 50000) {
    return res.status(400).json({ error: 'Valor inválido. O depósito deve ser entre R$ 0,01 e R$ 50.000.' });
  }

  try {
    const usuarioDocRef = doc(db, 'users', uid);
    const snapshot = await getDoc(usuarioDocRef);

    if (!snapshot.exists()) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    const data = snapshot.data();
    // Calcula o novo saldo somando o depósito ao saldo atual
    const novoSaldo = Number(data.saldoFicticio || 0) + valorDeposito;

    // Registra o depósito no histórico de transações
    const depositoEntry = {
      uid,
      startupId: null,          // Depósito não é vinculado a nenhuma startup
      startupNome: 'Depósito',
      amount: valorDeposito,
      tokenPrice: 0,
      tokensQuantity: 0,
      tipo: 'deposito',
      createdAt: new Date().toLocaleString('pt-BR'),
    };

    // Salva o novo saldo e o registro no histórico
    await setDoc(usuarioDocRef, {
      saldoFicticio: novoSaldo,
      historicoAportes: [...(data.historicoAportes || []), depositoEntry],
    }, { merge: true });

    return res.status(200).json({
      message: `Depósito de R$ ${valorDeposito.toFixed(2)} realizado com sucesso.`,
      saldoFicticio: novoSaldo,
    });
  } catch (error) {
    return res.status(500).json({ error: 'Erro interno ao processar depósito.' });
  }
});

// ============================================================
// ROTAS DE PERGUNTAS E RESPOSTAS (Q&A)
// ============================================================

/**
 * ROTA GET: /api/perguntas/:startupId
 * Retorna as perguntas de uma startup específica.
 * Retorna TODAS as perguntas públicas + as perguntas privadas do usuário (se uid fornecido).
 *
 * Parâmetro de URL: :startupId — ID da startup
 * Query string: ?uid=... — (opcional) filtra para incluir perguntas privadas do usuário
 * Retorna: array de perguntas ordenado por data (mais recente primeiro)
 */
app.get('/api/perguntas/:startupId', async (req, res) => {
  const { startupId } = req.params;
  const { uid } = req.query; // uid é opcional — vem como ?uid=xxx na URL

  try {
    // Busca todas as perguntas da startup
    const perguntasRef = collection(db, 'perguntas');
    const q = query(perguntasRef, where('startupId', '==', startupId));
    const snapshot = await getDocs(q);

    const perguntas = [];
    snapshot.forEach(d => {
      const data = d.data();
      // Inclui: perguntas públicas OU perguntas privadas do próprio usuário
      if (data.tipo === 'publica' || (uid && data.uid === uid)) {
        perguntas.push({ id: d.id, ...data });
      }
    });

    // Ordena por data de criação (mais recente primeiro)
    perguntas.sort((a, b) => (b.criadoEm || '') > (a.criadoEm || '') ? 1 : -1);

    return res.status(200).json(perguntas);
  } catch (error) {
    return res.status(500).json({ error: 'Erro ao buscar perguntas.' });
  }
});

/**
 * ROTA POST: /api/perguntas
 * Registra uma nova pergunta de um usuário sobre uma startup.
 * A resposta fica como null até que um administrador a preencha no Firestore.
 *
 * Recebe: { uid, startupId, pergunta, tipo } — tipo pode ser 'publica' ou 'privada'
 * Retorna: o documento criado com ID
 */
app.post('/api/perguntas', async (req, res) => {
  const { uid, startupId, pergunta, tipo } = req.body;

  if (!uid || !startupId || !pergunta) {
    return res.status(400).json({ error: 'uid, startupId e pergunta são obrigatórios.' });
  }

  // Define o tipo: se não informado ou inválido, usa 'publica' como padrão
  const tipoPergunta = tipo === 'privada' ? 'privada' : 'publica';

  // Garante que a pergunta tem um conteúdo mínimo
  if (pergunta.trim().length < 5) {
    return res.status(400).json({ error: 'A pergunta deve ter pelo menos 5 caracteres.' });
  }

  try {
    // Busca o nome do autor (para exibir na tela junto com a pergunta)
    const usuarioDoc = await getDoc(doc(db, 'users', uid));
    const nomeAutor = usuarioDoc.exists() ? (usuarioDoc.data().nomeCompleto || 'Anônimo') : 'Anônimo';

    // Monta o documento da nova pergunta
    const novaPergunta = {
      uid,                           // ID do usuário que perguntou
      nomeAutor,                     // Nome para exibição
      startupId,                     // Qual startup é a pergunta
      pergunta: pergunta.trim(),     // Texto da pergunta (sem espaços extras)
      resposta: null,                // Null até que um admin responda no Firestore
      tipo: tipoPergunta,            // 'publica' ou 'privada'
      criadoEm: new Date().toLocaleString('pt-BR'),
    };

    // addDoc cria o documento com ID automático gerado pelo Firestore
    const docRef = await addDoc(collection(db, 'perguntas'), novaPergunta);

    // Retorna o documento criado incluindo o ID gerado
    return res.status(201).json({ id: docRef.id, ...novaPergunta });
  } catch (error) {
    return res.status(500).json({ error: 'Erro ao registrar pergunta.' });
  }
});

// ============================================================
// INICIALIZAÇÃO DO SERVIDOR
// ============================================================

const PORT = 3000;

// Inicia o servidor na porta 3000 e exibe mensagem de confirmação no terminal
app.listen(PORT, () => {
  console.log('============================================');
  console.log('🚀 API do MesclaInvest iniciada com sucesso!');
  console.log('🌐 Endereço: http://localhost:' + PORT);
  console.log('⏳ Status: aguardando requisições...');
  console.log('Pressione Ctrl+C para parar o servidor.');
  console.log('============================================');
});
