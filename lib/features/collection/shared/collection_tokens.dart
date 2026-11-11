import 'package:flutter/material.dart';

import 'collection_colors.dart';

/// 보관함 화면 전용 색 토큰.
///
/// `HomeTokens`와 같은 꼴이다. 값 자체는 [CollectionColors]에 있고 여기서는
/// 밝기에 맞는 쪽을 골라 준다. 쓰는 쪽은 `context.collectionTokens.mint`처럼
/// 꺼내 쓰고 밝기 분기를 적지 않는다.
@immutable
class CollectionTokens extends ThemeExtension<CollectionTokens> {
  const CollectionTokens({
    required this.mint,
    required this.sky,
    required this.cream,
    required this.mintInk,
    required this.skyInk,
    required this.creamInk,
    required this.tintLabel,
    required this.tintSurface,
    required this.liked,
    required this.voiceActive,
    required this.goldBackground,
    required this.goldBorder,
  });

  /// 문장 탭과 일상 표현 팩의 파스텔 배경.
  final Color mint;

  /// 클립 탭과 여행 표현 팩의 파스텔 배경.
  final Color sky;

  /// 단어 탭과 카페 표현 팩의 파스텔 배경.
  final Color cream;

  /// mint 배경 위의 아이콘과 제목.
  final Color mintInk;

  /// sky 배경 위의 아이콘과 제목.
  final Color skyInk;

  /// cream 배경 위의 아이콘과 제목.
  final Color creamInk;

  /// 파스텔 배경 위의 설명 글자. 세 색조 공통으로 쓴다.
  final Color tintLabel;

  /// 파스텔 배경 위에 얹는 동그라미 같은 작은 면.
  final Color tintSurface;

  /// 좋아요를 누른 하트.
  final Color liked;

  /// 앵무새에게 보내기가 켜진 상태의 아이콘.
  final Color voiceActive;

  /// 친밀도 최고 단계 카드의 배경 그라디언트.
  final List<Color> goldBackground;

  /// 친밀도 최고 단계 카드의 테두리 그라디언트.
  final List<Color> goldBorder;

  static const light = CollectionTokens(
    mint: CollectionColors.mint,
    sky: CollectionColors.sky,
    cream: CollectionColors.cream,
    mintInk: CollectionColors.tabIcon,
    skyInk: CollectionColors.packIcon,
    creamInk: CollectionColors.creamIcon,
    tintLabel: CollectionColors.packLabel,
    tintSurface: Color(0xFFFFFFFF),
    liked: CollectionColors.liked,
    voiceActive: CollectionColors.voiceActive,
    goldBackground: CollectionColors.goldBackground,
    goldBorder: CollectionColors.goldBorder,
  );

  static const dark = CollectionTokens(
    mint: CollectionColors.mintDark,
    sky: CollectionColors.skyDark,
    cream: CollectionColors.creamDark,
    mintInk: CollectionColors.tabIconDark,
    skyInk: CollectionColors.packIconDark,
    creamInk: CollectionColors.creamIconDark,
    tintLabel: CollectionColors.packLabelDark,
    tintSurface: Color(0xFF2A3038),
    liked: CollectionColors.likedDark,
    voiceActive: CollectionColors.voiceActiveDark,
    goldBackground: CollectionColors.goldBackgroundDark,
    goldBorder: CollectionColors.goldBorderDark,
  );

  /// 테마에 등록된 보관함 토큰. 없으면 밝기에 맞는 기본값으로 떨어진다.
  static CollectionTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<CollectionTokens>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  CollectionTokens copyWith({
    Color? mint,
    Color? sky,
    Color? cream,
    Color? mintInk,
    Color? skyInk,
    Color? creamInk,
    Color? tintLabel,
    Color? tintSurface,
    Color? liked,
    Color? voiceActive,
    List<Color>? goldBackground,
    List<Color>? goldBorder,
  }) =>
      CollectionTokens(
        mint: mint ?? this.mint,
        sky: sky ?? this.sky,
        cream: cream ?? this.cream,
        mintInk: mintInk ?? this.mintInk,
        skyInk: skyInk ?? this.skyInk,
        creamInk: creamInk ?? this.creamInk,
        tintLabel: tintLabel ?? this.tintLabel,
        tintSurface: tintSurface ?? this.tintSurface,
        liked: liked ?? this.liked,
        voiceActive: voiceActive ?? this.voiceActive,
        goldBackground: goldBackground ?? this.goldBackground,
        goldBorder: goldBorder ?? this.goldBorder,
      );

  @override
  CollectionTokens lerp(ThemeExtension<CollectionTokens>? other, double t) {
    if (other is! CollectionTokens) return this;
    return CollectionTokens(
      mint: Color.lerp(mint, other.mint, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      mintInk: Color.lerp(mintInk, other.mintInk, t)!,
      skyInk: Color.lerp(skyInk, other.skyInk, t)!,
      creamInk: Color.lerp(creamInk, other.creamInk, t)!,
      tintLabel: Color.lerp(tintLabel, other.tintLabel, t)!,
      tintSurface: Color.lerp(tintSurface, other.tintSurface, t)!,
      liked: Color.lerp(liked, other.liked, t)!,
      voiceActive: Color.lerp(voiceActive, other.voiceActive, t)!,
      goldBackground: _lerpList(goldBackground, other.goldBackground, t),
      goldBorder: _lerpList(goldBorder, other.goldBorder, t),
    );
  }

  static List<Color> _lerpList(List<Color> a, List<Color> b, double t) => [
        for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
      ];
}

/// 보관함 토큰을 context에서 바로 꺼내는 창구.
extension CollectionTokensContext on BuildContext {
  /// 보관함 화면 전용 색 토큰.
  CollectionTokens get collectionTokens => CollectionTokens.of(this);
}
