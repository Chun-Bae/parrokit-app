// 질문 보상 안내(5차): 보유량과 언제 빠지는지, 모자라면 얼마나 모자란지.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/question/presentation/question_write_screen.dart';

void main() {
  test('넉넉하면 보유량과 어디로 가는지', () {
    expect(rewardNote(44900, 100),
        '보유 44,900 · 질문을 올리면 바로 빠지고, 채택한 답변에 그대로 가요.');
  });

  test('모자라면 모자란 만큼', () {
    expect(rewardNote(50, 300), '보유 50 · 크래커가 250개 모자라요.');
    expect(rewardNote(1200, 5000), '보유 1,200 · 크래커가 3,800개 모자라요.');
  });
}
