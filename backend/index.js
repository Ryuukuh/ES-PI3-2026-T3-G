/**
 * PROJETO INTEGRADOR 3 - MESCLAINVEST
 * Autor Principal: Rafael Elias Correa
 * Componente: Backend - Rotas de Cadastro, Login e Listagem de Startups (Issue #7, #8 e #11)
 */

const express = require('express');
const cors = require('cors'); // Habilita requisições vindas do Flutter Web
const bcrypt = require('bcrypt');
const { initializeApp } = require("firebase/app");
const { getFirestore, collection, doc, setDoc, query, where, getDocs } = require("firebase/firestore");

const app = express();

app.use(cors()); // Libera o acesso para o navegador não bloquear o app
app.use(express.json()); // Habilita o servidor a ler JSON no corpo da requisição

// Sua configuração oficial do Firebase
const config = {
  apiKey: "AIzaSyA07tMa8LxgGPk4ah83yg4vF7aKUmAlmqU",
  authDomain: "mesclainvest-pi3.firebaseapp.com",
  projectId: "mesclainvest-pi3",
  storageBucket: "mesclainvest-pi3.firebasestorage.app",
  messagingSenderId: "234622831135",
  appId: "1:234622831135:web:74900b7b473ff9be1d632a",
  measurementId: "G-H87XRZ5H9R"
};

// Inicializando os serviços do Firebase
const firebaseApp = initializeApp(config);
const db = getFirestore(firebaseApp);

/**
 * ROTA POST: /api/cadastro (Issue #7 - Concluída)
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

    const dadosUsuarioFirestore = {
      nomeCompleto,
      email,
      cpf,
      telefone,
      senha: senhaCriptografada,
      dataCadastro: new Date().toLocaleString("pt-BR"),
      saldoFicticio: 10000.00,
      tokens: {}
    };

    const customUid = cpf.replace(/\D/g, ""); 
    await setDoc(doc(db, "users", customUid), dadosUsuarioFirestore);
    
    return res.status(201).json({ message: "Usuário cadastrado com sucesso!", uid: customUid });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

/**
 * ROTA POST: /api/login (Issue #8 - Concluída)
 */
app.post('/api/login', async (req, res) => {
  const { email, senha } = req.body;

  if (!email || !senha) {
    return res.status(400).json({ error: "Campos obrigatórios ausentes. Informe email e senha." });
  }

  try {
    console.log(`⏳ Buscando usuário com o e-mail: ${email}`);
    const usuariosRef = collection(db, "users");
    const q = query(usuariosRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    if (querySnapshot.empty) {
      return res.status(401).json({ error: "E-mail ou senha incorretos." });
    }

    const usuarioDoc = querySnapshot.docs[0];
    const dadosUsuario = usuarioDoc.data();
    const uid = usuarioDoc.id;

    console.log("🔒 Verificando criptografia da senha...");
    const senhaValida = await bcrypt.compare(senha, dadosUsuario.senha);

    if (!senhaValida) {
      return res.status(401).json({ error: "E-mail ou senha incorretos." });
    }

    console.log(`✅ [LOGIN SUCESSO] Usuário ${dadosUsuario.nomeCompleto} logado.`);

    return res.status(200).json({
      message: "Login efetuado com sucesso!",
      uid: uid,
      usuario: {
        nomeCompleto: dadosUsuario.nomeCompleto,
        email: dadosUsuario.email,
        saldoFicticio: dadosUsuario.saldoFicticio
      }
    });

  } catch (error) {
    console.error("❌ Erro no fluxo de login:", error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * ROTA GET: /api/startups (Issue #11 - Rota de Listagem Direta do Firestore)
 * Consome os dados reais salvos na nuvem sem nenhuma informação estática no código.
 */
app.get('/api/startups', async (req, res) => {
  try {
    console.log("⏳ Consultando catálogo de startups direto do Firestore...");
    const startupsRef = collection(db, "startups");
    const querySnapshot = await getDocs(startupsRef);

    // Mapeia os documentos que já existem fisicamente no banco de dados
    const listaStartups = querySnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    console.log(`✅ [SUCESSO] ${listaStartups.length} startups oficiais carregadas da nuvem.`);
    return res.status(200).json(listaStartups);

  } catch (error) {
    console.error("❌ Erro ao listar startups:", error);
    return res.status(500).json({ error: "Erro interno ao consultar catálogo no banco de dados." });
  }
});

// Inicialização do servidor local na porta 3000
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 API do MesclaInvest rodando em http://localhost:${PORT}`);
});