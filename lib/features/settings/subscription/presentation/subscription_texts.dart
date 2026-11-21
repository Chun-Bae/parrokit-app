// 구독 화면의 글귀. 한 곳에 모아 둔다(.claude/subscription-ux.md와 같은 말).

import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/shared/utils/calendar_date_label.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_state.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_quota.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';

/// 단계 이름. 더보기 줄과 구독 화면이 같은 말을 쓴다.
String subscriptionTierName(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      return '무료';
    case SubscriptionTier.light:
      return '라이트';
    case SubscriptionTier.plus:
      return '플러스';
    case SubscriptionTier.pro:
      return '프로';
    case SubscriptionTier.max:
      return '맥스';
  }
}

/// 더보기 '구독' 줄의 부제.
String subscriptionRowSubtitle(SubscriptionTier tier) =>
    tier == SubscriptionTier.free ? '광고 없이, 매달 패롯을 받아요.' : '구독 중이에요. 눌러서 관리해요.';

const String subscriptionScreenTitle = '구독';

/// 하루 한도를 다 썼을 때 무료 사용자에게 보여 주는 한 줄.
/// 숫자는 서버 설정에서 바뀔 수 있어서 적지 않는다.
const String assistQuotaUpsellText = '구독하면 하루에 더 많이 채울 수 있어요.';

/// 구독 화면으로 가는 버튼 이름. 여러 화면에서 같은 말을 쓴다.
const String subscriptionOpenButtonLabel = '구독 보기';

/// 구독하지 않은 사람에게 보여 주는 머리말.
const String subscriptionFreeHeadline = '지금 무료예요';
const String subscriptionFreeBody = '광고를 보고 패롯 3개를 받고 있어요.';

/// 단계별 혜택. 값은 스토어가 주는 것을 쓰고, 여기 적은 값은 미리보기용이다.
class SubscriptionTierCopy {
  const SubscriptionTierCopy({
    required this.tier,
    required this.previewPrice,
    required this.firstLine,
  });

  final SubscriptionTier tier;
  final String previewPrice;

  /// 그 단계만의 첫 줄. 나머지 혜택은 값에서 만든다.
  final String firstLine;

  String get name => subscriptionTierName(tier);
  String get startLabel => '$name 시작하기';

  /// 혜택 줄. 패롯 수와 저장 용량은 적어 두지 않고 한 곳에서 가져온다.
  /// 예전에는 여기 '매달 패롯 100개'처럼 박아 둬서, 서버 값을 바꾸면
  /// 화면이 거짓말을 하게 돼 있었다(5차).
  List<String> get benefits => [
        firstLine,
        '매달 패롯 ${monthlyParrotsFor(tier)}개',
        '서버 백업 ${serverStorageQuotaLabel(tier)}',
        // 뜻·발음과 예문은 **서로 다른 축**이다. 하나를 써도 다른 쪽이
        // 깎이지 않는다. 전에는 예문만 숫자를 적고 뜻·발음은 '한도가
        // 늘어요'로 뭉뚱그려서, 두 가지가 있다는 것도 얼마나 되는지도
        // 알 수 없었다(5차 531).
        '$fillBasicsLabel 하루 ${dailyAssistFor(tier)}번',
        '예문 생성 하루 ${dailyExamplesFor(tier)}개',
        '한 낱말에 예문 ${examplesPerWordFor(tier)}개까지',
      ];
}

const List<SubscriptionTierCopy> subscriptionTiers = [
  SubscriptionTierCopy(
    tier: SubscriptionTier.light,
    previewPrice: '월 ₩4,000',
    firstLine: '광고 없이',
  ),
  SubscriptionTierCopy(
    tier: SubscriptionTier.plus,
    previewPrice: '월 ₩7,000',
    firstLine: '라이트에 더해',
  ),
  SubscriptionTierCopy(
    tier: SubscriptionTier.pro,
    previewPrice: '월 ₩10,000',
    firstLine: '플러스에 더해',
  ),
  SubscriptionTierCopy(
    tier: SubscriptionTier.max,
    previewPrice: '월 ₩20,000',
    firstLine: '프로에 더해, 클립 수백 개도 거뜬히',
  ),
];

/// 스토어 심사가 요구하는 안내. 구독 화면에 늘 보인다.
const String subscriptionRenewalNotice =
    '언제든 스토어에서 해지할 수 있어요. 해지하지 않으면 매달 자동으로 결제돼요.';
