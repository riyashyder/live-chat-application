import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFF8B85FF);
  static const primaryDark = Color(0xFF4A42DB);

  // Accent
  static const accent = Color(0xFF00D9FF);
  static const accentAlt = Color(0xFFFF6B9D);

  // Semantic
  static const success = Color(0xFF4CAF50);
  static const online = Color(0xFF4ADE80);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFFBBF24);

  // Light theme
  static const lightBg = Color(0xFFF8F9FE);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF1F3F8);
  static const lightText = Color(0xFF1A1D26);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightBorder = Color(0xFFE5E7EB);

  // Dark theme
  static const darkBg = Color(0xFF0F1117);
  static const darkSurface = Color(0xFF1A1D2E);
  static const darkCard = Color(0xFF242736);
  static const darkText = Color(0xFFF9FAFB);
  static const darkTextSecondary = Color(0xFF9CA3AF);
  static const darkBorder = Color(0xFF374151);

  // Chat bubbles
  static const senderBubbleLight = Color(0xFF6C63FF);
  static const receiverBubbleLight = Color(0xFFF1F3F8);
  static const senderBubbleDark = Color(0xFF5B54E8);
  static const receiverBubbleDark = Color(0xFF242736);

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF00D9FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkGradient = LinearGradient(
    colors: [Color(0xFF1A1D2E), Color(0xFF0F1117)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
