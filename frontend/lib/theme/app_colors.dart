// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: Paleta de cores centralizadas do aplicativo
//
// Centralizar cores aqui é uma boa prática: se precisar mudar uma cor,
// basta alterar neste arquivo e o efeito se aplica em todo o app.

// Importa o Material do Flutter — necessário para usar o tipo 'Color'
import 'package:flutter/material.dart';

// Classe que agrupa todas as cores do projeto MesclaInvest.
// Não é para criar objetos — apenas organiza constantes de cor acessíveis
// em qualquer tela com: AppColors.primary, AppColors.background, etc.
class AppColors {
  // Construtor privado: impede que alguém crie uma instância com 'AppColors()'
  AppColors._();

  // Azul escuro — cor principal do app, usada em botões, barras e destaques
  // 0xFF = opacidade total (100%), 0D47A1 = código hexadecimal do azul escuro
  static const Color primary = Color(0xFF0D47A1);

  // Branco puro — cor de fundo padrão de todas as telas
  static const Color background = Colors.white;

  // Cinza muito escuro, quase preto — usado em títulos e textos principais
  // 0xFF212121 equivale ao "Grey 900" do Material Design
  static const Color textDark = Color(0xFF212121);

  // Cinza médio — usado em textos secundários, legendas e descrições
  // 0xFF757575 equivale ao "Grey 600" do Material Design
  static const Color textLight = Color(0xFF757575);
}
