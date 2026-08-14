import 'package:flutter/material.dart';

enum PlayerAspectRatio {
  fit('Fit Screen (Best Fit)', BoxFit.contain, Icons.fit_screen_outlined),
  zoom('Zoom (Fill Screen)', BoxFit.cover, Icons.zoom_out_map_outlined),
  stretch('Stretch', BoxFit.fill, Icons.aspect_ratio_outlined),
  sixteenNine('16:9 Widescreen', null, Icons.tv_outlined),
  fourThree('4:3 Standard', null, Icons.crop_portrait_outlined);

  final String label;
  final BoxFit? boxFit;
  final IconData icon;

  const PlayerAspectRatio(this.label, this.boxFit, this.icon);
}

class SubtitleStyleSettings {
  final double fontSize;
  final Color textColor;
  final Color backgroundColor;
  final bool hasBackground;

  const SubtitleStyleSettings({
    this.fontSize = 20.0,
    this.textColor = Colors.white,
    this.backgroundColor = Colors.black54,
    this.hasBackground = true,
  });

  SubtitleStyleSettings copyWith({
    double? fontSize,
    Color? textColor,
    Color? backgroundColor,
    bool? hasBackground,
  }) {
    return SubtitleStyleSettings(
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      hasBackground: hasBackground ?? this.hasBackground,
    );
  }
}
