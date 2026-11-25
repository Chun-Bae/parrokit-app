// ============================================================================
// lib/features/more/presentation/sections/info_section.dart
// ============================================================================
//
// [역할]
// 정보 섹션 위젯.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/app/navigation/push_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parrokit/core/shared/widgets/tip_dialog.dart';

import '../widgets/nav_tile.dart';
import '../web_document_screen.dart';

/// 정보 섹션.
class InfoSection extends StatefulWidget {
  const InfoSection({super.key});

  @override
  State<InfoSection> createState() => _InfoSectionState();
}

class _InfoSectionState extends State<InfoSection> {
  String _versionLabel = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _versionLabel = '${info.version} (${info.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    // 카드 테두리·그림자·여백 없이 목록으로 붙인다.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        children: [
          NavTile(
            icon: Icons.info_outline,
            title: '앱 정보',
            // 버전을 보여주는 줄이고 갈 곳이 없다. onTap을 빼면 눌리는
            // 느낌이 사라진다.
            trailing: Text(
              _versionLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          NavTile(
            icon: Icons.help_outline,
            // '도움말'이라는 이름에 견주면 내용이 안내 세 가지뿐이라, 사용법
            // 도움말을 기대하고 누르면 어긋났다. 창 제목과 같은 말로 둔다(5차).
            title: '이용 안내',
            onTap: () => showTipDialog(context, force: true),
          ),
          NavTile(
            icon: Icons.privacy_tip_outlined,
            title: '개인정보 처리방침',
            onTap: () {
              pushAppScreen(
                context,
                const WebDocumentScreen(
                  title: '개인정보 처리방침',
                  url: 'https://www.notion.so/421b6c6245ad813f8060ce2b10735561',
                ),
              );
            },
          ),
          NavTile(
            // 개인정보 처리방침과 같은 방패 아이콘이라 구분이 안 됐다(5차).
            icon: Icons.description_outlined,
            title: '이용 약관',
            onTap: () {
              pushAppScreen(
                context,
                const WebDocumentScreen(
                  title: '이용 약관',
                  url: 'https://www.notion.so/421b6c6245ad81c48b1ed73a4c6ed4a7',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
