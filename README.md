# MesclaInvest

Aplicativo mobile de simulação de investimentos em startups do ecossistema Mescla da PUC-Campinas.

## Integrantes

| Nome | RA |
|------|----|
| Rafael Elias Correa | 18726497 |

## Tecnologias

- **Frontend:** Flutter / Dart
- **Backend:** Node.js / Express / JavaScript
- **Banco de Dados:** Firebase Firestore
- **Autenticação:** bcrypt + MFA por e-mail (nodemailer)
- **Controle de Versão:** Git / GitHub

## Como executar

### Backend

```bash
cd backend
npm install
node index.js
```

O servidor iniciará em `http://localhost:3000`.

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

> Certifique-se de que o backend está rodando antes de iniciar o app.

## Funcionalidades

- Cadastro e login com autenticação multifator (MFA)
- Recuperação de senha por e-mail
- Catálogo de startups com filtros por estágio e setor
- Detalhes da startup: estrutura societária, mentores, Q&A
- Simulação de compra e venda de tokens inteiros
- Carteira digital com saldo fictício
- Dashboard com gráfico de valorização dos tokens
