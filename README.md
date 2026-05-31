# ES-PI3-2026-T3-G — MesclaInvest

Repositório central de desenvolvimento do **MesclaInvest**, aplicativo mobile de simulação de investimentos em startups com tokenização de ativos. Desenvolvido para a disciplina de **Projeto Integrador 3** do curso de **Engenharia de Software** da **PUC-Campinas**, 2026.

---

## 🎯 Visão Geral do Projeto

O MesclaInvest simula um ecossistema digital de investimentos baseado na negociação de tokens representativos de startups vinculadas ao **Mescla** — o ecossistema de inovação da PUC-Campinas.

O aplicativo permite que o usuário cadastre-se, visualize startups, simule aportes financeiros em tokens, acompanhe a valorização de sua carteira com gráficos interativos e gerencie sua conta com segurança (MFA/2FA e recuperação de senha por e-mail).

Todas as operações de negociação têm caráter exclusivamente simulado, sem envolvimento de ativos reais.

---

## 🧩 Estrutura do Repositório

- `backend/`
  - `index.js` — servidor Node.js com todas as rotas REST e integração com Firebase Firestore
  - `package.json` — dependências do backend
  - `.env` — variáveis de ambiente (não versionado — contém credenciais Firebase e Gmail)
- `frontend/`
  - `lib/screens/` — telas do aplicativo Flutter
  - `lib/services/` — serviços auxiliares (SessionService)
  - `lib/theme/` — paleta de cores e tema visual
  - `pubspec.yaml` — dependências do app Flutter
  - `lib/firebase_options.dart` — configuração gerada pelo FlutterFire CLI
- `planilha_startups_simuladas.xlsx` — base de dados simulada com 8 startups para o catálogo

---

## 🛠️ Tecnologias Utilizadas

| Camada | Tecnologia |
|--------|-----------|
| Mobile (Frontend) | Flutter 3.x / Dart |
| Backend | Node.js LTS + Express / JavaScript |
| Banco de Dados | Firebase Firestore (banco não relacional) |
| Segurança de Senhas | bcrypt |
| E-mail (MFA + recuperação de senha) | Nodemailer + Gmail SMTP |
| Sessão Local | shared_preferences |
| Gráficos | fl_chart 1.2.0 |
| Controle de Versão | Git + GitHub |
| IDE | Visual Studio Code |

---

## ▶️ Como Executar o Backend

Abra o terminal em `backend/` e execute:

```powershell
cd backend
npm install
npm start
```

O servidor inicia em `http://localhost:3000`. Antes de iniciar, certifique-se de que o arquivo `.env` está configurado com as credenciais do Firebase e Gmail.

---

## ▶️ Como Executar o Frontend

Abra o terminal em `frontend/` e execute:

```powershell
cd frontend
flutter pub get
flutter run
```

> A execução do Flutter deve ser feita dentro de `frontend/`, onde está o `pubspec.yaml`.

---

## ✅ Status de Implementação dos Requisitos

*(Conforme Documento de Visão — Seção 5)*

### 5.1 — Autenticação

- [x] Cadastro com Nome completo, E-mail, CPF, Telefone celular e Senha
- [x] Validação de todos os campos no formulário de cadastro
- [x] Login por e-mail e senha
- [x] Sessão persistente — verificada automaticamente na abertura do app (`SplashScreen`)
- [x] Sem acesso anônimo à plataforma
- [x] Recuperação de senha ("Esqueci minha senha") com código enviado por e-mail

### 5.2 — Catálogo de Startups

- [x] Listagem dinâmica de startups via API (`GET /api/startups`)
- [x] Filtros por estágio de desenvolvimento (Ideação, Validação, Operação, Tração)
- [x] Filtros por setor de atuação
- [x] Visualização de descrição / sumário executivo
- [x] Estrutura societária e sócios fundadores com participação percentual
- [x] Volume de capital já aportado (simulado) e total de tokens emitidos
- [x] Membros do conselho e mentores
- [x] Vídeo de pitch (link externo com redirecionamento)
- [x] Perguntas e respostas públicas na página da startup (coleção `perguntas` no Firestore; respostas gerenciadas pelo administrador)
 
