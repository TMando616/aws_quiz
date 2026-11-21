import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:material_ui/material_ui.dart';

import 'ad_config.dart';

/// 広告を出す前の同意まわりをまとめたもの
///
/// アプリ起動時に [gather] を1回呼ぶと、次の順で進む。
/// 1. UMP（GoogleのUser Messaging Platform）で、EU・イギリスなど同意が必要な地域の人にだけ同意画面を出す
/// 2. iOSでは、トラッキング許可（ATT）のダイアログを出す
/// 3. 広告SDKを初期化する
///
/// 広告を読み込む側は [ready] を待ってから読み込む。
/// （同意を取る前に広告をリクエストすると規約違反になるため）
class AdConsent {
  AdConsent._();

  static final _ready = Completer<bool>();

  /// 広告をリクエストしてよければtrue。同意の確認が終わるまで待つ
  static Future<bool> get ready => _ready.future;

  static Future<void> gather() async {
    if (_ready.isCompleted) return;
    if (!AdConfig.enabled) {
      _ready.complete(false);
      return;
    }

    try {
      // 1. 同意が必要な地域かどうかを確認し、必要なら同意画面を出す
      final updated = await _requestConsentInfoUpdate();
      if (updated) {
        final error = await _loadAndShowConsentFormIfRequired();
        if (error != null) debugPrint('同意画面の表示に失敗: ${error.message}');
      }

      // 2. iOSのトラッキング許可。まだ聞いていない人にだけダイアログを出す
      if (Platform.isIOS) {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          // 起動直後だとダイアログが出ないことがあるので、少し待つ
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      }

      // 3. 同意の結果、広告を出してよければSDKを初期化する
      // （確認に失敗しても、前回の起動で同意済みならtrueになる）
      final canRequest = await ConsentInformation.instance.canRequestAds();
      if (canRequest) await MobileAds.instance.initialize();
      _ready.complete(canRequest);
    } catch (e) {
      debugPrint('広告の同意確認でエラー: $e');
      if (!_ready.isCompleted) _ready.complete(false);
    }
  }

  /// 「広告のプライバシー設定」をメニューに出す必要があるか（同意が必要な地域の人だけtrue）
  static Future<bool> isPrivacyOptionsRequired() async {
    if (!AdConfig.enabled) return false;
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  /// 同意の内容を変更する画面を出す
  static Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('プライバシー設定の表示に失敗: ${error.message}');
    });
  }

  // UMPのAPIはコールバック形式なので、awaitで書けるようにFutureに包む

  static Future<bool> _requestConsentInfoUpdate() {
    final completer = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => completer.complete(true),
      (error) {
        debugPrint('同意情報の取得に失敗: ${error.message}');
        completer.complete(false);
      },
    );
    return completer.future;
  }

  static Future<FormError?> _loadAndShowConsentFormIfRequired() {
    final completer = Completer<FormError?>();
    ConsentForm.loadAndShowConsentFormIfRequired(completer.complete);
    return completer.future;
  }
}
