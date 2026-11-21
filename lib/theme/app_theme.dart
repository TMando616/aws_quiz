import 'package:material_ui/material_ui.dart';

import 'app_tokens.dart';

/// アプリ全体のテーマ。値はすべて DESIGN.md のトークン（[AppTokens]）から作る
///
/// - コンセプトは「通勤電車で開く単語帳」。色は墨が基本で、アクセントはマーカーの黄色を少量
/// - シードカラーからの自動生成はせず、ColorScheme を固定の値で組む（配色が平均的にならないように）
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppTokens.light, Brightness.light);
  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.ink,
      onPrimary: t.onInk,
      secondary: t.ink,
      onSecondary: t.onInk,
      error: t.danger,
      onError: t.surface,
      surface: t.surface,
      onSurface: t.textPrimary,
      onSurfaceVariant: t.textSecondary,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.background,
      surfaceContainerHigh: t.surfaceMuted,
      surfaceContainerHighest: t.surfaceMuted,
      outline: t.textSecondary,
      outlineVariant: t.hairline,
      primaryContainer: t.surfaceMuted,
      onPrimaryContainer: t.textPrimary,
    );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: t.background,
      extensions: [t],
    );
    final text = base.textTheme;

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(t.radiusControl),
    );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineSmall: t.title,
        titleLarge: t.title,
        bodyLarge: t.question,
        bodyMedium: t.body,
        labelLarge: t.label.copyWith(color: t.textPrimary),
        labelMedium: t.label,
        bodySmall: t.caption,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: t.numeric(t.label.copyWith(
          fontSize: 15,
          color: t.textPrimary,
        )),
      ),
      // カードは問題のカード専用の見た目にするので、Card は線だけの控えめなものにする
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusControl),
          side: BorderSide(color: t.hairline, width: t.borderThin),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.ink,
          foregroundColor: t.onInk,
          disabledBackgroundColor: t.surfaceMuted,
          disabledForegroundColor: t.textSecondary,
          minimumSize: Size.fromHeight(t.tapTarget),
          shape: controlShape,
          textStyle: t.label.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          minimumSize: Size.fromHeight(t.tapTarget),
          side: BorderSide(color: t.hairline, width: t.borderControl),
          shape: controlShape,
          textStyle: t.label.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.textPrimary,
          textStyle: t.label,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.marker,
        linearTrackColor: t.surfaceMuted,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onInk : t.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.ink : t.surfaceMuted,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.textPrimary,
        unselectedLabelColor: t.textSecondary,
        indicatorColor: t.ink,
        dividerColor: t.hairline,
        labelStyle: t.label.copyWith(fontSize: 15),
      ),
      dividerTheme: DividerThemeData(
        color: t.hairline,
        thickness: t.borderThin,
        space: t.borderThin,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.ink,
        contentTextStyle: t.body.copyWith(color: t.onInk),
      ),
    );
  }

  // 正誤の色（既存のコードとの互換のために残す。中身はトークン）
  static Color correctBackground(BuildContext context) =>
      context.tokens.correctSurface;
  static Color wrongBackground(BuildContext context) =>
      context.tokens.dangerSurface;
  static Color correctForeground(BuildContext context) => context.tokens.correct;
  static Color wrongForeground(BuildContext context) => context.tokens.danger;
}
