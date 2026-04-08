import 'package:flutter/material.dart';

/// Utilitário para tornar a app responsiva em diferentes dispositivos
class ResponsiveUtils {
  /// Retorna o tamanho da tela
  static Size getScreenSize(BuildContext context) {
    return MediaQuery.of(context).size;
  }

  /// Retorna a largura da tela
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Retorna a altura da tela
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Retorna true se for um dispositivo pequeno (< 360dp)
  static bool isSmallDevice(BuildContext context) {
    return getScreenWidth(context) < 360;
  }

  /// Retorna true se for um dispositivo médio (360-400dp)
  static bool isMediumDevice(BuildContext context) {
    final width = getScreenWidth(context);
    return width >= 360 && width < 400;
  }

  /// Retorna true se for um dispositivo grande (>= 400dp)
  static bool isLargeDevice(BuildContext context) {
    return getScreenWidth(context) >= 400;
  }

  /// Calcula um tamanho de fonte responsivo baseado na largura da tela
  /// baseFontSize: tamanho base para dispositivo médio (375dp)
  static double responsiveFontSize(BuildContext context, double baseFontSize) {
    final width = getScreenWidth(context);
    const baseWidth = 375.0; // Largura base (iPhone 11)
    final scale = width / baseWidth;

    // Limitar escala entre 0.85 e 1.15 para não ficar muito pequeno ou grande
    final clampedScale = scale.clamp(0.85, 1.15);

    return baseFontSize * clampedScale;
  }

  /// Calcula um padding responsivo
  static double responsivePadding(BuildContext context, double basePadding) {
    if (isSmallDevice(context)) {
      return basePadding * 0.8;
    } else if (isLargeDevice(context)) {
      return basePadding * 1.1;
    }
    return basePadding;
  }

  /// Calcula uma altura responsiva
  static double responsiveHeight(BuildContext context, double baseHeight) {
    final height = getScreenHeight(context);
    const baseScreenHeight = 812.0; // Altura base (iPhone 11)
    final scale = height / baseScreenHeight;

    return baseHeight * scale.clamp(0.85, 1.15);
  }

  /// Retorna o fator de escala de texto do sistema
  static double getTextScaleFactor(BuildContext context) {
    return MediaQuery.of(context).textScaleFactor;
  }

  /// Limita o fator de escala de texto para evitar overflow
  /// maxScale: máximo permitido (ex: 1.3 = 130%)
  static double clampedTextScaleFactor(BuildContext context, {double maxScale = 1.3}) {
    final scale = getTextScaleFactor(context);
    return scale.clamp(1.0, maxScale);
  }

  /// Wrapper para texto que limita a escala automaticamente
  static Widget scalableText(
      String text, {
        required TextStyle style,
        double maxScale = 1.3,
        TextAlign? textAlign,
        int? maxLines,
        TextOverflow? overflow,
      }) {
    return Builder(
      builder: (context) {
        final scale = clampedTextScaleFactor(context, maxScale: maxScale);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: Text(
            text,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          ),
        );
      },
    );
  }
}

/// Extension para facilitar acesso aos utilitários
extension ResponsiveContext on BuildContext {
  double get screenWidth => ResponsiveUtils.getScreenWidth(this);
  double get screenHeight => ResponsiveUtils.getScreenHeight(this);
  bool get isSmallDevice => ResponsiveUtils.isSmallDevice(this);
  bool get isMediumDevice => ResponsiveUtils.isMediumDevice(this);
  bool get isLargeDevice => ResponsiveUtils.isLargeDevice(this);

  double responsiveFontSize(double baseFontSize) =>
      ResponsiveUtils.responsiveFontSize(this, baseFontSize);

  double responsivePadding(double basePadding) =>
      ResponsiveUtils.responsivePadding(this, basePadding);

  double responsiveHeight(double baseHeight) =>
      ResponsiveUtils.responsiveHeight(this, baseHeight);
}
