# 코드 리뷰 진행 체크리스트

대상: `git ls-files 'lib/**/*.dart'` = 489개 파일.
feature 단위로 묶고, 파일 수와 최근 3개월 변경 빈도를 함께 보고 순서를 정했다.
정확성 버그가 실제 피해로 이어지는 상태·데이터 계층을 앞에 두고,
그다음 변경이 잦았던 화면 코드를 본다.

## 기준선

- `flutter analyze` → No issues found
- `flutter test` → 188개 전부 통과

## 묶음 목록

| # | 묶음 | 경로 | 파일 | 상태 |
|---|------|------|------|------|
| 1 | 상태·도메인 | `lib/core/state`, `lib/core/domain` | 30 | 완료 (고침 6, 보류 4) |
| 2 | 데이터 | `lib/data/local`, `lib/data/models` | 27 | 대기 |
| 3 | 커뮤니티 셸 | `lib/features/community/shell` | 25 | 대기 |
| 4 | 자막 제작 | `lib/features/content-studio/captioning` | 58 | 대기 |
| 5 | 홈 | `lib/features/home` | 31 | 대기 |
| 6 | 보관함 | `lib/features/collection` | 54 | 대기 |
| 7 | 커뮤니티 글·질문·투표 | `lib/features/community/{board,question,vote,shared}` | 32 | 대기 |
| 8 | 커뮤니티 알림·활동·메뉴·차단 | `lib/features/community/{notification,activity,menu,block}` | 42 | 대기 |
| 9 | TTS | `lib/features/content-studio/tts` | 25 | 대기 |
| 10 | 챗봇·영상·허브 | `lib/features/content-studio/{chat-bot,video,hub,shared}` | 32 | 대기 |
| 11 | 공용 위젯·테마 | `lib/core/shared` | 41 | 대기 |
| 12 | 앱 셸·라우터·인프라 | `lib/core/{app,infrastructure,content,speech}` | 51 | 대기 |
| 13 | 설정·더보기 | `lib/features/settings` | 37 | 대기 |
| 14 | 인증 | `lib/features/auth` | 4 | 대기 |

## 함께 처리할 남은 일 (어젯밤 UI 작업에서 넘어온 것)

`.claude/ui-audit.md`에 적힌 코드 수준 항목. 해당 묶음을 볼 때 같이 본다.

- 생숫자 반지름 75곳 (6/10/18/30/32…) → 묶음별로 처리
- `AppCard` 추출 (`BoxDecoration` 276곳) → 묶음 11에서 판단
- `AppSheet` 추출 (시트 36곳) → 묶음 11에서 판단
- `AppSectionHeader` → 묶음 11에서 판단
- 폼 입력 두 가지 패턴 통일 → 묶음 13, 14에서 판단
- 영상 오버레이 토큰 (`onVideo`/`onVideoMuted`/`videoScrim`) → 묶음 10
- "좋아요" 색 세 가지 → 묶음 7

## 눈으로 못 보는 것

인증 네 화면(로그인·회원가입·비밀번호 찾기·온보딩)은 로그인 상태라 시뮬레이터로 못 띄운다.
묶음 14는 코드 리뷰만 하고 UI 확인은 미확인으로 남긴다.
