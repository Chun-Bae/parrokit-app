# 3차 작업 체크리스트

시작: 2026-11-12. 루프 프롬프트는 사용자가 준 "Parrokit 3차 작업".

## 기준선 (시작 시점, 커밋 b2c21b39)

| 검사 | 결과 |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 219 passed |
| `functions` `npm run lint` | 0 errors, 7 warnings (전부 원래 있던 것) |
| `functions` `npm run build` | 통과 |
| `test_rules` `npm test` | 31/31 |

## A. 남은 문제

- [x] A1 CommunityProvider·VideoProvider 의존성 주입 + 되돌리기 회귀 테스트 5개
- [x] A2 백업 압축 분리 + "DB 없이 완료" 회귀 테스트
- [x] A3 게시판·질문·투표 무한 스크롤
- [x] A4 네이버 토큰 발급 앱 확인 조사
- [x] A5 App Check 준비 (enforce 끄고)
- [x] A6 패롯·크래커 서버 이전 설계 문서
- [x] A7 네이버 이메일 중복 선택지 정리
- [ ] A8 작업 중 본 확실한 버그 (발견하는 대로 아래에 적는다)
- [x] 투표 종료 스케줄러: 2차 보류에 "의도한 설계, 유지" 표시

## B. UI/UX 개편과 통일

이전 밤 작업(ui-decisions.md 1~17)에서 세그먼트·빈 상태·뒤로가기·바텀시트 방식·
반지름 일부는 이미 통일됐다. 이번에는 그 "남은 일"을 토대로 삼고 화면을 돈다.

### B0 토대 (공용 컴포넌트)
- [ ] 토큰 점검: 색·글자·간격·반지름·그림자 현황표를 ui-decisions.md에 적는다
- [ ] AppCard (표면색 + 반지름 + 테두리 패턴)
- [ ] AppSheet (드래그 핸들 + 제목 + 설명)
- [ ] AppSectionHeader (제목 + 부제 + 오른쪽 버튼)
- [ ] 로딩·오류 표시 통일
- [ ] 좋아요 색 하나로
- [ ] 영상 위 UI 토큰 (onVideo 등)

### B1 화면 (많이 쓰는 순)
- [ ] 홈 대시보드 (character_dashboard_screen, learning_hub_screen)
- [ ] 학습 무대 (stage_preview_screen, add_sentence_screen)
- [ ] 최근 (recent_screen)
- [ ] 보관함 셸 + 문장·단어 (collection_shell_screen, sentence/word_collection_preview)
- [ ] 클립 라이브러리 (library_screen, clip_discover_screen)
- [ ] 클립 플레이어·쇼츠 (clip_player_screen, shorts_screen)
- [ ] 커뮤니티 셸 + 게시판 목록 (community_shell_screen, board_screen)
- [ ] 게시글 보기·쓰기 (board_view_screen, board_write_screen)
- [ ] 질문 목록·보기·쓰기
- [ ] 투표 목록·보기·쓰기
- [ ] 활동·알림·메뉴·차단 (activity, notification, menu, blocked_users)
- [ ] 더보기 (more_screen)
- [ ] 프로필 편집·환전·저장공간·웹문서
- [ ] 콘텐츠 제작 허브·브리지
- [ ] 자막 만들기 (captioning_screen)
- [ ] TTS (tts_screen)
- [ ] 영상 (video_screen)
- [ ] 오프라인 화면
- [ ] auth 네 화면 (코드만, UI 미확인)

## C. 기능 안건
- [ ] feature-proposals.md 만들기
- [ ] 비활성 버튼 11개 각각의 안
- [ ] 마무리 정리 (상위 5개)

## 기록

### 0단계 (2026-11-12)
기준선 측정 완료. 개편 전 스크린샷은 `.claude/round3-shots/before/`에 있다
(쇼츠·홈·커뮤니티·보관함·더보기 × 라이트·다크). 이 폴더는 `.git/info/exclude`로
커밋에서 뺐다. 시뮬레이터 외형은 다크로 두었고 앱 테마 설정은 원래부터 "시스템"이다.

개편 전 화면에서 눈에 띈 것 (B에서 다룬다):
- 주색이 둘이다. 홈은 청록(진행 막대, 소리 버튼, Lv 글자)이고 나머지 화면과
  탭바는 파랑이다. 앱 하나에 브랜드색 두 개
- 다크에서 보관함 "Parrokit 제공" 카드의 "공식" 배지가 글자 없는 흰 알약으로 보인다
- 홈 아래쪽 학습 기록 카드가 떠 있는 탭바 밑으로 들어가 잘린다(스크롤하면 보이니 버그는 아님)

### A1~A3 (2026-11-12)
- A1 `07a506d5`, `21bc0b2e`: Provider 주입. 되돌리기 테스트 5개, 고치기 전 코드로 되돌리면 5개 모두 실패
- A2 `593c80e1`: 백업 압축 공개 + 테스트 3개. 옛 동작이면 2개 실패
- A3 `bcc53d1f`: 무한 스크롤. 페이지 크기 1로 시뮬레이터 확인(게시판). 실제 Firestore에서
  커서가 동작한다. 2차 보고의 "커서 미확인"이 이걸로 풀렸다. 질문·투표 글이 하나도 없어서
  그 두 목록의 버튼은 눈으로 못 봤다
- A8 `d4506094`: 투표 완료·만료 필터의 빈 화면 문구
- 확인 중 게시글 하나(봄배 "안녕하세요")를 열어서 조회수가 12→13이 됐다. 글을 여는 것만으로
  올라가는 값이라 피할 수 없었다. 그 밖에 실제 커뮤니티에 쓴 것은 없다
- A4: 조사만. OIDC id_token(aud 검사)이 정석. 앱·함수 동시 배포가 필요해 보류. review-findings.md에 적었다
- A5 `800ffb60`: 함수 쪽 스위치만(false). 앱 패키지는 FlutterFire 전체 업그레이드가 필요해 넣지 않았다. 순서는 review-findings.md
- A6: 설계만 review-findings.md에. 같은 경로의 확실한 버그 둘은 고쳤다: `0c594a3b`(캐시 크래커 덮어쓰기), `2e11e91d`(Apple 기본 잔액)
- A7: 선택지 넷(A~D)과 추천(C 다음 D)을 review-findings.md에
