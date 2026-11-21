import 'package:material_ui/material_ui.dart';

/// アプリ全体の見た目をまとめる（LaravelでいえばCSSの変数や共通スタイル）
///
/// - 白基調でミニマル、角丸のカード、アクセントカラーはティール1色
/// - AWSのオレンジと紺は、公式アプリと誤解されやすいので使わない
/// - 長文の問題文が読みやすいことを最優先に、本文の文字サイズと行間を広めにする
class AppTheme {
  AppTheme._();

  static const _accent = Color(0xFF0F8B8D); // ティール

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: brightness,
      // 背景はほぼ白（ダークではほぼ黒）にして、色はアクセントだけに絞る
      surface: isDark ? const Color(0xFF121414) : Colors.white,
    );

    final base = ThemeData(colorScheme: scheme, brightness: brightness);
    final text = base.textTheme;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        // 問題文・解説（長文）
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 1.7),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.65),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }

  /// 正解・不正解の色。ダークモードでも読めるように明るさを変える
  static Color correctBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1F3D2B)
      : const Color(0xFFE3F4E8);

  static Color wrongBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF4A2326)
      : const Color(0xFFFBE4E4);

  static Color correctForeground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF7DD69B)
      : const Color(0xFF1E7B3C);

  static Color wrongForeground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFF08A8A)
      : const Color(0xFFC62828);
}
