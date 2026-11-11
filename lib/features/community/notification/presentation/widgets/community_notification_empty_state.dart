import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/widgets/app_empty_state.dart';

class CommunityNotificationEmptyState extends StatelessWidget {
  const CommunityNotificationEmptyState({super.key});

  @override
  Widget build(BuildContext context) => const AppEmptyState(
        icon: Icons.notifications_none_rounded,
        title: '알림이 없어요.',
        description: '게시글, 댓글, 투표 알림이 여기에 표시돼요.',
      );
}
