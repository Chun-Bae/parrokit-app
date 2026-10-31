// ============================================================================
// lib/core/navigation/app_bottom_navbar.dart
// ============================================================================
//
// [역할]
// 앱 하단 네비게이션 바 위젯.
// 반투명 캡슐 안에 쇼츠, 커뮤니티, 홈, 콜렉션, 더보기 탭으로 구성.
//
// [레이어]
// Core Layer > Navigation
// 앱 전체 네비게이션 쉘 컴포넌트.
// ============================================================================

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:native_glass_navbar/native_glass_navbar.dart';

import 'package:parrokit/core/shared/theme/app_theme.dart';

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NativeGlassNavBar(
      currentIndex: currentIndex,
      onTap: onTap,
      tintColor: CupertinoColors.systemBlue.resolveFrom(context),
      tabs: const [
        NativeGlassNavBarItem(label: '쇼츠', symbol: 'play.rectangle.fill'),
        NativeGlassNavBarItem(label: '커뮤니티', symbol: 'person.2.fill'),
        NativeGlassNavBarItem(label: '홈', symbol: 'house.fill'),
        NativeGlassNavBarItem(label: '콜렉션', symbol: 'bookmark.fill'),
        NativeGlassNavBarItem(label: '더보기', symbol: 'ellipsis'),
      ],
      fallback: _GlassFallbackNavBar(
        currentIndex: currentIndex,
        onTap: onTap,
      ),
    );
  }
}

class _GlassFallbackNavBar extends StatelessWidget {
  const _GlassFallbackNavBar({
    required this.currentIndex, // 현재 선택된 탭 인덱스
    required this.onTap, // 탭 선택 콜백
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    const destinations = [
      (Icons.slow_motion_video, '쇼츠'),
      (Icons.people, '커뮤니티'),
      (Icons.home_rounded, '홈'),
      (Icons.bookmarks, '콜렉션'),
      (Icons.more_horiz, '더보기'),
    ];

    final reduceTransparency = MediaQuery.highContrastOf(context) ||
        MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(AppTheme.bottomNavRadius);

    return SafeArea(
      top: false,
      child: Padding(
        padding: AppTheme.bottomNavMargin,
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: reduceTransparency ? 0 : AppTheme.bottomNavBlur,
              sigmaY: reduceTransparency ? 0 : AppTheme.bottomNavBlur,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface.withValues(
                  alpha:
                      reduceTransparency ? 1 : AppTheme.bottomNavSurfaceOpacity,
                ),
                borderRadius: radius,
                border: Border.all(
                  color: colors.outlineVariant.withValues(
                    alpha: AppTheme.bottomNavBorderOpacity,
                  ),
                ),
              ),
              child: Padding(
                padding: AppTheme.bottomNavPadding,
                child: SizedBox(
                  height: AppTheme.bottomNavHeight,
                  child: Row(
                    children: List.generate(destinations.length, (index) {
                      final (icon, label) = destinations[index];
                      final selected = currentIndex == index;
                      final color =
                          selected ? colors.primary : colors.onSurfaceVariant;

                      return Expanded(
                        child: Semantics(
                          selected: selected,
                          button: true,
                          label: label,
                          excludeSemantics: true,
                          child: AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : AppTheme.bottomNavAnimation,
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              color: colors.primary.withValues(
                                alpha: selected
                                    ? AppTheme.bottomNavSelectionOpacity
                                    : 0,
                              ),
                            ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                borderRadius: radius,
                                onTap: () => onTap(index),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon,
                                          size: AppTheme.bottomNavIconSize,
                                          color: color),
                                      const SizedBox(
                                          height: AppTheme.bottomNavLabelGap),
                                      Text(label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: color)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
