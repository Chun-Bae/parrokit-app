import 'package:parrokit/core/shared/utils/network_error.dart';

/// 음성 만들기가 실패했을 때 화면에 띄울 말(5차 311).
///
/// 전에는 예외 글을 그대로 담아서 '미리 듣기' 아래에
/// `[firebase_functions/failed-precondition] 보유하신 패롯이 부족합니다.`처럼
/// 대괄호가 붙은 글이 그대로 떴다. 예외는 로그에만 남긴다.
String ttsErrorText(Object error) {
  if (looksOffline(error)) {
    return offlineMessage;
  }
  final message = _serverMessage(error);
  if (message.contains('패롯') && message.contains('부족')) {
    return '패롯이 모자라요. 더 채우고 다시 해 주세요.';
  }
  if (looksPermissionDenied(error)) {
    return '지금은 할 수 없어요. 로그인 상태를 확인하고 다시 해 주세요.';
  }
  return '음성을 만들지 못했어요. 잠시 뒤 다시 해 주세요.';
}

/// `[firebase_functions/코드] 사람 말` 꼴에서 뒤쪽만 꺼낸다.
String _serverMessage(Object error) {
  final text = error.toString();
  final close = text.indexOf('] ');
  if (text.startsWith('[') && close > 0) {
    return text.substring(close + 2).trim();
  }
  return text.replaceFirst('Exception: ', '').trim();
}

/// 목소리 목록을 못 받았을 때. 엔진별 시트 둘이 같은 말을 쓴다(5차 444).
const String voiceListLoadFailedMessage = '목소리 목록을 불러오지 못했어요.';