/// 받은 패롯이 어떻게 되는지(5차 529).
///
/// 전에는 '그달 안에 써요. 남으면 다음 달로 넘어가지 않아요'라고 적었는데
/// 서버는 그렇게 하지 않는다. expireSubscriptionParrots는 status가
/// 'expired'일 때만 남은 것을 지우고, 갱신(active)에서는 지우지 않은 채
/// 다음 기간 몫을 더한다. 그래서 안 쓰면 달마다 쌓인다.
///
/// 기간 소멸은 필요 없다고 정했으므로(사용자), 화면이 실제 동작을 적는다.
const String subscriptionParrotNotice = '받은 패롯은 다음 달로 넘어가요. 구독이 끝나면 남은 것은 사라져요.';
const String subscriptionRestoreLabel = '이미 구독했다면 구매 복원';

/// 아직 스토어에 상품이 없을 때.
const String subscriptionPreviewNotice = '아직 구독 상품을 준비하는 중이에요. 화면만 미리 보고 있어요.';
const String subscriptionNotReadyToast = '아직 구독 상품이 없어요. 준비되면 여기서 시작할 수 있어요.';

/// 이미 구독 중이라 구독 화면이 뜨지 않을 때(5차 355).
const String subscriptionAlreadyToast = '이미 구독 중이에요. 자세한 것은 구독 칸에서 볼 수 있어요.';

/// 구독 화면을 여는 데 실패했을 때.
const String subscriptionOpenFailedToast = '구독 화면을 열지 못했어요. 잠시 뒤 다시 해 주세요.';

/// 구매 복원 결과(5차 356).
const String subscriptionRestoreDoneToast = '구매를 복원했어요.';
const String subscriptionRestoreNoneToast = '복원할 구독을 찾지 못했어요.';
const String subscriptionRestoreFailedToast =
    '구매를 복원하지 못했어요. 인터넷을 확인하고 다시 해 주세요.';

// ─── 구독 중 화면 ───────────────────────────────────────────────
// 글귀는 .claude/subscription-ux.md 3-3과 같다.

/// 다음 결제일 한 줄. 기간 끝을 모르면 null.
///
/// 날짜는 앱의 다른 곳과 같은 규칙을 쓴다(해가 넘어가면 연도까지). 12월에
/// 보는 '1월 5일'이 올해인지 내년인지 알 수 없었다(5차).
String? subscriptionRenewalLine(DateTime? periodEnd, {DateTime? now}) =>
    periodEnd == null
        ? null
        : '다음 결제일 ${calendarDateLabel(periodEnd, now ?? DateTime.now())}';

/// 상태별 안내 한 줄. 멀쩡하면 null.
String? subscriptionStatusNotice(SubscriptionStatus status, DateTime? periodEnd,
    {DateTime? now}) {
  switch (status) {
    case SubscriptionStatus.grace:
      return '결제가 밀렸어요. 스토어에서 결제 수단을 확인해 주세요.';
    case SubscriptionStatus.canceled:
      final when = periodEnd == null
          ? '기간이 끝나면'
          : '${calendarDateLabel(periodEnd, now ?? DateTime.now())}에';
      return '$when 끝나요. 그때까지는 그대로 쓸 수 있어요.';
    case SubscriptionStatus.expired:
      return '구독이 끝났어요. 받아 둔 영상은 기기에 남아 있어요.';
    case SubscriptionStatus.active:
      return null;
  }
}

/// 남은 양을 '62 / 100 남음'으로 적는다. 쓴 양이 아니라 남은 양이다.
String subscriptionRemainingText(int left, int total) => '$left / $total 남음';

const String subscriptionManageLabel = '구독 관리';
const String subscriptionRestoreButtonLabel = '구매 복원';
/// 올리기 단추 이름(5차 520).
///
/// 전에는 '프로로 올리기'로 박혀 있었다. 단계가 넷으로 늘면서 맥스가 아닌
/// 모든 사람에게 이 단추가 뜨는데, 프로를 쓰는 사람도 '프로로 올리기'를
/// 보게 됐다. 누르면 특정 단계로 가는 것도 아니고 단계 목록이 열린다.
/// 어느 단계에서 봐도 맞는 말로 적는다.
const String subscriptionUpgradeLabel = '단계 올리기';
const String subscriptionParrotRowTitle = '이번 달 패롯';
const String subscriptionStorageRowTitle = '서버 백업';
