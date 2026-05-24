# ES-PI3-2026-T3-G — MesclaInvest

Repositório central de desenvolvimento do projeto **MesclaInvest**, aplicativo mobile de simulação de investimentos em startups utilizando conceitos de tokenização de ativos. Projeto desenvolvido para a disciplina de **Projeto Integrador 3** do curso de **Engenharia de Software** da **PUC-Campinas**.

---

## 🗺️ Mapa Mental de Módulos e Ações do Sistema

Abaixo está o detalhamento estruturado e ramificado dos módulos do aplicativo, especificando exatamente as ações e interações disponíveis para o usuário em cada camada (Atendimento integral ao Item 2 das orientações da Profa. Renata):

### 🔐 1. Módulo: Autenticação & Perfil
* **Criar Conta (Sign Up):**
    * Formulário com validação de dados obrigatórios (*Nome Completo, E-mail, Telefone, CPF e Senha*).
* **Efetuar Login (Sign In):**
    * Autenticação por credenciais para acesso seguro do investidor simulado.
* **Gerenciar Perfil:**
    * Visualização de informações cadastrais básicas.
    * Consulta ao saldo fictício inicial em carteira disponível para realizar os aportes nas startups do catálogo.

### 🏢 2. Módulo: Catálogo de Startups (Base de Dados)
* **Listar Startups:**
    * Exibição dinâmica das empresas parceiras através de cards com informações resumidas na home.
    * Filtros avançados para refinamento da busca por *Estágio de Maturação* (Ideação, Validação, Operação, Tração) e *Setor de Atuação* (Fintech, Edtech, Agrotech, Cleantech, etc.).
* **Visualizar Detalhes da Startup:**
    * Acesso à descrição completa da tese de mercado da empresa.
    * Consulta de dados transparentes de governança (*Sócios Fundadores* e *Mentores/Corpo Técnico de Conselho*).
    * Visualização completa do histórico financeiro simulado (*Capital já aportado acumulado* e *Volume total de tokens emitidos*).
* **Assistir Pitch:**
    * Redirecionamento ou acesso direto ao link do vídeo demonstrativo/pitch de vendas da startup selecionada.

### 📊 3. Módulo: Simulador de Investimentos (Aportes)
* **Simular Aporte Financeiro:**
    * Campo de inserção de valor monetário simulado (R$) destinado à startup desejada.
    * Validação em tempo real para impedir aportes maiores do que o saldo atual da carteira.
* **Calcular Proporcionalidade de Ativos:**
    * Processamento síncrono da quantidade estimada de tokens que o usuário receberá com base no valor aportado e na participação societária correspondente.
* **Confirmar Transação Fictícia:**
    * Processo de débito automático do valor investido no saldo geral da carteira virtual do usuário.
    * Atualização imediata e inclusão automática da startup no portfólio pessoal de ativos simulados do investidor.

---

## 📂 Estrutura de Arquivos de Dados do Repositório

* **`planilha_startups_simuladas.xlsx`**: Base de dados em formato de planilha Excel contendo o mapeamento detalhado de 8 startups de diferentes setores e estágios, fornecendo a massa de dados simulada completa que alimenta o catálogo do aplicativo.

---

## 👥 Colaboradores & Autoria
* **Docente Responsável:** Profa. Renata
* **Equipe de Desenvolvimento:** Grupo T3-G (Engenharia de Software - PUC-Campinas)