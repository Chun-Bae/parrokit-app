import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/widgets/app_empty_state.dart';

class EmptyRecentView extends StatelessWidget {
  const EmptyRecentView({super.key});

  @override
  Widget build(BuildContext context) => const AppEmptyState(
        icon: Icons.history_toggle_off,
        title: '아직 최근 본 클립이 없어요',
        description: '플레이어에서 보면 여기에 쌓여요.',
      );
}
