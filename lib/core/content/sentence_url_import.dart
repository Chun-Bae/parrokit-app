import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 주소로 가져오기에 실패한 이유. [message]는 그대로 사용자에게 보여줘도 된다.
class SentenceUrlException implements Exception {
  const SentenceUrlException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 주소(URL)에서 CSV·엑셀(xlsx) 파일을 내려받아 문장으로 가져올 때 쓰는 도우미.
class SentenceUrlImport {
  const SentenceUrlImport._();

  /// 너무 큰 파일은 받지 않는다.
  static const maxBytes = 5 * 1024 * 1024;
  static const timeout = Duration(seconds: 15);

  /// 입력한 주소를 내려받을 주소로 바꾼다. https 주소만 허용한다.
  /// 구글 스프레드시트 공유 주소(`/spreadsheets/d/<id>/edit#gid=0`)는 CSV 내보내기 주소로 바꾼다.
  /// 쓸 수 없는 주소면 [SentenceUrlException]을 던진다.
  static Uri downloadUri(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const SentenceUrlException('https로 시작하는 주소만 쓸 수 있어요.');
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

  /// 아이클라우드 드라이브 공유 주소(`https://www.icloud.com/iclouddrive/<코드>#이름`)인지.
  static bool isICloudShare(Uri uri) =>
      uri.host == 'www.icloud.com' &&
      uri.pathSegments.length >= 2 &&
      uri.pathSegments.first == 'iclouddrive';

  /// [uri]의 내용을 내려받는다. 시간이 지나거나 [maxBytes]를 넘으면 예외를 던진다.
  /// 아이클라우드 공유 주소는 파일 주소를 먼저 찾아서 내려받는다.
  static Future<Uint8List> fetch(Uri uri, {http.Client? client}) async {
    final http_ = client ?? http.Client();
    try {
      final target =
          isICloudShare(uri) ? await _resolveICloud(uri, http_) : uri;
      final response = await http_.get(target).timeout(timeout);
      if (response.statusCode != 200) {
        throw http.ClientException('status ${response.statusCode}', target);
      }
      if (response.bodyBytes.length > maxBytes) {
        throw const SentenceUrlException('파일이 너무 커요. 5MB까지 가져올 수 있어요.');
      }
      return response.bodyBytes;
    } finally {
      if (client == null) http_.close();
    }
  }

  /// 아이클라우드 공유 코드로 실제 파일을 받을 수 있는 주소를 찾는다.
  /// 애플이 문서로 공개한 방법이 아니라서 나중에 바뀌면 실패할 수 있다. 폴더 링크는 지원하지 않는다.
  static Future<Uri> _resolveICloud(Uri share, http.Client client) async {
    const fail = SentenceUrlException(
        '아이클라우드 링크에서 파일을 찾지 못했어요. 폴더가 아니라 파일 하나를 "링크가 있는 모든 사용자"로 공유했는지 확인해주세요.');
    final response = await client
        .post(
          Uri.parse('https://ckdatabasews.icloud.com/database/1/'
              'com.apple.cloudkit/production/public/records/resolve'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'shortGUIDs': [
              {'value': share.pathSegments[1]}
            ]
          }),
        )
        .timeout(timeout);
    if (response.statusCode != 200) throw fail;
    try {
      final result = (jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>)['results'][0] as Map<String, dynamic>;
      final content = result['rootRecord']['fields']['fileContent']['value']
          ['downloadURL'] as String;
      final url = Uri.parse(content.replaceAll(r'${f}', 'file'));
      if (url.scheme != 'https') throw fail;
      return url;
    } on SentenceUrlException {
      rethrow;
    } catch (_) {
      throw fail;
    }
  }
}
