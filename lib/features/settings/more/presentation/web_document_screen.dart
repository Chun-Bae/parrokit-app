// ============================================================================
// lib/features/more/presentation/web_document_screen.dart
// ============================================================================
//
// [역할]
// 웹뷰 문서 표시 화면 (개인정보처리방침, 이용약관 등).
//
// [레이어]
// Presentation Layer - View
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 웹 문서 표시 화면.
class WebDocumentScreen extends StatefulWidget {
  const WebDocumentScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<WebDocumentScreen> createState() => _WebDocumentScreenState();
}

class _WebDocumentScreenState extends State<WebDocumentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _hideHostChrome();
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// 문서를 띄워 주는 쪽이 끼워 넣는 것들을 가린다(5차).
  ///
  /// 약관과 개인정보 처리방침은 노션 공개 쪽을 그대로 띄운다. 그런데 노션은
  /// 로그인하지 않은 사람에게 **영어 가입 유도 띠**를 문서 맨 위에 꽂는다
  /// ("You're almost there — sign up to start building in Notion today").
  /// 한국어 약관 위에 영어 광고가 붙고, 심사에서도 문서가 아니라 노션
  /// 가입 화면처럼 보인다. 위쪽 제목줄과 햄버거 메뉴도 문서에는 필요 없다.
  ///
  /// 클래스 이름은 노션이 언제든 바꾸므로 거기에만 기대지 않는다. 글로도
  /// 한 번 더 찾고, 늦게 그려지는 것까지 잡게 지켜본다. 못 가려도 문서
  /// 자체는 그대로 보이므로 실패해도 넘어간다.
  Future<void> _hideHostChrome() async {
    try {
      await _controller.runJavaScript(r"""
(function () {
  var style = document.createElement('style');
  style.textContent = '.notion-topbar,.notion-topbar-mobile{display:none!important}';
  (document.head || document.documentElement).appendChild(style);

  function hideCta() {
    var nodes = document.querySelectorAll('div,section,aside');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var text = (el.innerText || '').trim();
      if (text.length === 0 || text.length > 160) continue;
      if (text.indexOf('sign up to start building') >= 0 ||
          text.indexOf('Sign up or login') >= 0 ||
          text.indexOf('Try Notion') >= 0 ||
          text.indexOf('Duplicate') === 0) {
        el.style.display = 'none';
      }
    }
  }

  hideCta();
  if (document.body) {
    new MutationObserver(hideCta)
        .observe(document.body, {childList: true, subtree: true});
  }
})();
""");
    } catch (error) {
      AppLogger.w('[WebDocument] 바깥 요소 가리기 실패(넘어간다): $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              color: cs.primary,
              backgroundColor: cs.surfaceContainerHighest,
            ),
        ],
      ),
    );
  }
}
