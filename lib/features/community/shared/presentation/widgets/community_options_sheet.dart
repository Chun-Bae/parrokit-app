import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

class CommunityOptionAction {
  const CommunityOptionAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final IconData? icon;
  final bool isDestructive;
  final Future<void> Function() onTap;
}

Future<void> showCommunityOptionsSheet({
  required BuildContext context,
  required List<CommunityOptionAction> actions,
  String title = '옵션',
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
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
    final foregroundColor =
        action.isDestructive ? context.tokens.danger : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
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
