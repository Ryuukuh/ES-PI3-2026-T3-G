/**
 * PROJETO INTEGRADOR 3 - MESCLAINVEST
 * Autor Principal: Rafael Elias Correa
 * Componente: Backend - Rota de Cadastro de Usuários via Firestore (Issue #7)
 */

const express = require('express');
const bcrypt = require('bcrypt');
const { initializeApp } = require("firebase/app");
const { getFirestore, collection, doc, setDoc, query, where, getDocs } = require("firebase/firestore");

const app = express();
app.use(express.json()); // Habilita o servidor a ler JSON no corpo da requisição

// Sua configuração oficial do Firebase (Igual ao print image_b7d62f.png)
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
 * ROTA POST: /api/cadastro
 * Objetivo: Validar dados, criptografar senha e salvar o usuário direto no Firestore
 */
app.post('/api/cadastro', async (req, res) => {
  const { nomeCompleto, email, cpf, telefone, senha } = req.body;

  // Validação de QA: Garante que os campos obrigatórios do PDF estão presentes
  if (!nomeCompleto || !email || !cpf || !telefone || !senha) {
    return res.status(400).json({ 
      error: "Campos obrigatórios ausentes. Informe nomeCompleto, email, cpf, telefone e senha." 
    });
  }

  try {
    console.log("⏳ Validando se o e-mail já existe no banco...");
    
    // 1. Regra de QA: Evita cadastrar o mesmo e-mail duas vezes
    const usuariosRef = collection(db, "users");
    const q = query(usuariosRef, where("email", "==", email));
    const querySnapshot = await getDocs(q);

    if (!querySnapshot.empty) {
      return res.status(400).json({ error: "Este e-mail já está cadastrado no sistema." });
    }

    console.log("🔒 Criptografando a senha do usuário...");
    // 2. Criptografia da senha com Salt de 10 rounds (Segurança nível produção)
    const saltRounds = 10;
    const senhaCriptografada = await bcrypt.hash(senha, saltRounds);

    // 3. Monta o payload estruturado exatamente como o Documento de Visão exige
    const dadosUsuarioFirestore = {
      nomeCompleto,
      email,
      cpf,
      telefone,
      senha: senhaCriptografada, // Senha protegida contra vazamentos
      dataCadastro: new Date().toLocaleString("pt-BR"),
      saldoFicticio: 10000.00,  // Saldo simulado de R$ 10k solicitado pela faculdade
      tokens: {}                // Carteira de startups zerada
    };

    // 4. Cria um ID de documento único baseado no CPF (ou deixa o Firestore gerar um automático se preferir)
    // Usar o CPF limpo como ID impede duplicidade de conta por pessoa física
    const customUid = cpf.replace(/\D/g, ""); 

    console.log("💾 Gravando registro no Cloud Firestore...");
    await setDoc(doc(db, "users", customUid), dadosUsuarioFirestore);

    console.log(`✅ Registro efetuado! Usuário criado com sucesso no banco.`);
    
    return res.status(201).json({ 
      message: "Usuário cadastrado com sucesso!", 
      uid: customUid 
    });

  } catch (error) {
    console.error("❌ Erro ao tentar cadastrar usuário:", error);
    return res.status(500).json({ error: error.message });
  }
});

// Inicialização do servidor local na porta 3000
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 API do MesclaInvest rodando em http://localhost:${PORT}`);
});