# 안 쓰는 파일 후보 (5차 반복 56, 2026-11-13)

`lib/` 안에서 어떤 파일도 import·export·part 하지 않는 Dart 파일이다(테스트에서도 안 씀).
지우지 않았다. 지우려면 사용자 승인이 필요하다(dead-code-cleanup 규칙).
확인 방법: 파일 이름으로 `import '...파일이름'`을 찾는 스크립트(생성 파일 *.g.dart 제외).

## 예전 화면·위젯 (새 디자인으로 바뀌며 떨어져 나간 것)
- lib/features/home/dashboard/presentation/sections/quick_actions_section.dart
- lib/features/home/dashboard/presentation/widgets/character_info_sheet.dart
- lib/features/home/dashboard/presentation/widgets/idle_bird_preview.dart
- lib/features/collection/shell/presentation/widgets/collection_header_delegate.dart
- lib/features/collection/library/presentation/widgets/episode_list.dart
- lib/features/collection/library/domain/clip_meta.dart
- lib/features/settings/more/presentation/sections/player_settings_section.dart
- lib/features/settings/more/presentation/sections/shorts_settings_section.dart
- lib/features/settings/more/presentation/widgets/status_badge.dart
- lib/features/settings/more/presentation/widgets/avatar_selection_sheet.dart

## 결제·프리미엄 (결제를 붙이면 쓸 수 있음)
- lib/features/settings/more/presentation/sections/payment_section.dart
- lib/features/settings/more/presentation/sections/coin_store_section.dart
- lib/features/settings/more/presentation/widgets/premium_dialog.dart

## 커뮤니티 (지금 화면은 다른 위젯을 씀)
- lib/features/community/vote/presentation/sections/vote_comments_section.dart
- lib/features/community/vote/presentation/widgets/vote_sticky_comment_bar.dart
- lib/features/community/board/presentation/widgets/board_sheet_action.dart
- lib/features/community/question/presentation/sections/question_replies_section.dart
- lib/features/community/question/presentation/widgets/question_sticky_reply_bar.dart
- lib/data/models/answer.dart
- lib/data/models/report.dart (예전 신고 모델. 지금 신고는 community_report_repository.dart)

## 자막(콘텐츠 제작) — 앱에서 직접 OpenAI를 부르던 시절 코드, 지금은 서버 함수가 함
- lib/features/content-studio/captioning/data/adapters/openai_llm_adapter.dart
- lib/features/content-studio/captioning/data/adapters/openai_whisper_asr_adapter.dart
- lib/features/content-studio/captioning/data/usecases/transcribe_usecase.dart
- lib/features/content-studio/captioning/domain/models/native_title_result.dart
- lib/features/content-studio/captioning/presentation/widgets/input_card.dart

## 그 밖
- lib/core/shared/utils/send_mail.dart (메일 보내기, flutter_email_sender)
- lib/core/infrastructure/services/device_id_service.dart
- lib/core/infrastructure/services/firebase/sync_status.dart

지우면 쓰지 않게 되는 패키지(flutter_email_sender 등)도 pubspec에서 뺄 수 있는지 함께 본다.

## 쓰이는 파일 안에 섞여 있는 안 쓰는 위젯 (5차 반복 169)

파일 단위로는 안 보인다. `python3 tool/find_unused_widgets.py`가 찾는다.
선언 파일 밖에서 아무도 만들지 않는 위젯만 적는다(grep으로 한 번 더 확인함).

- `AutoNextButton` — lib/features/collection/clip/shorts/presentation/widgets/action_icon.dart
  쇼츠 자동 넘김은 지금 같은 파일의 `ActionIcon`으로 그린다. 이 위젯은 아무도 안 만든다
- `HeaderSection` — lib/features/home/dashboard/presentation/sections/header_section.dart
  새 홈의 머리(이름·레벨·XP)가 대신한다
- `QuickActionButton` — lib/features/home/dashboard/presentation/widgets/quick_action_button.dart
  예전 홈의 빠른 동작 줄과 함께 떨어져 나갔다(quick_actions_section.dart도 위 목록에 있다)
- `TodayPracticeSummary` — lib/features/home/dashboard/presentation/widgets/today_practice_summary.dart
  **같은 파일의 `DailyGoalDialog`는 지금도 쓴다.** 목표를 바꾸는 길이 이 위젯뿐이어서
  한동안 목표가 5에 묶여 있었다(반복 168에서 '오늘' 줄에 다시 이었다). 지울 때 창은 남겨야 한다

오탐(같은 파일 안에서 쓴다): `SentenceImportSheet`, `WordReviewSheet`, `ModelOptionCard`,
`FeatureChip`, `PracticeReminderSheet`.
의도한 보관(결제를 붙이면 쓴다): `CoinStoreSection`, `PaymentSection`.

