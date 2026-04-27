import 'package:flutter/material.dart';

extension KvizThemeColors on BuildContext {
  Color get pageBg => Theme.of(this).scaffoldBackgroundColor;
  Color get cardBg => Theme.of(this).colorScheme.surface;
  Color get innerBg => Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get borderColor => Theme.of(this).colorScheme.outlineVariant;
  Color get strongText => Theme.of(this).colorScheme.onSurface;
  Color get mutedText => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get dimText =>
      Theme.of(this).colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
  Color get accentText => Theme.of(this).colorScheme.primary;
  Color get successColor => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFFA5D6A7)
      : const Color(0xFF1D6D4A);
  Color get successBg => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFF1B3A20)
      : const Color(0xFFE1F4E7);
  Color get warningBg => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFF3A2C0B)
      : const Color(0xFFFFF8E5);
  Color get warningBorder => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFF8A6A1A)
      : const Color(0xFFF1C980);
  Color get warningText => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFFFFE4A3)
      : const Color(0xFF5A3F00);
  Color get errorColor => Theme.of(this).colorScheme.error;
  Color get scoreColor => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFFFFD54F)
      : const Color(0xFF8A5A00);
  Color get actionBlue => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFF0B5AA0)
      : const Color(0xFF063A6B);
}
