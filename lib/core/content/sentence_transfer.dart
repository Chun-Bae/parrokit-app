import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'default_conversation_sentences.dart';

/// 가져오기 파일에서 읽은 문장 한 줄. 원문만 있으면 되고 뜻·발음·언어는 비어 있어도 된다.
class ImportedSentence {
  const ImportedSentence({
    required this.text,
    this.translation = '',
    this.pronunciation = '',
    this.language = '',
  });

  final String text;
  final String translation;
  final String pronunciation;

  /// 비어 있으면 가져오는 쪽에서 고른 언어를 쓴다.
  final String language;
}

/// 내 문장을 CSV·엑셀(xlsx)로 내보내고 가져오는 형식.
///
/// 열 순서는 `언어, 문장, 뜻, 발음`이다. 가져올 때는 첫 줄이 머리글이면 열 이름으로 찾고,
/// 머리글이 없으면 `문장, 뜻, 발음` 순서로 읽는다.
class SentenceTransfer {
  const SentenceTransfer._();

  static const _header = ['언어', '문장', '뜻', '발음'];

  static const _languageNames = {'언어', 'language'};
  static const _textNames = {'문장', '원문', 'text', 'sentence'};
  static const _translationNames = {'뜻', '번역', 'translation', 'meaning'};
  static const _pronunciationNames = {'발음', 'pronunciation'};

  static List<List<String>> _rowsOf(List<DefaultConversationSentence> list) => [
        _header,
        for (final s in list)
          [s.language, s.text, s.translation, s.pronunciation],
      ];

  /// 엑셀에서 한글이 깨지지 않도록 UTF-8 BOM을 붙인 CSV.
  static String exportCsv(List<DefaultConversationSentence> sentences) {
    final lines = [
      for (final row in _rowsOf(sentences)) row.map(_csvCell).join(','),
    ];
    return '﻿${lines.join('\r\n')}\r\n';
  }

  static String _csvCell(String value) =>
      value.contains(RegExp(r'[",\r\n]')) || value != value.trim()
          ? '"${value.replaceAll('"', '""')}"'
          : value;

  /// 시트 하나짜리 xlsx 파일.
  static Uint8List exportXlsx(List<DefaultConversationSentence> sentences) {
    final sheet = StringBuffer(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData>');
    final rows = _rowsOf(sentences);
    for (var r = 0; r < rows.length; r++) {
      sheet.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final text = XmlText(rows[r][c]).toXmlString();
        sheet.write('<c r="${_columnName(c)}${r + 1}" t="inlineStr">'
            '<is><t xml:space="preserve">$text</t></is></c>');
      }
      sheet.write('</row>');
    }
    sheet.write('</sheetData></worksheet>');

    const header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    final archive = Archive()
      ..add(ArchiveFile.string(
          '[Content_Types].xml',
          '$header<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
              '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
              '<Default Extension="xml" ContentType="application/xml"/>'
              '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
              '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
              '</Types>'))
      ..add(ArchiveFile.string(
          '_rels/.rels',
          '$header<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
              '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
              '</Relationships>'))
      ..add(ArchiveFile.string(
          'xl/workbook.xml',
          '$header<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
              'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
              '<sheets><sheet name="내 문장" sheetId="1" r:id="rId1"/></sheets></workbook>'))
      ..add(ArchiveFile.string(
          'xl/_rels/workbook.xml.rels',
          '$header<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
              '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
              '</Relationships>'))
      ..add(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet.toString()));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// 파일 이름의 확장자로 CSV/TSV/텍스트와 xlsx를 구분해 읽는다.
  /// 읽을 수 없는 내용이면 [FormatException]을 던진다.
  static List<ImportedSentence> parse(Uint8List bytes, String fileName) {
    final isXlsx = fileName.toLowerCase().endsWith('.xlsx');
    return _parseAs(bytes, isXlsx: isXlsx);
  }

  /// 주소에서 받은 내용처럼 파일 이름이 없을 때, 내용이 zip(`PK`)이면 xlsx로 보고 아니면 CSV로 읽는다.
  /// 로그인 페이지 같은 웹 페이지(HTML)가 내려오면 [FormatException]을 던진다.
  static List<ImportedSentence> parseDownloaded(Uint8List bytes) {
    final isXlsx = bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (!isXlsx) {
      final head = utf8
          .decode(bytes.take(200).toList(), allowMalformed: true)
          .trimLeft()
          .toLowerCase();
      if (head.startsWith('<!doctype') || head.startsWith('<html')) {
        throw const FormatException('웹 페이지가 내려왔어요.');
      }
    }
    return _parseAs(bytes, isXlsx: isXlsx);
  }

