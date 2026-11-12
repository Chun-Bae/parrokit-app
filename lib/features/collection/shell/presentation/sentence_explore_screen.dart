// 둘러보기 전용 화면. 다른 사람이 공유한 문장과 Parrokit 문장팩을 본다.
//
// 전에는 보관함 문장 탭 안에서 "내 문장 / 둘러보기" 탭으로 바꿔 봤다. 이제
// 문장 탭에는 둘러보기 한 줄만 두고, "전체"를 누르면 이 화면이 열린다.
// 홈의 "인기 공유 문장 · 전체 보기"도 여기로 온다.

import 'package:flutter/material.dart';
import 'widgets/sentence_collection_preview.dart';

class SentenceExploreScreen extends StatelessWidget {
  const SentenceExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('둘러보기'),
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
      ),
      body: const SentenceCollectionPreview(exploreOnly: true),
    );
  }
}

/// 둘러보기 화면을 탭바 위로 띄운다.
Future<void> openSentenceExplore(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const SentenceExploreScreen()),
    );
