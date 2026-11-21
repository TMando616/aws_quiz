import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:material_ui/material_ui.dart';

import 'ad_config.dart';
import 'ad_consent.dart';

/// 画面の幅に合わせたバナー広告。
/// 大きさが決まった時点で場所を空けておき、読み込めたら中身を出す（読み込み後に画面の要素が跳ねないように）。
/// 読み込みに失敗したら場所も消す
class BannerAdView extends StatefulWidget {
  const BannerAdView({super.key});

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
  AdSize? _size; // 場所を空けておく大きさ。広告を出さないときは null
  bool _loaded = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面幅（MediaQuery）を使うので、initStateではなくここで読み込む
    if (!_requested && AdConfig.enabled) {
      _requested = true;
      _load();
    }
  }

  Future<void> _load() async {
    // 同意の確認が終わるまで待つ。広告を出せない場合は何もしない
    if (!await AdConsent.ready || !mounted) return;
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    setState(() => _size = size);

    final ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('バナー広告の読み込みに失敗: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _size = null;
            });
          }
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    if (size == null) return const SizedBox.shrink();
    final ad = _ad;
    return SizedBox(
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: ad != null && _loaded ? AdWidget(ad: ad) : null,
    );
  }
}