### 5.3 — Compra e Venda de Tokens — Balcão
 
- [x] Depósito de saldo fictício em reais (`POST /api/depositar`)
- [x] Simulação de aporte diretamente na página da startup (`POST /api/aporte`)
- [x] Cálculo proporcional de tokens com base no valor aportado e preço unitário
- [x] Confirmação de aporte com débito automático de saldo e atualização imediata
- [x] Venda de tokens com crédito automático de saldo (`POST /api/venda`)
- [x] Histórico de aportes e vendas registrado no Firestore
- [x] Transações restritas a usuários cadastrados na plataforma

### 5.4 — Acompanhamento da Valorização dos Tokens

- [x] Painel gráfico de valorização na tela de Carteira
- [x] Período Diário (24h) com rótulos por hora
- [x] Período Semanal (7 dias) com rótulos por dia da semana
- [x] Período Mensal (30 dias) com rótulos por dia
- [x] Período Últimos 6 meses (26 semanas) com rótulos por mês
- [x] Período YTD / Anual com rótulos por mês
- [x] Tooltip interativo com valor em R$ ao toque/hover
- [x] Gráfico de distribuição da carteira (pizza) por startup
- [x] Indicadores de saldo total e total investido

### 5.5 — Segurança de Acesso da Conta

- [x] Autenticação multifator (MFA/2FA) de forma opcional
- [x] Código MFA enviado por e-mail ao realizar login quando habilitado
- [x] Validação do código com expiração (15 min)
- [x] Toggle de MFA na tela de Perfil com feedback visual
- [x] Senhas armazenadas com hash bcrypt no Firestore

---

## 🗺️ Mapa Mental de Módulos e Ações do Sistema

### 🔐 1. Módulo: Autenticação & Perfil

* **Criar Conta (Sign Up):**
    * Formulário com validação de: Nome Completo, E-mail, Telefone, CPF e Senha.
    * Status: ✅ implementado em `frontend/lib/screens/register_screen.dart` e rota `POST /api/cadastro`.

* **Efetuar Login:**
    * Autenticação por e-mail e senha; suporte a fluxo MFA quando habilitado pelo usuário.
    * Status: ✅ implementado em `frontend/lib/screens/login_screen.dart` e rota `POST /api/login`.

* **Recuperação de Senha:**
    * Fluxo em 3 etapas com indicador de progresso: e-mail → código de verificação (6 dígitos) → nova senha.
    * Código enviado via Nodemailer (Gmail SMTP), válido por 15 minutos.
    * Status: ✅ implementado em `frontend/lib/screens/forgot_password_screen.dart` e rotas `POST /api/esqueci-senha`, `POST /api/resetar-senha`.

* **Sessão Persistente:**
    * Dados do usuário salvos localmente via `shared_preferences`; verificados e atualizados na abertura do app.
    * Status: ✅ implementado em `frontend/lib/screens/splash_screen.dart` + `frontend/lib/services/session_service.dart`.

* **Gerenciar Perfil:**
    * Visualização e edição de nome, e-mail, CPF e telefone.
    * Consulta ao saldo fictício disponível.
    * Toggle de MFA com indicador visual de status.
    * Logout com confirmação.
    * Status: ✅ implementado em `frontend/lib/screens/profile_screen.dart` e rota `PATCH /api/usuario/:uid`.

* **Autenticação Multifator (MFA/2FA):**
    * Envio de código numérico por e-mail durante o login quando MFA está ativo.
    * Toggle habilitado/desabilitado pelo próprio usuário na tela de perfil.
    * Status: ✅ implementado em `frontend/lib/screens/login_screen.dart` e rotas `POST /api/mfa/verificar-login`, `PATCH /api/mfa/toggle`.

### 🏢 2. Módulo: Catálogo de Startups

* **Dashboard Principal (Home):**
    * Exibição de cards de startups em destaque e acesso rápido ao catálogo completo.
    * Status: ✅ implementado em `frontend/lib/screens/home_screen.dart`.

