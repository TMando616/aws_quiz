
import 'package:material_ui/material_ui.dart';

/// デザインのトークン（DESIGN.md の値をそのままコードにしたもの）
///
/// 画面のコードでは `context.tokens.space4` のように使い、数値やカラーコードを直接書かない。
/// Laravel でいえば、CSS の変数を1か所にまとめた設定ファイルのようなもの。
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.hairline,
    required this.ink,
    required this.onInk,
    required this.marker,
    required this.correct,
    required this.correctSurface,
    required this.danger,
    required this.dangerSurface,
    required this.cardShadow,
  });

  // ---------- カラー ----------
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color hairline;

  /// 主ボタンの塗り（墨）
  final Color ink;
  final Color onInk;

  /// アクセント（マーカーの黄色）。進捗のバーと「ポイント」の下線だけに使い、文字色には使わない
  final Color marker;
  final Color correct;
  final Color correctSurface;
  final Color danger;
  final Color dangerSurface;

  /// 問題のカードの影（ダークでは空）
  final List<BoxShadow> cardShadow;

  // ---------- 余白（4pt スケール） ----------
  double get space1 => 4;
  double get space2 => 8;
  double get space3 => 12;
  double get space4 => 16;
  double get space5 => 24;
  double get space6 => 32;
  double get space7 => 48;

  // ---------- 角丸・枠線 ----------
  double get radiusCard => 20;
  double get radiusControl => 14;
  double get radiusSmall => 8;

  /// 正答率・進捗のバーの太さ
  double get barHeight => 6;

  /// 「ポイント」に引くマーカーの下線の太さ
  double get markerUnderline => 3;

  /// スワイプ表示の選択肢の領域の高さ
  double get swipeChoiceHeight => 160;
  double get borderThin => 1;
  double get borderControl => 1.5;
  double get borderControlSelected => 2;

  /// タップの的の最小の高さ（揺れる電車の中でも押しやすいように）
  double get tapTarget => 52;

  // ---------- モーション ----------
  Duration get answerFeedback => const Duration(milliseconds: 180);
  Duration get cardFlip => const Duration(milliseconds: 220);

  /// カードをめくるときに横にずらす量（画面の幅に対する割合）
  double get cardFlipShift => 0.12;

  // ---------- 文字 ----------
  static const _tabular = [FontFeature.tabularFigures()];

  /// 正答率などの結果の数字
  TextStyle get display => TextStyle(
    fontSize: 44,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    fontFeatures: _tabular,
  );

  /// 画面の見出し（試験名など）
  TextStyle get title => TextStyle(
    fontSize: 22,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  /// 問題文（カードの中）
  TextStyle get question => TextStyle(
    fontSize: 18,
    height: 1.75,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  /// 解説・選択肢
  TextStyle get body => TextStyle(
    fontSize: 15,
    height: 1.7,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  /// セクション名・分野名などの短いラベル
  TextStyle get label => TextStyle(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: textSecondary,
  );

  /// 補足（問題数・比重など）。数字は等幅
  TextStyle get caption => TextStyle(
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    fontFeatures: _tabular,
  );

  /// 等幅の数字にしたいときに、ほかのスタイルに重ねる
  TextStyle numeric(TextStyle base) => base.copyWith(fontFeatures: _tabular);

  static const light = AppTokens(
    background: Color(0xFFF3F4F6),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE9EBEE),
    textPrimary: Color(0xFF16191D),
    textSecondary: Color(0xFF565E69),
    hairline: Color(0xFFD8DCE1),
    ink: Color(0xFF16191D),
    onInk: Color(0xFFFFFFFF),
    marker: Color(0xFFF5C518),
    correct: Color(0xFF1C7A3E),
    correctSurface: Color(0xFFE2F3E7),
    danger: Color(0xFFC02626),
    dangerSurface: Color(0xFFFBE3E3),
    cardShadow: [
      BoxShadow(color: Color(0x14000000), offset: Offset(0, 6), blurRadius: 20),
    ],
  );

  static const dark = AppTokens(
    background: Color(0xFF111315),
    surface: Color(0xFF1B1E22),
    surfaceMuted: Color(0xFF24282D),
    textPrimary: Color(0xFFECEEF1),
    textSecondary: Color(0xFFA9B0B9),
    hairline: Color(0xFF33383E),
    ink: Color(0xFFECEEF1),
    onInk: Color(0xFF111315),
    marker: Color(0xFFE3B514),
    correct: Color(0xFF7FD69C),
    correctSurface: Color(0xFF1D3A28),
    danger: Color(0xFFF28B8B),
    dangerSurface: Color(0xFF45201F),
    cardShadow: [],
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) =>
      t < 0.5 ? this : (other as AppTokens? ?? this);
}

extension AppTokensContext on BuildContext {
  /// 今のテーマのトークン。テーマに入っていないとき（テストなど）は明るさに合わせた既定値
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ??
        (theme.brightness == Brightness.dark ? AppTokens.dark : AppTokens.light);
  }
}
