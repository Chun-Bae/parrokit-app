// ============================================================================
// lib/features/player/domain/player_state.dart
// ============================================================================
//
// [역할]
// 플레이어 관련 상태 enum 및 상수 정의.
//
// [레이어]
// Domain Layer
// ============================================================================

import 'package:parrokit/core/shared/utils/speed_label.dart';

/// 재생 범위 (세그먼트/전체)
enum PlayScope { segment, full }

/// 재생 모드 (비디오/오디오 전용)
enum PlayMode { video, audioOnly }

/// 지원하는 재생 속도 목록
class PlaybackRates {
  PlaybackRates._();

  static const List<double> values = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  static const double defaultRate = 1.0;
  static const double minRate = 0.5;
  static const double maxRate = 2.0;

  /// 속도 표시 문자열 (예: "1배"). 화면마다 다르게 적지 않도록 공용 함수를 쓴다.
  static String label(double rate) => speedLabel(rate);
}
