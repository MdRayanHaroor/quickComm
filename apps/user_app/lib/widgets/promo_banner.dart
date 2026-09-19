import 'package:flutter/material.dart';
import 'ad_banner.dart';

export 'ad_banner.dart';

/// Clickable promotional banner / ad space (replaces old auto-sliding slider)
class PromoBanner extends StatelessWidget {
  final VoidCallback? onAdTap;

  const PromoBanner({super.key, this.onAdTap});

  @override
  Widget build(BuildContext context) {
    return AdBanner(onAdTap: onAdTap);
  }
}
