// 패롯으로 예문 몫을 사는 길(5차 532, 사용자 요청).
//
// 하루 한도는 날마다 새로 찬다(타이머). 여기서 산 몫은 사라지지 않고,
// 하루 한도를 다 쓴 뒤부터 깎인다. 서버가 한 트랜잭션으로 패롯을 깎고 몫을
// 올리므로, 중간에 끊겨 패롯만 사라지는 일은 없다.

import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

/// 사는 데 기다릴 시간(5차 534).
///
/// 15초(shortCallTimeout)로는 모자랐다. 함수가 쉬다 깨는 첫 호출은
/// index.ts 전체(genkit, TTS 등)를 불러오느라 그보다 오래 걸린다.
/// 기기에서 타임아웃이 났는데 **서버는 끝까지 처리했다** - 패롯은 깎이고
/// 화면은 '사지 못했어요'였다. 돈이 걸린 자리라 넉넉히 기다린다.
const Duration buyCallTimeout = Duration(seconds: 40);

/// 한 묶음 값. 서버 exampleQuota.ts의 EXAMPLE_CREDIT_PACK과 같아야 한다.
const int exampleCreditPackParrots = 3;
const int exampleCreditPackCredits = 10;

/// 뜻·발음 한 묶음. 서버 ASSIST_CREDIT_PACK과 같아야 한다(5차 535).
/// 예문과 같은 3패롯인데 횟수는 절반이다 - 한 번에 뜻과 발음을 함께 받아서
/// 구독에서 역산한 값이 예문 1개의 두 배다.
const int assistCreditPackParrots = 3;
const int assistCreditPackCredits = 5;

/// 묶음 수로 드는 패롯.
int exampleCreditCost(int packs) => exampleCreditPackParrots * packs;

/// 묶음 수로 받는 몫.
int exampleCreditGain(int packs) => exampleCreditPackCredits * packs;

/// 사기 단추에 적을 말(5차 536).
///
/// 무엇을 사는지는 단추 안 그림이 말한다. 글은 **몇 번이 느는지**만
/// 적는다(5차 567, 사용자 요청). 이름까지 넣으면 두 단추가 가로로
/// 나란히 설 자리에 안 들어가, 실기기에서 글씨가 잘렸다.
/// 값은 둘 다 같은 3패롯이라 카드 안내 줄에 한 번만 적는다.
String exampleCreditBuyLabel(int packs) => '+${exampleCreditGain(packs)}';

/// 그림만으로는 읽어 주지 못하는 곳(스크린 리더)에 쓸 말.
String exampleCreditBuySemantics(int packs) =>
    '예문 +${exampleCreditGain(packs)}번';

/// 한 묶음 값. 두 단추가 같은 값이라 안내 줄에 한 번만 적는다.
String creditPackPriceHint(int packs) =>
    '한 묶음에 패롯 ${exampleCreditCost(packs)}개예요.';

int assistCreditCost(int packs) => assistCreditPackParrots * packs;
int assistCreditGain(int packs) => assistCreditPackCredits * packs;

String assistCreditBuyLabel(int packs) => '+${assistCreditGain(packs)}';

/// 그림만으로는 읽어 주지 못하는 곳에 쓸 말.
String assistCreditBuySemantics(int packs) =>
    '$fillBasicsSubject +${assistCreditGain(packs)}번';

/// 뜻·발음 몫을 살 수 없을 때. 살 수 있으면 null.
String? assistCreditBlocked({required int? parrots, int packs = 1}) {
  if (parrots == null) return null;
  if (parrots >= assistCreditCost(packs)) return null;
  return exampleCreditShortMessage(parrots, packs);
}

/// 뜻·발음 몫을 산 뒤 알리는 말.
String assistCreditBoughtMessage(int credits) =>
    '$fillBasicsSubject $credits번을 받았어요.';

/// 패롯이 모자랄 때.
String exampleCreditShortMessage(int have, int packs) =>
    '패롯이 ${exampleCreditCost(packs) - have}개 모자라요. 지금 $have개 있어요.';

