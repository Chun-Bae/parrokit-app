// ============================================================================
// lib/core/shared/utils/operator_access.dart
// ============================================================================
//
// [역할]
// 운영자(관리자) 계정 판별. 유료화 전 기능 잠금(서버 스토리지 등), 보관
// 기간 무제한 처리 등 여러 기능에서 공통으로 쓰이는 운영자 UID 목록.
//
// [레이어]
// Core > Shared > Utils
// ============================================================================

const Set<String> operatorUids = {
  'dDsWhAQWQxfCWI4xHIayCkjLD662',
  'naver:iDj5CROn8PODq_1sTN1Yjt2tvaaKiJUppIfKR5-IXmA',
};

bool isOperatorUid(String? uid) {
  return uid != null && operatorUids.contains(uid);
}
