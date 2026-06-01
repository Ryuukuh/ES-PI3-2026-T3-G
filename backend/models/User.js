/**
 * PROJETO INTEGRADOR 3 - MESCLAINVEST
 * Autor Principal: Rafael Elias Correa RA: 18726497
 * Componente: Modelo de dados do Usuário
 *
 * Este arquivo define a "forma" (estrutura) de um usuário no sistema.
 * Em programação orientada a objetos, uma classe funciona como um molde:
 * você define uma vez quais campos e comportamentos um usuário tem,
 * e depois pode criar quantos usuários quiser a partir desse molde.
 */

/**
 * Classe User — representa um usuário investidor do MesclaInvest.
 * Define quais dados cada usuário possui e como validá-los antes de salvar no banco.
 */
class User {
  /**
   * Construtor: método executado automaticamente quando se cria um novo usuário.
   * Recebe os dados básicos e inicializa os campos padrão.
   *
   * @param {string} nomeCompleto - Nome completo do usuário
   * @param {string} email        - E-mail de acesso à plataforma
   * @param {string} cpf          - CPF (usado como ID único no banco)
   * @param {string} telefone     - Telefone celular de contato
   */
  constructor(nomeCompleto, email, cpf, telefone) {
    // Campos informados pelo usuário no cadastro
    this.nomeCompleto = nomeCompleto;
    this.email = email;
    this.cpf = cpf;
    this.telefone = telefone;

    // Campos gerados automaticamente pelo sistema
    this.dataCadastro = new Date();     // Registra o momento exato do cadastro
    this.saldoFicticio = 10000.00;      // Cada usuário começa com R$10.000 para investir (simulado)
    this.tokens = {};                   // Carteira de tokens começa vazia — objeto chave:valor
  }

  /**
   * Valida se este objeto de usuário tem todos os campos obrigatórios preenchidos.
   * Retorna true se estiver válido, false caso algum campo falte ou esteja incorreto.
   *
   * Usado antes de salvar no banco para garantir integridade dos dados.
   */
  isValid() {
    // Verifica se nome está preenchido e é uma string de texto
    if (!this.nomeCompleto || typeof this.nomeCompleto !== 'string') return false;

    // Verifica se e-mail está preenchido e contém o caractere '@'
    if (!this.email || !this.email.includes('@')) return false;

    // Verifica se CPF está preenchido e tem pelo menos 11 dígitos
    if (!this.cpf || this.cpf.length < 11) return false;

    // Verifica se telefone está preenchido
    if (!this.telefone) return false;

    // Se chegou até aqui, todos os campos são válidos
    return true;
  }

  /**
   * Converte o objeto User para um formato JSON compatível com o Firestore.
   * O Firestore trabalha com objetos JavaScript simples — não com instâncias de classe.
   * Este método retorna apenas os dados relevantes para salvar no banco.
   */
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

// Exporta a classe para que outros arquivos possam usá-la com require('...User.js')
module.exports = User;
