import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:material_ui/material_ui.dart';

import 'ad_config.dart';
import 'ad_consent.dart';

/// 全画面広告の読み込みと表示を担当する（Laravelでいうサービスクラス）
///
/// 全画面広告は表示する直前に読み込むと待たされるので、先に読み込んでおき、
/// 表示し終わったら次の分を読み込む。
class InterstitialAdManager {
  InterstitialAd? _ad;

  /// 画面を閉じたあとか。閉じたあとに読み込みが終わった広告は、保持せずにすぐ破棄する
  bool _disposed = false;

  Future<void> load() async {
    if (!AdConfig.enabled || _disposed) return;
    // 同意の確認が終わるまで待つ。広告を出せない場合は何もしない
    if (!await AdConsent.ready) return;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _ad = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('全画面広告の読み込みに失敗: $error');
          _ad = null;
        },
      ),
    );
  }

  /// 広告を表示し、閉じられたら [onDone] を呼ぶ。
  /// 読み込めていなければ広告は出さず、すぐに [onDone] を呼ぶ。
  void show({required VoidCallback onDone}) {
    final ad = _ad;
    if (ad == null) {
      onDone();
      return;
    }
    _ad = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        load();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('全画面広告の表示に失敗: $error');
        ad.dispose();
        load();
        onDone();
      },
    );
    ad.show();
  }

  void dispose() {
    _disposed = true;
    _ad?.dispose();
    _ad = null;
  }
}
