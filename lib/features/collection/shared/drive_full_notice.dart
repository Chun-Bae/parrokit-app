// Drive가 가득 찼을 때 보여 주는 안내.
//
// 전에는 '남은 공간 0 B' 칩 하나만 회색으로 있어서, 왜 클립을 올리지 못하는지
// 알 수 없었다(5차). 같은 안내를 더보기와 보관함 두 곳에서 쓴다.

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';

/// Drive 남은 공간이 이보다 적으면 가득 찬 것으로 본다(클립 하나도 못 올린다).
const int driveLowSpaceBytes = 20 * 1024 * 1024;

/// 남은 공간으로 본 Drive 상태. [hasQuota]가 거짓이면 알 수 없으므로 안내하지 않는다.
String? driveSpaceWarning({required bool hasQuota, required int remaining}) {
  if (!hasQuota) return null;
  if (remaining <= 0) {
    return 'Drive가 가득 찼어요. 새 클립을 올릴 수 없어요. '
        'Drive에서 공간을 비우거나 저장 위치를 바꿔 주세요.';
  }
  if (remaining < driveLowSpaceBytes) {
    return 'Drive 남은 공간이 얼마 없어요. 큰 클립은 올리지 못할 수 있어요.';
  }
  return null;
}

/// [driveSpaceWarning]이 있을 때만 보이는 줄.
class DriveFullNotice extends StatelessWidget {
  const DriveFullNotice({
    super.key,
    required this.hasQuota,
    required this.remaining,
  });

  final bool hasQuota;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final message = driveSpaceWarning(hasQuota: hasQuota, remaining: remaining);
    if (message == null) return const SizedBox.shrink();
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        key: const ValueKey('drive-space-warning'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.dangerSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: tokens.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: tokens.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
