/**
 * PROJETO INTEGRADOR 3 - MESCLAINVEST
 * Autor Principal: Rafael Elias Correa RA:18726497
 * * Definição de Estrutura e Validação da Coleção 'users' conforme Seção 5.1 do Documento de Visão.
 */

class User {
  constructor(nomeCompleto, email, cpf, telefone) {
    this.nomeCompleto = nomeCompleto;
    this.email = email;
    this.cpf = cpf;
    this.telefone = telefone;
    this.dataCadastro = new Date(); // Registra quando o usuário entrou
    this.saldoFicticio = 10000.00;  // Carteira digital simulada pedida no PDF (Ex: R$ 10.000,00)
    this.tokens = {};               // Carteira de tokens de startups (começa vazia)
  }

  // Função auxiliar para validar se o objeto tem todos os campos obrigatórios do PDF
  isValid() {
    if (!this.nomeCompleto || typeof this.nomeCompleto !== 'string') return false;
    if (!this.email || !this.email.includes('@')) return false;
    if (!this.cpf || this.cpf.length < 11) return false;
    if (!this.telefone) return false;
    return true;
  }

  // Transforma o objeto em um JSON limpo para salvar direto no Firestore
  toFirestore() {
    return {
      nomeCompleto: this.nomeCompleto,
      email: this.email,
      cpf: this.cpf,
      telefone: this.telefone,
      dataCadastro: this.dataCadastro,
      saldoFicticio: this.saldoFicticio,
      tokens: this.tokens
    };
  }
}

module.exports = User;