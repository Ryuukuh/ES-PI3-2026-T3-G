// 1. Importando as funções do SDK do Firebase que instalamos via npm
const { initializeApp } = require("firebase/app");
const { getFirestore, collection, addDoc } = require("firebase/firestore");

// 2. A sua configuração oficial do Firebase
const firebaseConfig = {
  apiKey: "AIzaSyA07tMa8LxgGPk4ah83yg4vF7aKUmAlmqU",
  authDomain: "mesclainvest-pi3.firebaseapp.com",
  projectId: "mesclainvest-pi3",
  storageBucket: "mesclainvest-pi3.firebasestorage.app",
  messagingSenderId: "234622831135",
  appId: "1:234622831135:web:74900b7b473ff9be1d632a",
  measurementId: "G-H87XRZ5H9R"
};

// 3. Inicializando o Firebase e o Banco de Dados
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// 4. Função para testar se a API do Node realmente grava no Firestore
async function testarConexaoBackend() {
  try {
    const docRef = await addDoc(collection(db, "teste_conexao"), {
      status: "Conectado com sucesso via Node.js!",
      horario: new Date().toLocaleString("pt-BR"),
      desenvolvedor: "Rafael"
    });
    console.log("✅ BANCO CONECTADO: Documento gravado com ID:", docRef.id);
  } catch (error) {
    console.error("❌ ERRO AO CONECTAR NO FIRESTORE:", error);
  }
}

// Executa o teste assim que o arquivo rodar
testarConexaoBackend();