/**
 * PROJETO INTEGRADOR 3 - MESCLAINVEST
 * Autor Principal: Rafael Elias Correa
 * Inicialização do Firebase e Modelagem/Teste da Coleção 'users' (Issue #6)
 */

const { initializeApp } = require("firebase/app");
const { getFirestore, collection, addDoc } = require("firebase/firestore");

// Sua configuração oficial do Firebase (Mantida intacta)
const firebaseConfig = {
  apiKey: "AIzaSyA07tMa8LxgGPk4ah83yg4vF7aKUmAlmqU",
  authDomain: "mesclainvest-pi3.firebaseapp.com",
  projectId: "mesclainvest-pi3",
  storageBucket: "mesclainvest-pi3.firebasestorage.app",
  messagingSenderId: "234622831135",
  appId: "1:234622831135:web:74900b7b473ff9be1d632a",
  measurementId: "G-H87XRZ5H9R"
};

// Inicializando o Firebase e o Banco de Dados
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// Função para validar e estruturar o usuário conforme a Seção 5.1 do PDF do PI3
async function testarModelagemUser() {
  console.log('⏳ Testando estruturação da coleção "users"...');

  // Criando o objeto com os 4 campos obrigatórios exigidos pelo professor Mateus
  const dadosNovoUsuario = {
    nomeCompleto: "Rafael Elias Correa Teste",
    email: "rafael.teste@puc.com",
    cpf: "12345678901",
    telefone: "19999999999",
    dataCadastro: new Date().toLocaleString("pt-BR"),
    saldoFicticio: 10000.00,  // Crédito interno simulado para o balcão de negociação
    tokens: {}                // Carteira de tokens de startups (começa vazia)
  };

  // Validação simples de QA antes de mandar pro banco
  if (!dadosNovoUsuario.nomeCompleto || !dadosNovoUsuario.email.includes('@') || dadosNovoUsuario.cpf.length < 11 || !dadosNovoUsuario.telefone) {
    console.error("❌ ERRO: Objeto de usuário quebra as regras obrigatórias do PDF do PI3.");
    return;
  }

  try {
    // Gravando o usuário de teste na coleção 'users' usando o seu padrão do addDoc
    const docRef = await addDoc(collection(db, "users"), dadosNovoUsuario);
    console.log("✅ ISSUE 6 CONCLUÍDA: Coleção 'users' modelada e testada! ID do documento:", docRef.id);
  } catch (error) {
    console.error("❌ ERRO AO SALVAR USUÁRIO NO FIRESTORE:", error);
  }
}

// Executa o teste de modelagem da Issue 6
testarModelagemUser(); 