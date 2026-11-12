import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_shadows.dart';

/// 앱 전역 색 토큰. 밝기에 맞는 값을 context에서 바로 꺼내 쓴다.
///
/// 값은 모두 [AppColors]에서 가져오므로 색의 출처는 여전히 한 곳이고,
/// 화면에서는 `AppTokens.of(context).textSecondary` 처럼 밝기 분기 없이 쓴다.
/// [AppTheme]이 라이트/다크 테마에 등록한다.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.isDark,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.divider,
    required this.dividerSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.primary,
    required this.primaryPressed,
    required this.primarySoft,
    required this.primarySubtle,
    required this.secondary,
    required this.secondarySoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.link,
    required this.disabled,
    required this.disabledForeground,
    required this.skeleton,
    required this.skeletonHighlight,
    required this.overlay,
    required this.overlayLight,
  });

  /// 다크 모드인지. 그림자처럼 밝기에 따라 값을 고르는 곳에서 쓴다.
  final bool isDark;

  /// 기본 배경.
  final Color surface;

  /// 카드와 컨테이너 배경.
  final Color surfaceContainer;

  /// 한 단계 더 올라온 컨테이너 배경.
  final Color surfaceContainerHigh;

  /// 구분선.
  final Color divider;

  /// 얇은 구분선.
  final Color dividerSubtle;

  /// 입력창·외곽선 버튼의 또렷한 테두리
  final Color borderStrong;

  /// 본문 글자.
  final Color textPrimary;

  /// 보조 글자.
  final Color textSecondary;

  /// 힌트 글자.
  final Color textTertiary;

  /// 비활성 글자.
  final Color textDisabled;

  /// 주요 강조색.
  final Color primary;

  /// 주요 강조색 눌림.
  final Color primaryPressed;

  /// 주요 강조색을 옅게 채운 배경.
  final Color primarySoft;

  /// primarySoft보다 더 옅은 배경.
  final Color primarySubtle;

  /// 보조 강조색.
  final Color secondary;

  /// 보조 강조색을 옅게 채운 배경.
  final Color secondarySoft;

  /// 성공.
  final Color success;

  /// 성공 배경.
  final Color successSoft;

  /// 경고.
  final Color warning;

  /// 경고 배경.
  final Color warningSoft;

  /// 위험.
  final Color danger;

  /// 위험 배경.
  final Color dangerSoft;

  /// 정보.
  final Color info;

  /// 정보 배경.
  final Color infoSoft;

  /// 링크.
  final Color link;

  /// 비활성 배경.
  final Color disabled;

  /// 비활성 전경.
  final Color disabledForeground;

  /// 스켈레톤 배경.
  final Color skeleton;

  /// 스켈레톤 하이라이트.
  final Color skeletonHighlight;

  /// 화면을 덮는 오버레이.
  final Color overlay;

  /// 옅은 오버레이.
  final Color overlayLight;

  static const light = AppTokens(
    isDark: false,
    surface: AppColors.surface,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    divider: AppColors.divider,
    dividerSubtle: AppColors.dividerSubtle,
    borderStrong: AppColors.borderStrong,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    textDisabled: AppColors.textDisabled,
    primary: AppColors.primary,
    primaryPressed: AppColors.primaryPressed,
    primarySoft: AppColors.primarySoft,
    primarySubtle: AppColors.primarySubtle,
    secondary: AppColors.secondary,
    secondarySoft: AppColors.secondarySoft,
    success: AppColors.success,
    successSoft: AppColors.successSoft,
    warning: AppColors.warning,
    warningSoft: AppColors.warningSoft,
    danger: AppColors.danger,
    dangerSoft: AppColors.dangerSoft,
    info: AppColors.info,
    infoSoft: AppColors.infoSoft,
    link: AppColors.link,
    disabled: AppColors.disabled,
    disabledForeground: AppColors.disabledForeground,
    skeleton: AppColors.skeleton,
    skeletonHighlight: AppColors.skeletonHighlight,
    overlay: AppColors.overlay,
    overlayLight: AppColors.overlayLight,
  );

  static const dark = AppTokens(
    isDark: true,
    surface: AppColors.surfaceDark,
    surfaceContainer: AppColors.surfaceContainerDark,
    surfaceContainerHigh: AppColors.surfaceContainerHighDark,
    divider: AppColors.dividerDark,
    dividerSubtle: AppColors.dividerSubtleDark,
    borderStrong: AppColors.borderStrongDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    textDisabled: AppColors.textDisabledDark,
    primary: AppColors.primaryDark,
    primaryPressed: AppColors.primaryPressedDark,
    primarySoft: AppColors.primarySoftDark,
    primarySubtle: AppColors.primarySubtleDark,
    secondary: AppColors.secondaryDark,
    secondarySoft: AppColors.secondarySoftDark,
    success: AppColors.successDark,
    successSoft: AppColors.successSoftDark,
    warning: AppColors.warningDark,
    warningSoft: AppColors.warningSoftDark,
    danger: AppColors.dangerDark,
    dangerSoft: AppColors.dangerSoftDark,
    info: AppColors.infoDark,
    infoSoft: AppColors.infoSoftDark,
    link: AppColors.linkDark,
    disabled: AppColors.disabledDark,
    disabledForeground: AppColors.disabledForegroundDark,
    skeleton: AppColors.skeletonDark,
    skeletonHighlight: AppColors.skeletonHighlightDark,
    overlay: AppColors.overlayDark,
    overlayLight: AppColors.overlayLightDark,
  );

  /// 테마에 등록된 토큰. 등록 전이거나 테마를 통째로 바꾼 곳에서도
  /// 밝기에 맞는 기본값으로 떨어지므로 null 검사가 필요 없다.
  static AppTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppTokens>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// 카드 그림자.
  List<BoxShadow> get shadowCard => AppShadows.card(isDark);

  /// 팝업과 드롭다운 그림자.
  List<BoxShadow> get shadowPopup => AppShadows.popup(isDark);

  /// 다이얼로그 그림자.
  List<BoxShadow> get shadowDialog => AppShadows.dialog(isDark);

  /// 바텀시트 그림자.
  List<BoxShadow> get shadowBottomSheet => AppShadows.bottomSheet(isDark);

  @override
  AppTokens copyWith({
    bool? isDark,
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? divider,
    Color? dividerSubtle,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? primary,
    Color? primaryPressed,
    Color? primarySoft,
    Color? primarySubtle,
    Color? secondary,
    Color? secondarySoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? link,
    Color? disabled,
    Color? disabledForeground,
    Color? skeleton,
    Color? skeletonHighlight,
    Color? overlay,
    Color? overlayLight,
  }) =>
      AppTokens(
        isDark: isDark ?? this.isDark,
        surface: surface ?? this.surface,
        surfaceContainer: surfaceContainer ?? this.surfaceContainer,
        surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
        divider: divider ?? this.divider,
        dividerSubtle: dividerSubtle ?? this.dividerSubtle,
        borderStrong: borderStrong ?? this.borderStrong,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        textDisabled: textDisabled ?? this.textDisabled,
        primary: primary ?? this.primary,
        primaryPressed: primaryPressed ?? this.primaryPressed,
        primarySoft: primarySoft ?? this.primarySoft,
        primarySubtle: primarySubtle ?? this.primarySubtle,
        secondary: secondary ?? this.secondary,
        secondarySoft: secondarySoft ?? this.secondarySoft,
        success: success ?? this.success,
        successSoft: successSoft ?? this.successSoft,
        warning: warning ?? this.warning,
        warningSoft: warningSoft ?? this.warningSoft,
        danger: danger ?? this.danger,
        dangerSoft: dangerSoft ?? this.dangerSoft,
        info: info ?? this.info,
        infoSoft: infoSoft ?? this.infoSoft,
        link: link ?? this.link,
        disabled: disabled ?? this.disabled,
        disabledForeground: disabledForeground ?? this.disabledForeground,
        skeleton: skeleton ?? this.skeleton,
        skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
        overlay: overlay ?? this.overlay,
        overlayLight: overlayLight ?? this.overlayLight,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceContainer:
          Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceContainerHigh:
          Color.lerp(surfaceContainerHigh, other.surfaceContainerHigh, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dividerSubtle: Color.lerp(dividerSubtle, other.dividerSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primarySubtle: Color.lerp(primarySubtle, other.primarySubtle, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondarySoft: Color.lerp(secondarySoft, other.secondarySoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      link: Color.lerp(link, other.link, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      disabledForeground:
          Color.lerp(disabledForeground, other.disabledForeground, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
      skeletonHighlight:
          Color.lerp(skeletonHighlight, other.skeletonHighlight, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      overlayLight: Color.lerp(overlayLight, other.overlayLight, t)!,
    );
  }
}

/// 홈(앵무새 무대, 연습 기록, 학습 허브)에서만 쓰는 색 토큰.
///
/// 이 화면들은 앱 공통 색과 다른 부드러운 하늘색 계열을 쓴다.
/// 라이트 값은 화면마다 직접 적어뒀던 값을 그대로 옮긴 것이다.
@immutable
class HomeTokens extends ThemeExtension<HomeTokens> {
  const HomeTokens({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSoft,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.primary,
    required this.border,
    required this.good,
    required this.goodSoft,
    required this.shadow,
    required this.like,
    required this.likeSoft,
    required this.likeInk,
    required this.garden,
    required this.mastery,
    required this.groundOuter,
    required this.groundInner,
  });

  /// 화면 배경.
  final Color background;

  /// 카드 배경.
  final Color surface;

  /// 옅게 채운 카드나 칩 배경.
  final Color surfaceAlt;

  /// surfaceAlt보다 더 옅은 영역 배경.
  final Color surfaceSoft;

  /// 본문 글자.
  final Color ink;

  /// 본문보다 조금 연한 글자.
  final Color inkSoft;

  /// 설명과 보조 글자.
  final Color muted;

  /// 주요 버튼 배경.
  final Color accent;

  /// 주요 버튼 글자.
  final Color onAccent;

  /// 강조 아이콘과 링크.
  final Color primary;

  /// 테두리와 구분선.
  final Color border;

  /// 목표 달성처럼 좋은 상태.
  final Color good;

  /// good을 옅게 채운 배경.
  final Color goodSoft;

  /// 카드 그림자 색(투명도는 쓰는 쪽에서 정한다).
  final Color shadow;

  /// 좋아요와 인기 표시.
  final Color like;

  /// like를 옅게 채운 배경.
  final Color likeSoft;

  /// likeSoft 배경 위에 쓰는 글자.
  final Color likeInk;

  /// 학습 잔디 단계 색. 0단계(안 함)부터 4단계(목표 초과)까지.
  final List<Color> garden;

  /// 문장 친밀도 단계 색. 처음, 익히는 중, 익숙함 순서.
  final List<Color> mastery;

  /// 둥지 그림 아래 바닥 그림자의 바깥 타원.
  final Color groundOuter;

  /// 바닥 그림자의 안쪽 타원. 바깥보다 밝다.
  final Color groundInner;

  static const light = HomeTokens(
    background: Color(0xFFF3F8FD),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE8EFF7),
    surfaceSoft: Color(0xFFF0F5FA),
    ink: Color(0xFF24364F),
    inkSoft: Color(0xFF415C7A),
    muted: Color(0xFF61758D),
    // 브랜드색(앱 전체 파랑 0064FF)에 맞춘다. 전에는 홈만 하늘색 버튼과
    // 청록(good) 강조라 다른 화면과 색이 달랐다.
    accent: Color(0xFF0064FF),
    onAccent: Color(0xFFFFFFFF),
    primary: Color(0xFF0064FF),
    border: Color(0xFFD9E3EA),
    good: Color(0xFF477B70),
    goodSoft: Color(0xFFDDEFEA),
    shadow: Color(0xFF46637A),
    like: Color(0xFFFF657E),
    likeSoft: Color(0xFFFFE5E9),
    likeInk: Color(0xFFBC4055),
    garden: [
      Color(0xFFF0F5FA),
      Color(0xFFDDEAF8),
      Color(0xFFB9D2EF),
      Color(0xFF6FA3FF),
      Color(0xFF0064FF),
    ],
    mastery: [
      Color(0xFFD9E3EA),
      Color(0xFFA8CBE8),
      Color(0xFF6D9890),
    ],
    groundOuter: Color(0xFFE4EDF2),
    groundInner: Color(0xFFF8FCFE),
  );

  static const dark = HomeTokens(
    background: Color(0xFF101722),
    surface: Color(0xFF18212E),
    surfaceAlt: Color(0xFF1F2B3A),
    surfaceSoft: Color(0xFF1A2432),
    ink: Color(0xFFE6EDF6),
    inkSoft: Color(0xFFBBCBDD),
    muted: Color(0xFF93A4B8),
    accent: Color(0xFF3C8DFF),
    onAccent: Color(0xFFFFFFFF),
    primary: Color(0xFF3C8DFF),
    border: Color(0xFF2A3747),
    good: Color(0xFF7FC2AE),
    goodSoft: Color(0xFF1C3A33),
    shadow: Color(0xFF000000),
    like: Color(0xFFFF8097),
    likeSoft: Color(0xFF3A1F26),
    likeInk: Color(0xFFFFADBB),
    garden: [
      Color(0xFF1C2735),
      Color(0xFF26384D),
      Color(0xFF32516E),
      Color(0xFF2F6BC2),
      Color(0xFF3C8DFF),
    ],
    mastery: [
      Color(0xFF2A3747),
      Color(0xFF3E5C7D),
      Color(0xFF4E7D73),
    ],
    groundOuter: Color(0xFF1B2533),
    groundInner: Color(0xFF243246),
  );

  /// 테마에 등록된 홈 토큰. 없으면 밝기에 맞는 기본값으로 떨어진다.
  static HomeTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<HomeTokens>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// 다크 모드인지.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  HomeTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSoft,
    Color? ink,
    Color? inkSoft,
    Color? muted,
    Color? accent,
    Color? onAccent,
    Color? primary,
    Color? border,
    Color? good,
    Color? goodSoft,
    Color? shadow,
    Color? like,
    Color? likeSoft,
    Color? likeInk,
    List<Color>? garden,
    List<Color>? mastery,
    Color? groundOuter,
    Color? groundInner,
  }) =>
      HomeTokens(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        surfaceSoft: surfaceSoft ?? this.surfaceSoft,
        ink: ink ?? this.ink,
        inkSoft: inkSoft ?? this.inkSoft,
        muted: muted ?? this.muted,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        primary: primary ?? this.primary,
        border: border ?? this.border,
        good: good ?? this.good,
        goodSoft: goodSoft ?? this.goodSoft,
        shadow: shadow ?? this.shadow,
        like: like ?? this.like,
        likeSoft: likeSoft ?? this.likeSoft,
        likeInk: likeInk ?? this.likeInk,
        garden: garden ?? this.garden,
        mastery: mastery ?? this.mastery,
        groundOuter: groundOuter ?? this.groundOuter,
        groundInner: groundInner ?? this.groundInner,
      );

  static List<Color> _lerpList(List<Color> a, List<Color> b, double t) => [
        for (var i = 0; i < a.length; i++)
          Color.lerp(a[i], i < b.length ? b[i] : a[i], t)!,
      ];

  @override
  HomeTokens lerp(HomeTokens? other, double t) {
    if (other == null) return this;
    return HomeTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      border: Color.lerp(border, other.border, t)!,
      good: Color.lerp(good, other.good, t)!,
      goodSoft: Color.lerp(goodSoft, other.goodSoft, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      like: Color.lerp(like, other.like, t)!,
      likeSoft: Color.lerp(likeSoft, other.likeSoft, t)!,
      likeInk: Color.lerp(likeInk, other.likeInk, t)!,
      garden: _lerpList(garden, other.garden, t),
      mastery: _lerpList(mastery, other.mastery, t),
      groundOuter: Color.lerp(groundOuter, other.groundOuter, t)!,
      groundInner: Color.lerp(groundInner, other.groundInner, t)!,
    );
  }
}

/// 색 토큰을 context에서 바로 꺼내는 창구. `context.tokens.textSecondary` 처럼 쓴다.
///
/// `context.texts`와 같은 꼴이다. 밝기 분기를 쓰는 쪽에서 적지 않아도 되므로
/// `isDark ? AppColors.xDark : AppColors.x` 대신 이걸 쓴다.
extension AppTokensContext on BuildContext {
  /// 앱 전역 색 토큰.
  AppTokens get tokens => AppTokens.of(this);

  /// 홈 화면 전용 색 토큰.
  HomeTokens get homeTokens => HomeTokens.of(this);
}
