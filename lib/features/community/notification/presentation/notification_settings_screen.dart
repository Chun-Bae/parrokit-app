import 'package:parrokit/features/community/notification/presentation/utils/notification_text.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/shared/utils/login_prompt_text.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/shared/utils/user_error_message.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/notification/data/settings/notification_prefs.dart';

/// 커뮤니티 알림 설정(5차, 사용자 요청). 종류마다 휴대폰 푸시를 켜고 끈다.
/// 꺼도 알림 목록에는 남는다. 휴대폰 설정에서 앱 알림이 꺼져 있으면 알려 준다.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    this.repository,
    this.osPushAllowed,
  });

  /// 테스트에서 바꿔 끼운다. 비우면 Firestore를 쓴다.
  final NotificationPrefsRepository? repository;

  /// 휴대폰(OS)에서 이 앱 알림을 허용했는지. 모르면 null. 비우면 FCM에 묻는다.
  final Future<bool?> Function()? osPushAllowed;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  late final NotificationPrefsRepository _repository =
      widget.repository ?? NotificationPrefsRepository();

  NotificationPrefs? _prefs;
  bool _loadFailed = false;
  bool? _osAllowed;
  String? _uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _uid = context.read<UserProvider?>()?.currentUser?.id;
      _load();
      _checkOsPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 휴대폰 설정에서 알림을 켜고 돌아오면 안내가 바로 사라져야 한다(5차 366).
  ///
  /// 전에는 화면을 열 때 한 번만 물어봐서, '휴대폰 설정 열기'로 켜고 와도
  /// '꺼져 있어요' 상자가 그대로 남았다. 화면을 나갔다 다시 들어와야 바뀌었다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) _checkOsPermission();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    setState(() => _loadFailed = false);
    try {
      final prefs = await _repository.load(uid);
      if (mounted) setState(() => _prefs = prefs);
    } catch (e, st) {
      AppLogger.e('알림 설정 불러오기 실패', error: e, stackTrace: st);
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _checkOsPermission() async {
    try {
      final allowed = await (widget.osPushAllowed ?? _askFcm)();
      if (mounted) setState(() => _osAllowed = allowed);
    } catch (_) {/* 모르면 안내하지 않는다 */}
  }

  static Future<bool?> _askFcm() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.denied => false,
      AuthorizationStatus.notDetermined => null,
      _ => true,
    };
  }

  /// 바로 바꿔 보이고 저장한다. 실패하면 되돌리고 알린다.
  Future<void> _update(NotificationPrefs next) async {
    final uid = _uid;
    final previous = _prefs;
    if (uid == null || previous == null || next == previous) return;
    setState(() => _prefs = next);
    try {
      await _repository.save(uid, next);
    } catch (e, st) {
      AppLogger.e('알림 설정 저장 실패', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _prefs = previous);
      showToast(userErrorMessage(e, fallback: settingsSaveFailedMessage));
    }
  }

  /// 휴대폰의 이 앱 설정 화면을 연다. 열지 못하면 어디로 가야 하는지 알린다.
  Future<void> _openSystemSettings() async {
    try {
      final opened = await launchUrl(Uri.parse('app-settings:'));
      if (opened) return;
    } catch (e) {
      AppLogger.e('[Notification] 휴대폰 설정 열기 실패', error: e);
    }
    if (!mounted) return;
    showToast('휴대폰 설정 > 패로킷 > 알림에서 켜 주세요.');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loggedIn = context.watch<UserProvider?>()?.currentUser != null;
    final prefs = _prefs;

    Widget body;
    if (!loggedIn) {
      // 안내만 하고 끝내면 여기서 할 수 있는 일이 없다. 로그인으로 보낸다
      // (5차 439).
      body = _Message(
        loginToUse('알림을 설정할'),
        actionLabel: goToSignInLabel,
        onAction: () => context.goNamed(AppRoutes.signIn),
      );
    } else if (_loadFailed) {
      body = _Message('설정을 불러오지 못했어요.', actionLabel: '다시 시도', onAction: _load);
    } else if (prefs == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_osAllowed == false) ...[
            Container(
              key: const ValueKey('os-push-off'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.notifications_off_rounded, color: cs.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '휴대폰 설정에서 패로킷 알림이 꺼져 있어요. 아래를 켜도 '
                        '휴대폰 설정 > 패로킷 > 알림을 켜야 받을 수 있어요.',
                        style: context.texts.bodyMedium
                            .copyWith(color: cs.onErrorContainer),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // 어디로 가야 하는지 적어만 두고 찾아가게 두면 멀다.
                  // 바로 그 화면을 연다(5차).
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('open-os-settings'),
                      onPressed: _openSystemSettings,
                      child: const Text('휴대폰 설정 열기'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text('휴대폰 알림으로 받을 것',
                style: context.texts.labelLarge
                    .copyWith(color: context.tokens.textSecondary)),
          ),
          _PrefSwitch(
            key: const ValueKey('pref-post-comment'),
            icon: Icons.chat_bubble_outline_rounded,
            title: '내 글에 댓글',
            subtitle: '게시판·질문·투표에 쓴 글에 댓글이 달리면',
            value: prefs.postComment,
            onChanged: (v) => _update(prefs.copyWith(postComment: v)),
          ),
          _PrefSwitch(
            key: const ValueKey('pref-comment-reply'),
            icon: Icons.reply_rounded,
            title: '내 댓글에 답글',
            subtitle: '내가 단 댓글에 누가 답글을 달면',
            value: prefs.commentReply,
            onChanged: (v) => _update(prefs.copyWith(commentReply: v)),
          ),
          _PrefSwitch(
            key: const ValueKey('pref-vote-end'),
            icon: Icons.how_to_vote_outlined,
            // 앱은 어디서나 '마감'이라 부른다 - 거르개 '마감', 카드의
            // 'N일 뒤 마감', 알림 '투표가 마감됐어요'. 이 줄만 '종료'로
            // 남아 다른 일처럼 보였다(5차 479).
            title: voteEndPrefTitle,
            subtitle: voteEndPrefSubtitle,
            value: prefs.voteEnd,
            onChanged: (v) => _update(prefs.copyWith(voteEnd: v)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '꺼도 커뮤니티 알림 목록(종 아이콘)에는 그대로 남아요. 휴대폰 알림만 오지 않아요.',
              style: context.texts.bodySmall
                  .copyWith(color: context.tokens.textSecondary),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 설정'),
        centerTitle: true,
      ),
      body: SafeArea(child: body),
    );
  }
}

class _PrefSwitch extends StatelessWidget {
  const _PrefSwitch({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        secondary: Icon(icon, color: context.tokens.primary),
        title: Text(title, style: context.texts.titleMedium),
        subtitle: Text(subtitle,
            style: context.texts.bodySmall
                .copyWith(color: context.tokens.textSecondary)),
        value: value,
        onChanged: onChanged,
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text,
                textAlign: TextAlign.center, style: context.texts.bodyLarge),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}