/// 응답이 늦을 때. 두 번 깎이지 않는다는 것까지 적는다.
const String exampleCreditSlowMessage =
    '응답이 늦어요. 다시 눌러도 두 번 깎이지 않아요.';

/// 아까 늦게 간 요청이 이미 반영돼 있었을 때.
const String exampleCreditAlreadyMessage = '아까 누른 것이 이미 들어가 있었어요.';

/// 산 뒤 알리는 말.
String exampleCreditBoughtMessage(int credits) => '예문 $credits번을 받았어요.';

/// 살 수 없을 때 적는 말. 살 수 있으면 null.
String? exampleCreditBlocked({required int? parrots, int packs = 1}) {
  if (parrots == null) return null;
  if (parrots >= exampleCreditCost(packs)) return null;
  return exampleCreditShortMessage(parrots, packs);
}

class ExampleCreditsResult {
  const ExampleCreditsResult({
    required this.credits,
    required this.bought,
    required this.spent,
  });

  /// 산 뒤 가진 몫.
  final int credits;

  /// 이번에 받은 몫. 같은 요청이 두 번 가면 0이다.
  final int bought;

  /// 이번에 쓴 패롯.
  final int spent;
}

/// 패롯이 모자라거나 서버가 막았을 때. 사용자에게 그대로 보여 준다.
class ExampleCreditsFailed implements Exception {
  const ExampleCreditsFailed(this.message);

  final String message;

  @override
  String toString() => message;
}

class ExampleCreditsService {
  ExampleCreditsService({FirebaseFunctions? functions}) : _given = functions;

  final FirebaseFunctions? _given;
  FirebaseFunctions get _functions => _given ?? FirebaseFunctions.instance;

  static final _rand = Random();

  /// 두 번 눌러도 한 번만 사게 하는 요청 id. 서버가 장부 키로 쓴다.
  static String newRequestId() =>
      'ec${DateTime.now().millisecondsSinceEpoch}${_rand.nextInt(1 << 20)}';

  /// [assist]가 true면 뜻·발음 몫을, 아니면 예문 몫을 산다(5차 535).
  Future<ExampleCreditsResult> buy({
    int packs = 1,
    String? requestId,
    bool assist = false,
  }) async {
    try {
      final result = await _functions
          .httpsCallable(assist ? 'buyAssistCredits' : 'buyExampleCredits')
          .call<Map<Object?, Object?>>({
        'packs': packs,
        'requestId': requestId ?? newRequestId(),
      }).timeout(buyCallTimeout);
      final data = Map<String, dynamic>.from(result.data);
      return ExampleCreditsResult(
        credits: ((assist ? data['assistCredits'] : data['exampleCredits'])
                as num?)
            ?.toInt() ??
            0,
        bought: (data['boughtCredits'] as num?)?.toInt() ?? 0,
        spent: (data['spentParrots'] as num?)?.toInt() ?? 0,
      );
    } on FirebaseFunctionsException catch (e) {
      AppLogger.w('[credits] 사지 못했어요: ${e.code} ${e.message}');
      // 서버가 적어 준 까닭(패롯 부족 등)은 그대로 보여 준다.
      throw ExampleCreditsFailed(
        e.code == 'failed-precondition' && (e.message ?? '').isNotEmpty
            ? e.message!
            : '지금은 받지 못했어요. 잠시 뒤 다시 해 주세요.',
      );
    } on TimeoutException catch (e) {
      // 갔는지 안 갔는지 모른다. 서버가 끝냈을 수도 있으므로 '실패'라고
      // 단정하지 않는다. 다시 누르면 같은 requestId로 가서 두 번 깎이지
      // 않는다(5차 534).
      AppLogger.w('[credits] 응답이 늦어요: $e');
      throw const ExampleCreditsFailed(exampleCreditSlowMessage);
    } catch (e) {
      AppLogger.w('[credits] 사지 못했어요: $e');
      throw const ExampleCreditsFailed('지금은 받지 못했어요. 잠시 뒤 다시 해 주세요.');
    }
  }
}
