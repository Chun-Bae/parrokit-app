import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/content-studio/captioning/presentation/screens/captioning_screen.dart';
import 'package:parrokit/features/content-studio/tts/presentation/screens/tts_screen.dart';
import 'package:parrokit/features/content-studio/tts/presentation/providers/tts_provider.dart';
import 'package:parrokit/features/content-studio/tts/domain/repositories/tts_generation_repository.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/features/content-studio/video/domain/models/video_generation_models.dart';
import 'package:parrokit/features/content-studio/video/presentation/video_screen.dart';
import 'package:parrokit/features/content-studio/video/presentation/video_provider.dart';
import 'package:parrokit/features/content-studio/chat-bot/presentation/chat_bot_provider.dart';
import 'studio_hub_provider.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/dashboard_studio_switch_fab.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/features/content-studio/chat-bot/presentation/widgets/chat_bot_fab.dart';
import 'content_studio_app_bar.dart';
import 'widgets/content_studio_exit_confirm_sheet.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class ContentStudioHubScreen extends StatefulWidget {
  const ContentStudioHubScreen({
    super.key,
    this.initialIndex = 0,
  });

  final int initialIndex;

  @override
  State<ContentStudioHubScreen> createState() => _ContentStudioHubScreenState();
}

class _ContentStudioHubScreenState extends State<ContentStudioHubScreen> {
  late final PageController _pageController;
  /// 마지막 탭 번호. 영상 만들기를 숨기면 TTS(1)가 끝이다.
  static int get _lastIndex => kVideoStudioEnabled ? 2 : 1;

