import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 가져올 곳으로 고른 방법. [url]이 null이면 파일에서, 아니면 그 주소에서 가져온다.
class SentenceImportSource {
  const SentenceImportSource.file() : url = null;
  const SentenceImportSource.url(String this.url);

  final String? url;
}

/// CSV·엑셀 가져오기 창. 위(헤드)에는 제목, 가운데(바디)에는 옆으로 넘기는 도움말 1~3쪽,
/// 아래(푸터)에는 주소로 가져올지 파일에서 가져올지 고르는 영역이 항상 보인다.
class SentenceImportMethodDialog extends StatefulWidget {
  const SentenceImportMethodDialog({super.key});

  @override
  State<SentenceImportMethodDialog> createState() =>
      _SentenceImportMethodDialogState();
}

class _SentenceImportMethodDialogState
    extends State<SentenceImportMethodDialog> {
  static const _pageCount = 3;

  final _pages = PageController();
  final _url = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    _url.dispose();
    super.dispose();
  }

  void _go(int page) => _pages.animateToPage(page,
      duration: const Duration(milliseconds: 220), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      key: const ValueKey('import-method-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _head(context),
            const Divider(height: 1),
            Flexible(
              child: SizedBox(
                height: 330,
                child: PageView(
                  key: const ValueKey('import-pages'),
                  controller: _pages,
                  onPageChanged: (value) => setState(() => _page = value),
                  children: [
                    _formatPage(colors),
                    _rulesPage(colors),
                    _urlHelpPage(colors),
                  ],
                ),
              ),
            ),
            _pager(colors),
            const Divider(height: 1),
            _footer(colors),
          ],
        ),
      ),
    );
  }

  /// 헤드: 제목과 닫기 버튼.
  Widget _head(BuildContext context) => Padding(
        key: const ValueKey('import-head'),
        padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
        child: Row(children: [
          Expanded(
            child: Text('CSV·엑셀에서 가져오기',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          IconButton(
            tooltip: '닫기',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ]),
      );

  /// 바디 아래: 이전·다음 버튼과 현재 쪽 표시.
  Widget _pager(ColorScheme colors) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(children: [
          IconButton(
            key: const ValueKey('import-prev'),
            tooltip: '이전',
            onPressed: _page == 0 ? null : () => _go(_page - 1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _pageCount; i++)
                  Container(
                    width: _page == i ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color:
                          _page == i ? colors.primary : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
              ]),
              const SizedBox(height: 2),
              Text('${_page + 1} / $_pageCount',
                  key: const ValueKey('import-page-label'),
                  style: context.texts.labelSmall
                      .copyWith(color: colors.onSurfaceVariant)),
            ]),
          ),
          IconButton(
            key: const ValueKey('import-next'),
            tooltip: '다음',
            onPressed: _page == _pageCount - 1 ? null : () => _go(_page + 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
      );

  /// 푸터: 주소를 입력해 가져오거나, 파일을 골라 가져온다.
  Widget _footer(ColorScheme colors) => Padding(
        key: const ValueKey('import-footer'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('url-import-input'),
                  controller: _url,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '파일 주소(URL)',
                    hintText: 'https://…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('url-import-confirm'),
                onPressed: () => Navigator.pop(
                    context, SentenceImportSource.url(_url.text.trim())),
                child: Text('주소에서\n가져오기',
                    textAlign: TextAlign.center,
                    style: context.texts.bodySmall),
              ),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('import-from-file'),
              onPressed: () =>
                  Navigator.pop(context, const SentenceImportSource.file()),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46)),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('파일에서 가져오기'),
            ),
          ],
        ),
      );

  /// 예시 이미지를 화면 가득 보여준다. 두 손가락으로 확대할 수 있다.
  void _showSampleImage() => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          key: const ValueKey('import-sample-viewer'),
          insetPadding: const EdgeInsets.all(12),
          child: Stack(children: [
            InteractiveViewer(
              maxScale: 4,
              child: Image.asset('assets/help/import_sample.png'),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ]),
        ),
      );

  Widget _scroll(List<Widget> children) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      );

  Widget _formatPage(ColorScheme colors) {
    const header = ['언어', '문장', '뜻', '발음'];
    const rows = [
      ['영어', 'Good morning', '좋은 아침', '굿모닝'],
      ['일본어', 'ありがとう', '고마워요', '아리가토'],
    ];
    Widget cell(String text, {bool head = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Text(text,
              style: context.texts.bodySmall.copyWith(
                  fontWeight: head ? FontWeight.w800 : FontWeight.w500,
                  color: head ? colors.onPrimaryContainer : null)),
        );
    return _scroll([
      _title('1. 엑셀·구글 시트에서 이렇게 만들어요'),
      Container(
        key: const ValueKey('import-format-sample'),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.1),
            1: FlexColumnWidth(2.2),
            2: FlexColumnWidth(1.8),
            3: FlexColumnWidth(1.6),
          },
          border: TableBorder(
              horizontalInside: BorderSide(color: colors.outlineVariant)),
          children: [
            TableRow(
              decoration: BoxDecoration(color: colors.primaryContainer),
              children: [for (final h in header) cell(h, head: true)],
            ),
            for (final row in rows)
              TableRow(children: [for (final c in row) cell(c)]),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text('실제 엑셀 화면 예시 (눌러서 크게 보기)',
          style:
              context.texts.bodySmall.copyWith(color: colors.onSurfaceVariant)),
      const SizedBox(height: 6),
      GestureDetector(
        key: const ValueKey('import-sample-image'),
        onTap: _showSampleImage,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset('assets/help/import_sample.png',
                fit: BoxFit.fitWidth),
          ),
        ),
      ),
      const SizedBox(height: 14),
      _bullet('첫 줄은 머리글(언어, 문장, 뜻, 발음)이에요.'),
      _bullet('꼭 필요한 건 문장 열 하나예요. 뜻과 발음은 비워도 돼요.'),
      _bullet('내 문장을 CSV·엑셀로 내보내면 이 양식 그대로 만들어져요.'),
    ]);
  }

  Widget _rulesPage(ColorScheme colors) => _scroll([
        _title('2. 이런 점을 알아두세요'),
        _bullet('열 이름이 맞으면 순서가 달라도 돼요. 머리글이 없으면 문장, 뜻, 발음 순서로 읽어요.'),
        _bullet('언어는 영어, 일본어, 중국어로 적어요. 비워 두면 가져올 때 보고 있던 언어로 들어가요.'),
        _bullet('이미 있는 문장은 건너뛰어요.'),
        _bullet('가져오기 전에 목록이 먼저 나와요. 빼고 싶은 문장은 체크를 풀고, 끝난 뒤에도 취소할 수 있어요.'),
        _bullet('CSV는 UTF-8로 저장해야 한글이 깨지지 않아요. 엑셀에서는 "CSV UTF-8"로 저장하세요.'),
        _bullet('엑셀(xlsx)은 첫 번째 시트만 읽어요.'),
      ]);

  Widget _urlHelpPage(ColorScheme colors) => _scroll([
        _title('3. 주소로 가져올 때'),
        _bullet('https로 시작하는 CSV·엑셀 파일 하나의 주소여야 하고, 5MB까지 가져올 수 있어요.'),
        _bullet('누구나 볼 수 있게 공유한 파일이어야 해요. 로그인이 필요한 파일은 읽을 수 없어요.'),
        const SizedBox(height: 6),
        _section('구글 스프레드시트'),
        _bullet(
            '공유를 "링크가 있는 모든 사용자 보기"로 바꾸고 공유 주소를 그대로 붙여넣어요. 시트가 여러 개면 주소의 탭 하나만 가져와요.'),
        const SizedBox(height: 6),
        _section('아이클라우드 드라이브'),
        _bullet('폴더가 아니라 파일 하나를 "링크가 있는 모든 사용자"로 공유한 주소를 붙여넣어요.'),
        _bullet('애플이 공개한 방식이 아니라서 나중에 안 될 수 있어요. 그때는 파일에서 가져오기를 써주세요.'),
      ]);

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: context.texts.labelMedium),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.circle, size: 5),
            ),
            Expanded(
                child: Text(text,
                    style: context.texts.labelMedium.copyWith(height: 1.4))),
          ],
        ),
      );
}
