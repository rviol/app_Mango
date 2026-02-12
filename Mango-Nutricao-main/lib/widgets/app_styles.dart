import 'package:flutter/material.dart';

class AppStyles {
  // --- RAIOS (RADII) ---
  
  // Para botões (ElevatedButton, OutlinedButton, InkWell de ação)
  static const double radiusButton = 16.0;
  
  // Para Cards, Containers principais, Modais e o "Resto"
  static const double radiusCard = 25.0;

  // --- BORDAS (BORDER RADIUS) ---
  
  static BorderRadius get borderButton => BorderRadius.circular(radiusButton);
  static BorderRadius get borderCard => BorderRadius.circular(radiusCard);
  
  // Usado para Sheets que abrem de baixo ou containers de fundo
  static BorderRadius get borderTopCard => BorderRadius.only(
    topLeft: Radius.circular(radiusCard),
    topRight: Radius.circular(radiusCard),
  );

  // --- SHAPES (FORMATOS) ---
  
  // Use isso dentro do style: ElevatedButton.styleFrom(shape: ...)
  static RoundedRectangleBorder get shapeButton => RoundedRectangleBorder(
    borderRadius: borderButton,
  );

  static RoundedRectangleBorder get shapeCard => RoundedRectangleBorder(
    borderRadius: borderCard,
  );
}