* **Listar Startups:**
    * Cards com nome, estágio (com acentuação correta), setor e valor do token.
    * Filtros por estágio de maturidade e por setor de atuação.
    * Status: ✅ implementado em `frontend/lib/screens/catalog_screen.dart` e rota `GET /api/startups`.

* **Visualizar Detalhes da Startup:**
    * Descrição completa, setor, estágio, capital aportado e total de tokens emitidos.
    * Estrutura societária: sócios fundadores com participação percentual.
    * Mentores e corpo de conselho.
    * Link para vídeo de pitch com redirecionamento externo.
    * Indicação se o usuário já é investidor (exibe tokens em posse).
    * Status: ✅ implementado em `frontend/lib/screens/startup_details_screen.dart`.

* **Perguntas e Respostas Públicas:**
    * Usuários enviam perguntas pelo app (públicas ou privadas para investidores).
    * Respostas adicionadas pelo administrador diretamente no Firestore (`coleção perguntas`).
    * Status: ✅ implementado em `frontend/lib/screens/startup_details_screen.dart` e coleção `perguntas` no Firestore.

### 📊 3. Módulo: Simulador de Investimentos — Balcão de Tokens

* **Simular e Confirmar Aporte:**
    * Campo de valor em R$ com validação em tempo real do saldo disponível.
    * Cálculo proporcional de tokens (valor aportado ÷ preço unitário do token).
    * Resultado da simulação exibido como card antes da confirmação.
    * Confirmação com débito de saldo e atualização imediata na carteira sem necessidade de refresh.
    * Status: ✅ implementado em `frontend/lib/screens/startup_details_screen.dart` e rota `POST /api/aporte`.

* **Vender Tokens:**
    * Seleção da quantidade de tokens a vender com crédito automático do valor correspondente.
    * Acessível tanto pelos detalhes da startup quanto pela carteira.
    * Status: ✅ implementado em `frontend/lib/screens/startup_details_screen.dart` e `frontend/lib/screens/portfolio_screen.dart` via rota `POST /api/venda`.

* **Depósito de Saldo Fictício:**
    * Adição de saldo fictício em reais à carteira do investidor simulado.
    * Status: ✅ implementado em `frontend/lib/screens/portfolio_screen.dart` e rota `POST /api/depositar`.

### 💼 4. Módulo: Carteira do Investidor

* **Visão Geral:**
    * Saldo disponível, total investido e variação percentual do portfólio.
    * Status: ✅ implementado em `frontend/lib/screens/portfolio_screen.dart`.

* **Gráfico de Valorização:**
    * Gráfico de linha com 5 filtros de período: 24h, 7 dias, 30 dias, 6 meses, Anual (YTD).
    * Rótulos dinâmicos no eixo X (horas, dias da semana, meses) conforme o período.
    * Tooltip interativo com valor formatado em R$ ao toque/hover.
    * Status: ✅ implementado em `frontend/lib/screens/portfolio_screen.dart` com `fl_chart`.

* **Distribuição da Carteira:**
    * Gráfico de pizza com proporção de cada startup no portfólio total.
    * Status: ✅ implementado em `frontend/lib/screens/portfolio_screen.dart`.

* **Investimentos em Carteira:**
    * Lista de startups com tokens em posse, valor investido e ação de venda direta.
    * Status: ✅ implementado em `frontend/lib/screens/portfolio_screen.dart`.

---

## 📂 Arquivos de Dados

* **`planilha_startups_simuladas.xlsx`** — base de dados com 8 startups simuladas de diferentes setores e estágios de maturidade, utilizada como massa de dados do catálogo.

---

## 👥 Colaboradores

| Nome Completo | RA | Papel |
|--------------|-----|-------|
| Rafael Elias Correa | 18726497 | Desenvolvimento Full Stack |

* **Docente Orientador:** Prof. Me. Mateus Pereira Dias
* **Disciplina:** Projeto Integrador 3 — Engenharia de Software — PUC-Campinas — 2026