  static List<ImportedSentence> _parseAs(Uint8List bytes,
      {required bool isXlsx}) {
    final rows = isXlsx ? _xlsxRows(bytes) : _csvRows(utf8.decode(bytes));
    return _fromRows(rows);
  }

  static List<ImportedSentence> _fromRows(List<List<String>> rows) {
    final table = [
      for (final row in rows)
        if (row.any((cell) => cell.trim().isNotEmpty)) row,
    ];
    if (table.isEmpty) return const [];

    int indexOf(List<String> header, Set<String> names) =>
        header.indexWhere((cell) => names.contains(cell.trim().toLowerCase()));

    var languageAt = -1, textAt = 0, translationAt = 1, pronunciationAt = 2;
    var start = 0;
    final header = table.first;
    final headerTextAt = indexOf(header, _textNames);
    if (headerTextAt >= 0) {
      start = 1;
      textAt = headerTextAt;
      languageAt = indexOf(header, _languageNames);
      translationAt = indexOf(header, _translationNames);
      pronunciationAt = indexOf(header, _pronunciationNames);
    }

    String cell(List<String> row, int index) =>
        index >= 0 && index < row.length ? row[index].trim() : '';

    return [
      for (final row in table.skip(start))
        if (cell(row, textAt).isNotEmpty)
          ImportedSentence(
            text: cell(row, textAt),
            translation: cell(row, translationAt),
            pronunciation: cell(row, pronunciationAt),
            language: cell(row, languageAt),
          ),
    ];
  }

  /// 따옴표 안의 쉼표·줄바꿈을 지키며 CSV를 칸으로 나눈다. 첫 줄에 탭이 있으면 탭으로 나눈다.
  static List<List<String>> _csvRows(String raw) {
    final content = raw.replaceFirst('﻿', '');
    final firstLine = content.split(RegExp(r'\r?\n')).first;
    final separator = firstLine.contains('\t') ? '\t' : ',';
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;

    void endCell() {
      row.add(cell.toString());
      cell.clear();
    }

    void endRow() {
      endCell();
      rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == separator) {
        endCell();
      } else if (ch == '\n') {
        endRow();
      } else if (ch != '\r') {
        cell.write(ch);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  static List<List<String>> _xlsxRows(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('엑셀 파일을 열지 못했어요.');
    }

    String? read(String name) {
      final file = archive.findFile(name);
      final data = file?.readBytes();
      return data == null ? null : utf8.decode(data);
    }

    final sheetName = archive.files
        .where((f) =>
            f.isFile &&
            f.name.startsWith('xl/worksheets/') &&
            f.name.endsWith('.xml'))
        .map((f) => f.name)
        .toList()
      ..sort();
    final sheetXml = sheetName.isEmpty ? null : read(sheetName.first);
    if (sheetXml == null) throw const FormatException('시트를 찾지 못했어요.');

    final sharedXml = read('xl/sharedStrings.xml');
    final shared = sharedXml == null
        ? const <String>[]
        : [
            for (final si in XmlDocument.parse(sharedXml).findAllElements('si'))
              si.findAllElements('t').map((t) => t.innerText).join(),
          ];

    final rows = <List<String>>[];
    for (final rowElement
        in XmlDocument.parse(sheetXml).findAllElements('row')) {
      final row = <String>[];
      for (final c in rowElement.findElements('c')) {
        final at = _columnIndex(c.getAttribute('r') ?? '');
        while (row.length < at) {
          row.add('');
        }
        final type = c.getAttribute('t');
        final value = c.getElement('v')?.innerText ?? '';
        final text = switch (type) {
          's' => shared.elementAtOrNull(int.tryParse(value) ?? -1) ?? '',
          'inlineStr' => c.findAllElements('t').map((t) => t.innerText).join(),
          _ => value,
        };
        if (at < row.length) {
          row[at] = text;
        } else {
          row.add(text);
        }
      }
      rows.add(row);
    }
    return rows;
  }

  static String _columnName(int index) {
    var n = index + 1;
    var name = '';
    while (n > 0) {
      final rest = (n - 1) % 26;
      name = String.fromCharCode(65 + rest) + name;
      n = (n - 1) ~/ 26;
    }
    return name;
  }

  /// `B3` 같은 셀 주소의 열을 0부터 센 번호로 바꾼다. 주소가 없으면 0.
  static int _columnIndex(String ref) {
    var index = 0;
    for (final unit in ref.toUpperCase().codeUnits) {
      if (unit < 65 || unit > 90) break;
      index = index * 26 + (unit - 64);
    }
    return index == 0 ? 0 : index - 1;
  }
}
