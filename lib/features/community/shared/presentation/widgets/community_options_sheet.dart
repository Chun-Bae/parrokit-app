import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

class CommunityOptionAction {
  const CommunityOptionAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.isDestructive = false,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final bool isDestructive;

  /// 지금 할 수 없는 일이면 false. 흐리게 보이고 눌러도 아무 일이 없다.
  /// 전에는 할 수 없을 때도 멀쩡해 보여, 눌러도 조용히 닫히기만 했다(5차).
  final bool enabled;

  final Future<void> Function() onTap;
}

Future<void> showCommunityOptionsSheet({
  required BuildContext context,
  required List<CommunityOptionAction> actions,
  String title = '옵션',
}) async {
  await showAppSheet<void>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...actions.map(
                (action) => _CommunityOptionActionTile(
                  action: action,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await action.onTap();
                  },
                ),
              ),
              const SizedBox(height: 4),
              _CommunityOptionActionTile(
                action: CommunityOptionAction(
                  label: '닫기',
                  onTap: _noop,
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _noop() async {}

class _CommunityOptionActionTile extends StatelessWidget {
  const _CommunityOptionActionTile({
    required this.action,
    required this.onTap,
  });

  final CommunityOptionAction action;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor =
        action.isDestructive ? context.tokens.danger : colorScheme.onSurface;
    final foregroundColor =
        action.enabled ? baseColor : baseColor.withValues(alpha: 0.38);

    return InkWell(
      onTap: action.enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action.label,
              style: context.texts.titleMedium.copyWith(color: foregroundColor),
            ),
          ],
        ),
      ),
    );
  }
}
