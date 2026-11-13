import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

/// 예외를 사용자에게 보일 한 줄로 바꾼다.
///
/// 예전에는 '저장 실패: $e'처럼 예외 원문(영어, 파일 경로, 클래스 이름)을 그대로
/// 토스트에 띄웠다(5차). 앱이 직접 한국어로 적은 이유는 살리고, 나머지는
/// [fallback]으로 대신한다. 원문은 부르는 쪽에서 로그로 남긴다.
String userErrorMessage(Object error, {required String fallback}) {
  if (error is SocketException || error is TimeoutException) {
    return _network;
  }
  // Firebase 오류는 영어 문장이라 코드로 고른다(FirebaseAuthException 포함).
  if (error is FirebaseException) {
    return switch (error.code) {
      'network-request-failed' || 'unavailable' => _network,
      'too-many-requests' => '요청이 너무 많아요. 잠시 뒤 다시 시도해 주세요.',
      'requires-recent-login' => '보안을 위해 로그아웃 후 다시 로그인한 뒤 시도해 주세요.',
      _ => fallback,
    };
  }
  final raw = switch (error) {
    StateError(:final message) => message,
    ArgumentError(:final message) => '${message ?? ''}',
    _ => error.toString(),
  };
  final text = raw
      .replaceFirst(
          RegExp(r'^(Exception|Bad state|Invalid argument\(s\)): ?'), '')
      .trim();
  // 한국어로 적힌 짧은 이유만 쓴다. 경로·영어 원문이 섞이면 대신 말을 쓴다.
  final hasHangul = RegExp(r'[가-힣]').hasMatch(text);
  if (!hasHangul || text.contains('/') || text.length > 80) return fallback;
  return text;
}

const _network = '인터넷 연결을 확인하고 다시 시도해 주세요.';
