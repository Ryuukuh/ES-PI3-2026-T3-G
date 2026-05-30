/**
 * PROJETO INTEGRADOR 3 - MESCLAINVEST
 * Autor Principal: Rafael Elias Correa
 * Componente: Backend - API REST completa
 */

require('dotenv').config();

const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const nodemailer = require('nodemailer');
const { initializeApp } = require("firebase/app");
const {
  getFirestore,
  collection,
  doc,
  setDoc,
  query,
  where,
  getDocs,
  getDoc,
  addDoc,
  orderBy,
} = require("firebase/firestore");

const app = express();

app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  console.log(`📥 [${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
  if (req.method !== 'GET') {
    console.log('     Payload:', JSON.stringify(req.body));
  }
  next();
});

const config = {
  apiKey: "AIzaSyA07tMa8LxgGPk4ah83yg4vF7aKUmAlmqU",
  authDomain: "mesclainvest-pi3.firebaseapp.com",
  projectId: "mesclainvest-pi3",
  storageBucket: "mesclainvest-pi3.firebasestorage.app",
  messagingSenderId: "234622831135",
  appId: "1:234622831135:web:74900b7b473ff9be1d632a",
  measurementId: "G-H87XRZ5H9R"
};

const firebaseApp = initializeApp(config);
const db = getFirestore(firebaseApp);

// Transporter para envio de e-mails via Gmail
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_PASS,
  },
});

function gerarCodigo6Digitos() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

async function enviarEmail(destinatario, assunto, corpo) {
  if (!process.env.GMAIL_USER || process.env.GMAIL_USER === 'seu_email@gmail.com') {
    console.log(`📧 [SIMULADO] Para: ${destinatario} | Assunto: ${assunto} | ${corpo}`);
    return;
  }
  await transporter.sendMail({
    from: `"MesclaInvest" <${process.env.GMAIL_USER}>`,
    to: destinatario,
    subject: assunto,
    text: corpo,
  });
}

/**
 * ROTA POST: /api/cadastro
 */
app.post('/api/cadastro', async (req, res) => {
  const { nomeCompleto, email, cpf, telefone, senha } = req.body;

  if (!nomeCompleto || !email || !cpf || !telefone || !senha) {
    return res.status(400).json({ error: "Campos obrigatórios ausentes. Informe nomeCompleto, email, cpf, telefone e senha." });
  }

  try {
    const usuariosRef = collection(db, "users");
    const q = query(usuariosRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    if (!querySnapshot.empty) {
      return res.status(400).json({ error: "Este e-mail já está cadastrado no sistema." });
    }

    const saltRounds = 10;
    const senhaCriptografada = await bcrypt.hash(senha, saltRounds);

    const dadosUsuario = {
      nomeCompleto,
      email,
      cpf,
      telefone,
      senha: senhaCriptografada,
      dataCadastro: new Date().toLocaleString("pt-BR"),
      saldoFicticio: 10000.00,
      tokens: {},
      historicoAportes: [],
      mfaEnabled: false,
    };

    const customUid = cpf.replace(/\D/g, "");
    await setDoc(doc(db, "users", customUid), dadosUsuario);

    return res.status(201).json({ message: "Usuário cadastrado com sucesso!", uid: customUid });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * ROTA POST: /api/login
 * Suporta MFA: se habilitado, retorna mfaRequired: true em vez dos dados do usuário
 */
app.post('/api/login', async (req, res) => {
  const { email, senha } = req.body;

  if (!email || !senha) {
    return res.status(400).json({ error: "Campos obrigatórios ausentes. Informe email e senha." });
  }

  try {
    const usuariosRef = collection(db, "users");
    const q = query(usuariosRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    if (querySnapshot.empty) {
      return res.status(401).json({ error: "E-mail ou senha incorretos." });
    }

    const usuarioDoc = querySnapshot.docs[0];
    const dadosUsuario = usuarioDoc.data();
    const uid = usuarioDoc.id;

    const senhaValida = await bcrypt.compare(senha, dadosUsuario.senha);
    if (!senhaValida) {
      return res.status(401).json({ error: "E-mail ou senha incorretos." });
    }

    // Se MFA está habilitado, envia código e retorna indicador
    if (dadosUsuario.mfaEnabled) {
      const codigo = gerarCodigo6Digitos();
      const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutos

      await setDoc(doc(db, "users", uid), { mfaCode: codigo, mfaCodeExpires: expiresAt }, { merge: true });

      await enviarEmail(
        email,
        'MesclaInvest — Código de verificação',
        `Seu código de verificação é: ${codigo}\n\nEle expira em 5 minutos. Não compartilhe com ninguém.`
      );

      console.log(`🔐 [MFA] Código gerado para ${email}: ${codigo}`);

      return res.status(200).json({ mfaRequired: true, uid });
    }

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
 * Valida o código MFA durante o fluxo de login
 */
app.post('/api/mfa/verificar-login', async (req, res) => {
  const { uid, codigo } = req.body;

  if (!uid || !codigo) {
    return res.status(400).json({ error: "uid e codigo são obrigatórios." });
  }

  try {
    const usuarioDocRef = doc(db, 'users', uid);
    const snapshot = await getDoc(usuarioDocRef);

    if (!snapshot.exists()) {
      return res.status(404).json({ error: "Usuário não encontrado." });
    }

    const data = snapshot.data();

    if (!data.mfaCode || data.mfaCode !== codigo) {
      return res.status(401).json({ error: "Código de verificação inválido." });
    }

    if (Date.now() > (data.mfaCodeExpires || 0)) {
      return res.status(401).json({ error: "Código de verificação expirado. Faça login novamente." });
    }

    // Limpa o código após validação
    await setDoc(usuarioDocRef, { mfaCode: null, mfaCodeExpires: null }, { merge: true });

    console.log(`✅ [MFA OK] Usuário ${uid} autenticado com sucesso via MFA.`);

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
 * Habilita ou desabilita MFA do usuário
 */
app.patch('/api/mfa/toggle', async (req, res) => {
  const { uid, habilitar } = req.body;

  if (!uid || typeof habilitar !== 'boolean') {
    return res.status(400).json({ error: "uid e habilitar (boolean) são obrigatórios." });
  }

  try {
    const usuarioDocRef = doc(db, 'users', uid);
    const snapshot = await getDoc(usuarioDocRef);

    if (!snapshot.exists()) {
      return res.status(404).json({ error: "Usuário não encontrado." });
    }

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
 * Gera código de redefinição e envia por e-mail
 */
app.post('/api/esqueci-senha', async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: "E-mail é obrigatório." });
  }

  try {
    const usuariosRef = collection(db, "users");
    const q = query(usuariosRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    // Mesmo que não encontre, retorna sucesso para não revelar quais e-mails existem
    if (querySnapshot.empty) {
      return res.status(200).json({ message: "Se este e-mail estiver cadastrado, você receberá as instruções em breve." });
    }

    const usuarioDoc = querySnapshot.docs[0];
    const uid = usuarioDoc.id;
    const codigo = gerarCodigo6Digitos();
    const expiresAt = Date.now() + 15 * 60 * 1000; // 15 minutos

    await setDoc(doc(db, "users", uid), {
      resetCode: codigo,
      resetCodeExpires: expiresAt,
    }, { merge: true });

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
 * Valida código e atualiza senha
 */
app.post('/api/resetar-senha', async (req, res) => {
  const { email, codigo, novaSenha } = req.body;

  if (!email || !codigo || !novaSenha) {
    return res.status(400).json({ error: "email, codigo e novaSenha são obrigatórios." });
  }

  if (novaSenha.length < 6) {
    return res.status(400).json({ error: "A nova senha deve ter pelo menos 6 caracteres." });
  }

  try {
    const usuariosRef = collection(db, "users");
    const q = query(usuariosRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    if (querySnapshot.empty) {
      return res.status(400).json({ error: "Código inválido ou expirado." });
    }

    const usuarioDoc = querySnapshot.docs[0];
    const uid = usuarioDoc.id;
    const data = usuarioDoc.data();

    if (!data.resetCode || data.resetCode !== codigo) {
      return res.status(400).json({ error: "Código inválido ou expirado." });
    }

    if (Date.now() > (data.resetCodeExpires || 0)) {
      return res.status(400).json({ error: "Código expirado. Solicite um novo." });
    }

    const senhaCriptografada = await bcrypt.hash(novaSenha, 10);

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

/**
 * ROTA GET: /api/usuario/:uid
 */
app.get('/api/usuario/:uid', async (req, res) => {
  const { uid } = req.params;
  if (!uid) return res.status(400).json({ error: 'UID do usuário é obrigatório.' });

  try {
    const usuarioDocRef = doc(db, 'users', uid);
    const usuarioSnapshot = await getDoc(usuarioDocRef);
    if (!usuarioSnapshot.exists()) return res.status(404).json({ error: 'Usuário não encontrado.' });

    const data = usuarioSnapshot.data();
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
 */
app.patch('/api/usuario/:uid', async (req, res) => {
  const { uid } = req.params;
  if (!uid) return res.status(400).json({ error: 'UID do usuário é obrigatório.' });

  const { nomeCompleto, email, cpf, telefone } = req.body;
  if (!nomeCompleto && !email && !cpf && !telefone) {
    return res.status(400).json({ error: 'Informe ao menos um campo para atualizar.' });
  }

  try {
    const usuarioDocRef = doc(db, 'users', uid);
    const usuarioSnapshot = await getDoc(usuarioDocRef);
    if (!usuarioSnapshot.exists()) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    const updates = {};
    if (nomeCompleto) updates.nomeCompleto = nomeCompleto;
    if (email) updates.email = email;
    if (cpf) updates.cpf = cpf;
    if (telefone) updates.telefone = telefone;

    if (email || cpf) {
      const usuariosRef = collection(db, 'users');
      const querySnapshot = await getDocs(query(usuariosRef, where(email ? 'email' : 'cpf', '==', email || cpf)));
      if (!querySnapshot.empty) {
        const conflictingUser = querySnapshot.docs.find(d => d.id !== uid);
        if (conflictingUser) {
          return res.status(400).json({ error: 'O e-mail ou CPF informado já está em uso por outro usuário.' });
        }
      }
    }

    await setDoc(usuarioDocRef, updates, { merge: true });
    const updatedSnapshot = await getDoc(usuarioDocRef);
    const updatedData = updatedSnapshot.data();
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

/**
 * ROTA GET: /api/startups
 */
app.get('/api/startups', async (req, res) => {
  try {
    const startupsRef = collection(db, "startups");
    const querySnapshot = await getDocs(startupsRef);

    const listaStartups = querySnapshot.docs.map(d => ({
      id: d.id,
      ...d.data()
    }));

    return res.status(200).json(listaStartups);
  } catch (error) {
    return res.status(500).json({ error: "Erro interno ao consultar catálogo." });
  }
});

/**
 * ROTA POST: /api/aporte
 */
app.post('/api/aporte', async (req, res) => {
  const { uid, startupId, startupNome, amount, tokenPrice, tokensQuantity } = req.body;

  if (!uid || !startupId || !startupNome || !amount || !tokenPrice || !tokensQuantity) {
    return res.status(400).json({ error: "Dados insuficientes para registrar o aporte." });
  }

  try {
    const usuarioDocRef = doc(db, 'users', uid);
    const usuarioSnapshot = await getDoc(usuarioDocRef);

    if (!usuarioSnapshot.exists()) {
      return res.status(404).json({ error: "Usuário não encontrado." });
    }

    const usuarioData = usuarioSnapshot.data();
    const saldoAtual = Number(usuarioData.saldoFicticio || 0);
    const valorAporte = Number(amount);
    const quantidadeTokens = Number(tokensQuantity);

    if (valorAporte > saldoAtual) {
      return res.status(400).json({ error: "Saldo insuficiente para este aporte." });
    }

    const tokensAtuais = usuarioData.tokens || {};
    const tokenKey = startupId.toString();
    const investimentoExistente = tokensAtuais[tokenKey] || {};

    const novoInvestimento = {
      startupNome,
      valor: Number(investimentoExistente.valor || 0) + valorAporte,
      tokens: Number(investimentoExistente.tokens || 0) + quantidadeTokens,
      tokenPrice,
      updatedAt: new Date().toLocaleString('pt-BR'),
    };

    const novoSaldo = saldoAtual - valorAporte;
    const novoAporte = {
      uid, startupId, startupNome,
      amount: valorAporte, tokenPrice,
      tokensQuantity: quantidadeTokens,
      tipo: 'aporte',
      createdAt: new Date().toLocaleString('pt-BR'),
    };

    const historicoAtualizado = [...(usuarioData.historicoAportes || []), novoAporte];
    const tokensAtualizados = { ...tokensAtuais, [tokenKey]: novoInvestimento };

    await setDoc(usuarioDocRef, {
      saldoFicticio: novoSaldo,
      tokens: tokensAtualizados,
      historicoAportes: historicoAtualizado,
    }, { merge: true });

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

    if (!investimentoExistente || Number(investimentoExistente.tokens || 0) <= 0) {
      return res.status(400).json({ error: 'Nenhum token disponível para venda nesta startup.' });
    }

    const quantidadeAtual = Number(investimentoExistente.tokens || 0);
    const quantidadeVenda = Number(tokenQuantity);

    if (quantidadeVenda <= 0 || quantidadeVenda > quantidadeAtual) {
      return res.status(400).json({ error: 'Quantidade de tokens inválida para venda.' });
    }

    const precoToken = Number(investimentoExistente.tokenPrice || 0);
    const valorVenda = precoToken * quantidadeVenda;
    const novoSaldo = Number(usuarioData.saldoFicticio || 0) + valorVenda;
    const novoQuantidade = quantidadeAtual - quantidadeVenda;

    const novoInvestimento = {
      ...investimentoExistente,
      valor: Number(investimentoExistente.valor || 0) - valorVenda,
      tokens: novoQuantidade,
      updatedAt: new Date().toLocaleString('pt-BR'),
    };

    const novoTokens = { ...tokensAtuais };
    if (novoQuantidade > 0) {
      novoTokens[tokenKey] = novoInvestimento;
    } else {
      delete novoTokens[tokenKey];
    }

    const vendaEntry = {
      uid, startupId,
      startupNome: investimentoExistente.startupNome || 'Startup',
      amount: valorVenda, tokenPrice: precoToken,
      tokensQuantity: quantidadeVenda,
      tipo: 'venda',
      createdAt: new Date().toLocaleString('pt-BR'),
    };

    const historicoAtualizado = [...(usuarioData.historicoAportes || []), vendaEntry];

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
 * Adiciona saldo fictício à carteira do usuário
 */
app.post('/api/depositar', async (req, res) => {
  const { uid, valor } = req.body;

  if (!uid || !valor) {
    return res.status(400).json({ error: 'uid e valor são obrigatórios.' });
  }

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
    const novoSaldo = Number(data.saldoFicticio || 0) + valorDeposito;

    const depositoEntry = {
      uid,
      startupId: null,
      startupNome: 'Depósito',
      amount: valorDeposito,
      tokenPrice: 0,
      tokensQuantity: 0,
      tipo: 'deposito',
      createdAt: new Date().toLocaleString('pt-BR'),
    };

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

/**
 * ROTA GET: /api/perguntas/:startupId
 * Retorna perguntas públicas de uma startup (+ privadas do usuário se informar uid)
 */
app.get('/api/perguntas/:startupId', async (req, res) => {
  const { startupId } = req.params;
  const { uid } = req.query;

  try {
    const perguntasRef = collection(db, 'perguntas');
    const q = query(perguntasRef, where('startupId', '==', startupId));
    const snapshot = await getDocs(q);

    const perguntas = [];
    snapshot.forEach(d => {
      const data = d.data();
      // Inclui públicas e privadas se o uid bater
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
 * Envia uma pergunta sobre uma startup
 */
app.post('/api/perguntas', async (req, res) => {
  const { uid, startupId, pergunta, tipo } = req.body;

  if (!uid || !startupId || !pergunta) {
    return res.status(400).json({ error: 'uid, startupId e pergunta são obrigatórios.' });
  }

  const tipoPergunta = tipo === 'privada' ? 'privada' : 'publica';

  if (pergunta.trim().length < 5) {
    return res.status(400).json({ error: 'A pergunta deve ter pelo menos 5 caracteres.' });
  }

  try {
    // Busca nome do usuário
    const usuarioDoc = await getDoc(doc(db, 'users', uid));
    const nomeAutor = usuarioDoc.exists() ? (usuarioDoc.data().nomeCompleto || 'Anônimo') : 'Anônimo';

    const novaPergunta = {
      uid,
      nomeAutor,
      startupId,
      pergunta: pergunta.trim(),
      resposta: null,
      tipo: tipoPergunta,
      criadoEm: new Date().toLocaleString('pt-BR'),
    };

    const docRef = await addDoc(collection(db, 'perguntas'), novaPergunta);

    return res.status(201).json({ id: docRef.id, ...novaPergunta });
  } catch (error) {
    return res.status(500).json({ error: 'Erro ao registrar pergunta.' });
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log('============================================');
  console.log('🚀 API do MesclaInvest iniciada com sucesso!');
  console.log('🌐 Endereço: http://localhost:' + PORT);
  console.log('⏳ Status: aguardando requisições...');
  console.log('Pressione Ctrl+C para parar o servidor.');
  console.log('============================================');
});
