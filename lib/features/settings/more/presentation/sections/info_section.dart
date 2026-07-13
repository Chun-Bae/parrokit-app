// ============================================================================
// lib/features/more/presentation/sections/info_section.dart
// ============================================================================
//
// [역할]
// 정보 섹션 위젯.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parrokit/core/shared/widgets/tip_dialog.dart';

import '../widgets/card_container.dart';
import '../widgets/hairline_divider.dart';
import '../widgets/nav_tile.dart';
import '../widgets/section_title.dart';
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
      setState(() => _versionLabel = '버전 ${info.version} (${info.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('정보'),
        const SizedBox(height: 10),
        CardContainer(
          child: Column(
            children: [
              NavTile(
                icon: Icons.info_outline,
                title: '앱 정보',
                subtitle: _versionLabel,
                onTap: () {},
                showArrow: false,
              ),
              const HairlineDivider(),
              NavTile(
                icon: Icons.help_outline,
                title: '도움말',
                onTap: () => showTipDialog(context, force: true),
              ),
              const HairlineDivider(),
              NavTile(
                icon: Icons.privacy_tip_outlined,
                title: '개인정보 처리방침',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WebDocumentScreen(
                        title: '개인정보 처리방침',
                        url:
                            'https://www.notion.so/2025-11-20-2b1b6c6245ad80b38685e5b20cc4be73?source=copy_link',
                      ),
                    ),
                  );
                },
              ),
              const HairlineDivider(),
              NavTile(
                icon: Icons.privacy_tip_outlined,
                title: '이용 약관',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const WebDocumentScreen(
                        title: '이용 약관',
                        url:
                            'https://www.notion.so/2025-11-20-2b1b6c6245ad80d2b741e496571298be?source=copy_link',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
