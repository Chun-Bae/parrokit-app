import 'package:intl/intl.dart';

/// 환전소의 빠른 수량 칩(1·5·10·전부)을 지금 누를 수 없는 까닭.
/// 누를 수 있으면 null.
///
/// 예전에는 가진 것보다 많은 칩을 흐리게 두고 누를 수도 없게 해서, 눌러도
/// 아무 일이 없었다(5차, 플레이어 '한 줄씩 멈춤'과 같은 문제).

String _josaIGa(String word) {
  if (word.isEmpty) return '이';
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return '이';
  return (code - 0xAC00) % 28 == 0 ? '가' : '이';
}

String _josaEunNeun(String word) {
  if (word.isEmpty) return '은';
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return '은';
  return (code - 0xAC00) % 28 == 0 ? '는' : '은';
}

String _n(int value) => NumberFormat.decimalPattern('ko').format(value);

/// 정해진 수량 칩(1·5·10 또는 1,000·5,000·10,000).
String? quickStepBlockedReason({
  required String unit,
  required int balance,
  required int step,
}) {
  if (step <= balance) return null;
  return '$unit${_josaIGa(unit)} ${_n(balance)}개뿐이라 ${_n(step)}개는 못 바꿔요.';
}

/// '전부' 칩. [unitSize]는 한 번에 바꿀 수 있는 단위(패롯 1, 크래커 1,000).
String? quickAllBlockedReason({
  required String unit,
  required int balance,
  required int unitSize,
}) {
  if (balance <= 0) return '바꿀 $unit${_josaIGa(unit)} 없어요.';
  if (balance < unitSize) {
    return '$unit${_josaEunNeun(unit)} ${_n(unitSize)}개 단위로 바꿔요. '
        '지금은 ${_n(balance)}개예요.';
  }
  return null;
}
