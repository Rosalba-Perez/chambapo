import 'package:flutter/material.dart';

// Colores que usa la app
abstract final class CP {
  static const verde = Color(0xFF0E5C5A);
  static const verdeOscuro = Color(0xFF093F3E);
  static const naranja = Color(0xFFC4471A);
  static const naranjaLogo = Color(0xFFE8662F);
  static const naranjaSuave = Color(0xFFF28B54);
  static const tinta = Color(0xFF13201C);
  static const texto2 = Color(0xFF3F4B47);
  static const apagado = Color(0xFF55625D);
  static const borde = Color(0xFFD5DDD9);
  static const fondoCampo = Color(0xFFF6F8F6);
  static const fondoApp = Color(0xFFF3F5F2);
  static const error = Color(0xFFB42318);
  static const errorFondo = Color(0xFFFEF0EE);
  static const advertencia = Color(0xFF8A5300);
  static const advertenciaFondo = Color(0xFFFDF3E1);
  static const exito = Color(0xFF2E9C7E);
  static const seleccion = Color(0xFFE6F1EF);
  static const desactivado = Color(0xFFE1E6E3);
  static const desactivadoTexto = Color(0xFF8E9994);
}

// Estilo de letra para los títulos
const estiloTitulo = TextStyle(fontFamily: 'Bricolage Grotesque', fontWeight: FontWeight.w800, color: CP.tinta, height: 1.1);

ThemeData temaChambapo() {
  final esquema = ColorScheme.fromSeed(seedColor: CP.verde).copyWith(
    primary: CP.verde, onPrimary: Colors.white,
    primaryContainer: CP.seleccion, onPrimaryContainer: CP.verde,
    secondary: CP.naranja, onSecondary: Colors.white,
    error: CP.error, onError: Colors.white, errorContainer: CP.errorFondo, onErrorContainer: CP.error,
    surface: Colors.white, onSurface: CP.tinta, onSurfaceVariant: CP.texto2,
    surfaceContainerHighest: CP.fondoApp, surfaceContainerHigh: CP.fondoApp, surfaceContainer: CP.fondoApp,
    outline: CP.borde, outlineVariant: CP.borde,
  );
  final radio14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const textoBoton = TextStyle(fontFamily: 'Figtree', fontSize: 16, fontWeight: FontWeight.w700);
  OutlineInputBorder bordeCampo(Color c, [double ancho = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: ancho));

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    fontFamily: 'Figtree',
    scaffoldBackgroundColor: Colors.white,
    textTheme: TextTheme(
      headlineMedium: estiloTitulo.copyWith(fontSize: 28),
      headlineSmall: estiloTitulo.copyWith(fontSize: 22),
      titleLarge: estiloTitulo.copyWith(fontSize: 20),
      titleMedium: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CP.tinta),
      titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CP.tinta),
      bodyLarge: const TextStyle(fontSize: 15, height: 1.4, color: CP.tinta),
      bodyMedium: const TextStyle(fontSize: 14, height: 1.4, color: CP.texto2),
      bodySmall: const TextStyle(fontSize: 12, height: 1.35, color: CP.apagado),
      labelLarge: textoBoton,
      labelMedium: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CP.apagado),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white, foregroundColor: CP.tinta, elevation: 0, scrolledUnderElevation: 0,
      centerTitle: false, titleTextStyle: estiloTitulo.copyWith(fontSize: 20),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: CP.naranja, foregroundColor: Colors.white,
      disabledBackgroundColor: CP.desactivado, disabledForegroundColor: CP.desactivadoTexto,
      minimumSize: const Size(64, 54), shape: radio14, textStyle: textoBoton,
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: CP.verde, side: const BorderSide(color: CP.verde, width: 1.5),
      minimumSize: const Size(64, 54), shape: radio14, textStyle: textoBoton,
    )),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
      foregroundColor: CP.verde, minimumSize: const Size(44, 44),
      textStyle: const TextStyle(fontFamily: 'Figtree', fontSize: 14, fontWeight: FontWeight.w700),
    )),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: CP.fondoCampo,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: CP.apagado, fontSize: 14),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((s) => TextStyle(
          color: s.contains(WidgetState.error) ? CP.error : CP.verde, fontWeight: FontWeight.w600)),
      hintStyle: const TextStyle(color: CP.apagado),
      helperStyle: const TextStyle(color: CP.apagado, fontSize: 12),
      errorStyle: const TextStyle(color: CP.error, fontSize: 12, fontWeight: FontWeight.w600),
      prefixIconColor: WidgetStateColor.resolveWith((s) =>
          s.contains(WidgetState.error) ? CP.error : s.contains(WidgetState.focused) ? CP.verde : CP.apagado),
      border: bordeCampo(CP.borde),
      enabledBorder: bordeCampo(CP.borde),
      focusedBorder: bordeCampo(CP.verde, 2),
      errorBorder: bordeCampo(CP.error, 1.5),
      focusedErrorBorder: bordeCampo(CP.error, 2),
      disabledBorder: bordeCampo(CP.borde),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Colors.white, selectedColor: CP.verde, disabledColor: CP.fondoApp,
      side: BorderSide(color: CP.borde), shape: StadiumBorder(),
      labelStyle: TextStyle(fontFamily: 'Figtree', fontSize: 13, fontWeight: FontWeight.w600, color: CP.tinta),
      secondaryLabelStyle: TextStyle(fontFamily: 'Figtree', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
      checkmarkColor: Colors.white,
      showCheckmark: false, padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    ),
    cardTheme: CardThemeData(
      color: Colors.white, surfaceTintColor: Colors.transparent, elevation: 0, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: CP.borde)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CP.tinta, contentTextStyle: const TextStyle(fontFamily: 'Figtree', color: Colors.white, fontSize: 14),
      actionTextColor: CP.naranjaSuave, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, indicatorColor: Colors.transparent,
      height: 68, elevation: 0,
      labelTextStyle: WidgetStateTextStyle.resolveWith((s) => TextStyle(fontFamily: 'Figtree', fontSize: 12,
          fontWeight: FontWeight.w700, color: s.contains(WidgetState.selected) ? CP.naranja : CP.apagado)),
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? CP.naranja : CP.apagado)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? CP.exito : CP.borde),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? CP.verde : Colors.white),
      side: const BorderSide(color: CP.borde, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? CP.verde : CP.apagado)),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: estiloTitulo.copyWith(fontSize: 22),
      contentTextStyle: const TextStyle(fontFamily: 'Figtree', fontSize: 15, height: 1.4, color: CP.texto2),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dividerTheme: const DividerThemeData(color: CP.borde, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: CP.verde),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: CP.naranja, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
