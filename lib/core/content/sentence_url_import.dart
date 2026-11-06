import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 주소(URL)에서 CSV·엑셀(xlsx) 파일을 내려받아 문장으로 가져올 때 쓰는 도우미.
class SentenceUrlImport {
  const SentenceUrlImport._();

  /// 너무 큰 파일은 받지 않는다.
  static const maxBytes = 5 * 1024 * 1024;
  static const timeout = Duration(seconds: 15);

  /// 입력한 주소를 내려받을 주소로 바꾼다. https 주소만 허용한다.
  /// 구글 스프레드시트 공유 주소(`/spreadsheets/d/<id>/edit#gid=0`)는 CSV 내보내기 주소로 바꾼다.
  /// 쓸 수 없는 주소면 [FormatException]을 던진다.
  static Uri downloadUri(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('https로 시작하는 주소만 쓸 수 있어요.');
    }
    final sheet = RegExp(r'^/spreadsheets/d/([\w-]+)').firstMatch(uri.path);
    if (uri.host == 'docs.google.com' && sheet != null) {
      final gid =
          RegExp(r'gid=(\d+)').firstMatch('${uri.query}&${uri.fragment}');
      return Uri.https(
          'docs.google.com', '/spreadsheets/d/${sheet.group(1)}/export', {
        'format': 'csv',
        if (gid != null) 'gid': gid.group(1)!,
      });
    }
    return uri;
  }

  /// [uri]의 내용을 내려받는다. 시간이 지나거나 [maxBytes]를 넘으면 예외를 던진다.
  static Future<Uint8List> fetch(Uri uri) async {
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('status ${response.statusCode}', uri);
    }
    if (response.bodyBytes.length > maxBytes) {
      throw const FormatException('파일이 너무 커요.');
    }
    return response.bodyBytes;
  }
}