  late int _selectedIndex;
  bool _isAppBarExpanded = false;
  bool _isChatBotVisible = true;
  bool _isSwipeEnabled = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _lastIndex);
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void didUpdateWidget(covariant ContentStudioHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.initialIndex.clamp(0, _lastIndex);
    if (nextIndex == _selectedIndex) return;
    _selectedIndex = nextIndex;
    _pageController.jumpToPage(nextIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setPage(int index) {
    index = index.clamp(0, _lastIndex);
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleBack(StudioHubProvider hub) async {
    final router = GoRouter.of(context);
    if (!hub.hasUnsavedWork) {
      _leave(router);
      return;
    }
    final shouldExit = await showContentStudioExitConfirmSheet(context);
    if (shouldExit != true) return;
    _leave(router);
  }

  /// 콘텐츠 제작을 나간다. 들어온 화면이 쌓여 있으면 그리로 돌아가고(보관함의 +
  /// 로 들어왔으면 보관함), 없으면 홈으로 간다. 예전엔 늘 홈으로 갔다(5차).
  void _leave(GoRouter router) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.dashboardPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProvider = context.watch<UserProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? context.tokens.surface : theme.colorScheme.surface;
    final appBarTitle = switch (_selectedIndex) {
      0 => '편집',
      1 => 'TTS 생성',
      _ => '영상 생성',
    };
    // 영상 만들기를 숨기면 챗봇이 영상 탭을 열려고 해도 열 곳이 없다.
    void openFromChatbot(int tabIndex) {
      if (tabIndex == 2 && !kVideoStudioEnabled) {
        showToast('영상 만들기는 지금 쉬고 있어요.');
        return;
      }
      _setPage(tabIndex);
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StudioHubProvider()),
        ChangeNotifierProvider(
          create: (context) =>
              TtsProvider(userProvider: context.read<UserProvider>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              VideoProvider(userProvider: context.read<UserProvider>()),
        ),
        ChangeNotifierProvider(create: (_) => ChatBotProvider()),
      ],
      child: Builder(
        builder: (context) {
          final hubProvider = context.watch<StudioHubProvider>();
          if (hubProvider.requestedTabIndex != null) {
            final idx = hubProvider.requestedTabIndex!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                hubProvider.clearRequestedTabIndex();
                _setPage(idx);
              }
            });
          }

          return Scaffold(
            backgroundColor: bg,
            appBar: ContentStudioAppBar(
              title: appBarTitle,
              coins: userProvider.coins,
              onBack: () => _handleBack(hubProvider),
              backgroundColor: bg,
              onToggleExpand: () {
                setState(() {
                  _isAppBarExpanded = !_isAppBarExpanded;
                });
              },
              isExpanded: _isAppBarExpanded,
            ),
            body: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                _handleBack(hubProvider);
              },
              child: SafeArea(
                top: false,
                child: Stack(
                  children: [
                    PageView(
                      controller: _pageController,
                      physics: _isSwipeEnabled
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        if (_selectedIndex == index) return;
                        setState(() => _selectedIndex = index);
                      },
                      children: [
                        _StudioPageSlot(
                          child: CaptioningScreen(
                            showAppBar: false,
                            onClose: (_) async =>
                                _leave(GoRouter.of(context)),
                          ),
                        ),
                        _StudioPageSlot(child: TtsScreen()),
                        if (kVideoStudioEnabled)
                          _StudioPageSlot(child: VideoScreen()),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 24,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DashboardStudioSwitchFab(
                            selectedIndex: _selectedIndex,
                            onSelectedIndexChanged: _setPage,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            alignment: Alignment.centerLeft,
                            child: _isChatBotVisible
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 8),
                                      ChatBotFab(
                                        onTriggerAction:
                                            (tabIndex, actionData) {
                                          if (tabIndex == 1) {
                                            final ttsProv =
                                                context.read<TtsProvider>();
                                            if (actionData != null) {
                                              if (actionData['text'] != null) {
                                                ttsProv.updateText(
                                                    actionData['text']
                                                        as String);
                                              }
                                              if (actionData['language'] !=
                                                  null) {
                                                ttsProv.updateLanguage(
                                                    actionData['language']
                                                        as String);
                                              }
                                              if (actionData['provider'] !=
                                                  null) {
                                                final pType = actionData[
                                                            'provider'] ==
                                                        'elevenlabs'
                                                    ? TtsProviderType.elevenlabs
                                                    : TtsProviderType.google;
                                                ttsProv
                                                    .updateProviderType(pType);
                                              }
                                              if (actionData['voiceId'] !=
                                                  null) {
                                                ttsProv.updateVoiceId(
                                                    actionData['voiceId']
                                                        as String);
                                              }
                                            }
                                          } else if (tabIndex == 2) {
                                            final videoProv =
                                                context.read<VideoProvider>();
                                            if (actionData != null) {
                                              if (actionData['prompt'] !=
                                                  null) {
                                                videoProv.updateScenePrompt(
                                                    actionData['prompt']
                                                        as String);
                                              }
                                              if (actionData['ratio'] != null) {
                                                videoProv.updateRatio(
                                                    actionData['ratio']
                                                        as String);
                                              }
                                              if (actionData['script'] !=
                                                  null) {
                                                videoProv.updateDialogue(
                                                    actionData['script']
                                                        as String);
                                              }
                                            }
                                          }
                                          openFromChatbot(tabIndex);
                                        },
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipRect(
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          alignment: Alignment.bottomCenter,
                          heightFactor: _isAppBarExpanded ? 1.0 : 0.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: isDark ? 0.3 : 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Wrap(
                                alignment: WrapAlignment.start,
                                children: [
                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width / 3,
                                    child: _AppBarOptionItem(
                                      icon: _isChatBotVisible
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      label: _isChatBotVisible
                                          ? 'AI 챗봇 숨기기'
                                          : 'AI 챗봇 켜기',
                                      iconColor: _isChatBotVisible
                                          ? theme.colorScheme.onSurfaceVariant
                                          : theme.colorScheme.primary,
                                      onTap: () {
                                        setState(() {
                                          _isChatBotVisible =
                                              !_isChatBotVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width / 3,
                                    child: _AppBarOptionItem(
                                      icon: Icons.storefront_rounded,
                                      label: '패롯 충전',
                                      iconColor: context.tokens.warning,
                                      onTap: () {
                                        context.pushReplacement(
                                            AppRoutes.morePath);
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width / 3,
                                    child: _AppBarOptionItem(
                                      icon: Icons.settings,
                                      label: '스튜디오 설정',
                                      iconColor: theme.colorScheme.onSurface,
                                      onTap: () {
                                        _showSettingsSheet(context);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '스튜디오 설정',
                      style: context.texts.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('화면 슬라이딩 이동 켜기'),
                      subtitle: const Text('스와이프하여 탭을 이동할 수 있습니다.'),
                      value: _isSwipeEnabled,
                      onChanged: (val) {
                        setSheetState(() {
                          _isSwipeEnabled = val;
                        });
                        setState(() {
                          _isSwipeEnabled = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StudioPageSlot extends StatefulWidget {
  const _StudioPageSlot({required this.child});

  final Widget child;

  @override
  State<_StudioPageSlot> createState() => _StudioPageSlotState();
}

class _StudioPageSlotState extends State<_StudioPageSlot>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _AppBarOptionItem extends StatelessWidget {
  const _AppBarOptionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: context.texts.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
