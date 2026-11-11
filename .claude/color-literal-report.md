# 색 리터럴 정리 보고서

작성: 2026-11-10 · 브랜치 `dev` · 커밋하지 않음 (`git diff`에 unstaged로 남아 있음)

인덱스(staged)에는 타이포 마이그레이션 98개 파일이 그대로 있다.
`git diff`는 이 작업, `git diff --cached`는 타이포 작업이다.

## 검증

| 항목 | 작업 전 | 작업 후 |
|---|---|---|
| `flutter analyze` | No issues found | No issues found |
| `flutter test` | +187 -1 | +187 -1 |

실패 1건은 `test/features/community/shell/domain/usecases/comment_usecases_test.dart`의
`AddCommentUseCase` 테스트로, 이 작업 전부터 실패하던 것이다. 건드리지 않았다.

`Color(0x…)` 리터럴 **145곳 → 40곳** (105곳 제거).
화면에서 밝기 분기 없이 라이트 전용 색을 쓰던 자리 **256곳 → 0곳**.
`isDark ? AppColors.xDark : AppColors.x` 꼴의 밝기 분기 **137곳 축약**.
리터럴이 한 줄에 둘 이상 있는 자리가 있어서, 줄 수가 아니라 리터럴 개수로 센 값이다.

## 새로 만든 파일

| 파일 | 담은 것 |
|---|---|
| `lib/features/content-studio/shared/studio_colors.dart` | 챗봇 모드·AI 공급자 브랜드 색 7개 |
| `lib/features/collection/shared/collection_colors.dart` | 보관함 파스텔·잉크·동작·금색 11항목 |

`AppColors`에 토큰 4개를 추가했다.

| 토큰 | 값 | 쓰는 곳 |
|---|---|---|
| `snackbarSurface` | `0xFF323232` | 스낵바 배경(라이트) |
| `snackbarSurfaceDark` | `0xFF2C3038` | 스낵바 배경(다크) |
| `parrotCurrency` | `0xFF10B981` | 패롯(프리미엄 재화) |
| `crackerCurrency` | `0xFFF59E0B` | 크래커(활동 재화) |

## 바꾼 것

### auth 브랜드 블루 30곳

네 화면이 `Color(0xFF0066FF)`를 직접 적어 쓰고 있었다.
`AppColors.primary`가 `0xFF0064FF`로 사람 눈에 구분되지 않는 값이라 전부 토큰으로 바꿨다.

- `sign_up_screen.dart` 11곳, `sign_in_screen.dart` 10곳,
  `find_pw_screen.dart` 4곳, `onboarding_screen.dart` 5곳

`AppColors.primary`가 `static const`라서 감싸고 있던 `const` 트리가 그대로 유지됐다.
const 전파로 인한 연쇄 오류는 없었다.

`AppTokens.of(context).primary`를 쓰지 않은 이유: 이 네 화면은 `Colors.white` 배경,
`Colors.black` 제목, `Colors.grey.shade400/500/600` 테두리로 라이트 모드 전용으로 짜여 있다.
파란색만 다크 대응으로 바꾸면 흰 배경 위에 다크용 파랑이 올라가 더 어긋난다.
auth 다크 모드는 화면 전체를 함께 바꿀 별도 작업이다.

### content-studio 모드 색 37곳

`StudioColors`로 모았다. 챗봇 모드와 AI 공급자를 구분하는 기능 고유 색이라
`AppTokens`에 넣지 않았다. 16진수 값은 그대로 두었으므로 외형 변화가 없다.

| 상수 | 값 | 뜻 |
|---|---|---|
| `generalPurple` | `0xFF8B5CF6` | 일반 대화 모드 |
| `ttsPink` | `0xFFEC4899` | 음성(TTS) 모드 |
| `videoBlue` | `0xFF3B82F6` | 영상 모드 |
| `purpleLight` | `0xFFC084FC` | 보라 그라디언트의 밝은 끝 |
| `videoCyan` | `0xFF06B6D4` | 영상 그라디언트의 청록 끝 |
| `actionCyan` | `0xFF00C6FF` | 추천 액션 칩의 하늘색 끝 |
| `geminiPurple` | `0xFF9B72CB` | Gemini 음성 선택 |

바뀐 파일: `gradient_helper.dart`(6), `routing_bottom_sheet.dart`(16),
`chat_bubble.dart`(5), `chat_bot_fab.dart`(2), `chat_bot_sheet.dart`(6),
`tts_screen.dart`(2), TTS 선택 시트 3개(각 2).

`chat_bubble.dart`의 `Color(0xFF0052D4)`는 `AppColors.primaryPressed`와 값이 정확히 같아
토큰으로 바꿨다. 이미 같은 그라디언트 안에서 `AppColors.primary`와 짝지어 쓰이던 자리다.

### 보관함 색 17곳

`CollectionColors`로 모았다. 값은 그대로이므로 외형 변화가 없다.

파스텔 배경 — 같은 세 색이 보관함 탭과 문장팩 카드에서 겹쳐 쓰이고 있었다.
한쪽 의미로 이름을 붙일 수 없어 색조 이름으로 뒀다.

| 상수 | 값 | 쓰는 곳 |
|---|---|---|
| `mint` | `0xFFDDEFEA` | 문장 탭, 일상 표현 팩 |
| `sky` | `0xFFDCE9F8` | 클립 탭, 여행 표현 팩 |
| `cream` | `0xFFFFE8C7` | 단어 탭, 카페 표현 팩 |

파스텔 위 잉크 — 네 색이 모두 "파스텔 배경 위 아이콘·라벨"이라는 같은 역할인데 값이 다르다.
현재 값을 그대로 옮겨만 뒀다.

| 상수 | 값 |
|---|---|
| `tabIcon` | `0xFF42636A` |
| `packIcon` | `0xFF3D5966` |
| `packLabel` | `0xFF526977` |
| `creamIcon` | `0xFFAA6B20` |

동작과 금색 — `liked`(`0xFFFF768B`, 2곳), `voiceActive`(`0xFF6D9890`),
`goldBackground`·`goldBorder`(각 3색 그라디언트).
금색은 `친밀도 최고 단계 문장 카드만 금색 테두리가 된다` 테스트가 의존하는 색이고,
그 테스트는 바꾼 뒤에도 통과한다.

### 스낵바 2곳

`app_snackbar_theme.dart`가 `isDark ? Color(0xFF2C3038) : Color(0xFF323232)`로 적어 쓰던 값을
`snackbarSurface` / `snackbarSurfaceDark` 토큰으로 옮겼다.

다크 쪽 값 `0xFF2C3038`은 `AppColors.disabledDark`와 값이 같지만 그 토큰은 쓰지 않았다.
스낵바 배경을 "비활성"이라고 부르면 나중에 비활성 색을 조정할 때 스낵바가 같이 끌려간다.
값이 겹친 것은 우연이다.

### 재화 색 6곳 — 유일한 의도된 외형 변화

`account_section.dart`의 패롯·크래커 뱃지 4곳을 `parrotCurrency` / `crackerCurrency`로 옮겼다.
여기는 값이 그대로라 변화가 없다.

작업 중에 **같은 재화에 색이 두 벌 있는 것**을 발견했다.
`exchange_screen.dart:117,120`은 같은 패롯·크래커를 `Colors.green`(`0xFF4CAF50`),
`Colors.orange`(`0xFFFF9800`)로 칠하고 있었다. 두 화면이 서로 다른 색으로 같은 재화를
가리키던 셈이라 환전 화면도 새 토큰으로 맞췄다.

**이 변경만 화면이 바뀐다.** 환전 화면 상단 잔액 두 줄의 색이
초록 → 에메랄드, 주황 → 앰버로 조금 바뀐다. 되돌리려면 그 두 줄만 고치면 된다.

`crackerCurrency`의 값 `0xFFF59E0B`는 `AppColors.warning`과 같지만 그 토큰은 쓰지 않았다.
재화 뱃지는 경고가 아니고, 다크 모드에서 `warningDark`로 따라가면 뜻이 틀어진다.

### community 글쓰기 두 화면 — 두 번째 의도된 외형 변화

리터럴 6곳만 바꾸면 화면이 반만 고쳐진다. 두 화면 모두 `AppColors`의 **라이트 전용 상수를
밝기 분기 없이** 쓰고 있어서, 리터럴로 땜질한 몇 자리만 다크를 따라가고 나머지는
다크 모드에서도 라이트 색을 그렸다. 그래서 두 화면의 색 출처를 `AppTokens.of(context)`로
통일했다.

규칙: `AppColors.X` → `tokens.X`. 라이트 값은 그대로이고 다크만 제 색을 찾는다.
두 파일에서 `AppColors` import가 사라졌다.

`board_write_screen.dart`

| 전 | 후 |
|---|---|
| `isDark ? Color(0xFF3A4048) : AppColors.surfaceContainer` | `tokens.surfaceContainer` |
| `const lineColor = AppColors.disabled` | `tokens.disabled` |
| `const mutedText = AppColors.textDisabled` | `tokens.textDisabled` |
| `const tipBlue = AppColors.primary` | `tokens.primary` |
| `AppColors.primarySoft` / `primary` (태그 칩, TIP 뱃지) | `tokens.primarySoft` / `primary` |
| `AppColors.textPrimary` (본문·팁) | `tokens.textPrimary` |

`panelBg`의 다크 값이 `0xFF3A4048`에서 `surfaceContainerDark`(`0xFF1A1D21`)로 **어두워진다.**
라이트는 그대로다.

`const` 전파로 `Divider` 3곳에서 `invalid_constant`가 났고, 감싼 `const`를 벗겨 해결했다.

`question_write_screen.dart`

| 전 | 후 |
|---|---|
| `isDark ? Color(0xFF3A3F46) : Color(0xFFE3E6EB)` (Q&A 박스 배경) | `tokens.surfaceContainerHigh` |
| `isDark ? Color(0xFF5B616B) : Color(0xFFCAD0D8)` (박스 테두리) | `tokens.divider` |
| `isDark ? Color(0xFF151922) : colorScheme.surface` (하단 툴바) | `tokens.surface` |
| `AppColors.surfaceContainerHigh` 3곳 (구분선·테두리) | `tokens.divider` |
| `isDark ? AppColors.primarySoft : AppColors.primary` 4곳 | `tokens.primary` |
| `AppColors.textDisabled` 2곳 | `tokens.textDisabled` |
| `const accentBlue = AppColors.primary` | `tokens.primary` |

**바뀌는 것:**

- Q&A 설정 박스 배경 — 라이트 `0xFFE3E6EB` → `0xFFF0F2F5`로 밝아지고,
  다크 `0xFF3A3F46` → `0xFF24272C`로 어두워진다.
- 박스 테두리 — 라이트 `0xFFCAD0D8` → `0x1A000000`로 옅어지고, 다크는 `0x33FFFFFF`가 된다.
- 구분선 3곳 — 원래 `surfaceContainerHigh`(표면색)를 선에 쓰고 있었다.
  선 토큰 `divider`로 바꿨다. 라이트는 약간 진해지고, 다크에서는 거의 흰 선이 사라진다.
- 하단 툴바 다크 배경 — `0xFF151922` → `surfaceDark`(`0xFF0D0F12`)로 어두워진다.
- 첨부 아이콘 4개 다크 — `primarySoft`(`0xFFE8F1FF`, 거의 흰 하늘색)를 쓰던 것이
  `primaryDark`(`0xFF3C8DFF`)가 된다.

### 앱 전체 다크 모드 색 통일 — 586곳

community 글쓰기 두 화면을 고치면서 같은 종류의 문제가 다른 화면에도 있는지 전수 조사했다.
`AppColors`의 상수 44개 중 다크 짝(`xDark`)이 있는 것이 31개인데, 화면에서 그 31개를
**밝기 분기 없이 라이트 값으로 쓰는 자리가 256곳** 있었다. 다크 모드에서 라이트 색을
그리고 있던 자리다. 반대로 분기를 제대로 쓰는 자리는 137곳이었다.

#### `context.tokens` 창구 추가

`app_tokens.dart`에 확장을 하나 넣었다. 이미 있는 `context.texts`와 같은 꼴이다.

```dart
extension AppTokensContext on BuildContext {
  AppTokens get tokens => AppTokens.of(this);
  HomeTokens get homeTokens => HomeTokens.of(this);
}
```

#### 치환 규칙

| 전 | 후 |
|---|---|
| `AppColors.x` (짝 있는 31개) | `context.tokens.x` |
| `AppColors.xDark` | `context.tokens.x` |
| `isDark ? AppColors.xDark : AppColors.x` | `context.tokens.x` |
| `isDark ? AppColors.aDark : AppColors.b` (비대칭) | `isDark ? context.tokens.a : context.tokens.b` |

세 번째 줄(137곳)은 값이 완전히 같아서 **외형 변화가 없다.**
네 번째 줄(26곳)도 토큰이 밝기별로 같은 값을 주므로 외형이 그대로다.
비대칭 분기는 의도된 것이라 분기를 유지했다. 예를 들어
`isDark ? surfaceContainerDark : surface`는 다크에서만 카드를 한 단계 띄우려는 것이고,
`isDark ? context.tokens.surfaceContainer : context.tokens.surface`로 뜻만 또렷하게 바꿨다.

첫째·둘째 줄의 256곳이 **실제로 다크 모드 외형을 바꾸는 부분**이다.
라이트 모드는 값이 그대로라 변화가 없다.

#### 결과

- 파일 71개에서 586곳 치환, 삼항 축약 137곳
- `context.tokens` 사용: 72개 파일, 431곳
- 화면 코드에 남은 `AppColors` 참조는 다크 짝이 없는 13개(커뮤니티 게시판 액센트,
  재화 색, 그라디언트)뿐이다. 밝기에 따라 바뀌지 않아야 하는 색들이다.
- `app_theme.dart`와 컴포넌트 테마는 `AppColors`를 그대로 쓴다.
  토큰이 거기서 나오므로 `context.tokens`를 쓸 수 없다.

#### 손으로 고친 것

스크립트가 낸 오류를 분석기로 잡아 하나씩 처리했다.

- **`invalid_constant` 63곳** — 런타임 값이 들어가면서 감싸던 `const`가 깨졌다.
  가장 가까운 `const`를 벗겼다. 그만큼 const 캐시를 잃으므로 그 위젯들은
  리빌드 때 다시 만들어진다. 색 하나짜리 `Icon`·`Divider`·`BoxDecoration`이라 부담은 작다.
- **`const` 지역변수 3곳** → `final` (`board_view_screen.dart`, `vote_write_screen.dart`)
- **`isDark` 지역변수 8곳** — 분기가 사라져 쓰이지 않게 되어 삭제
- **`board_comment_input_bar.dart`** — `backgroundColor`의 기본값은 const여야 해서
  토큰을 쓸 수 없었다. 파라미터를 nullable로 바꾸고 `backgroundColor ?? context.tokens.surface`로
  build에서 해결했다.
- **`community_menu_tile.dart`** — `_iconColorOf` / `_backgroundColorOf`가 context 없는
  최상위 함수였다. `BuildContext`를 첫 인자로 받게 바꿨다.
- **정규식 사고 2곳** — 축약 패턴이 `Theme.of(context).brightness == Brightness.dark ? a : b`의
  `Brightness.dark`를 조건 변수로 잘못 읽어 `brightness == context.tokens.x`라는 비교문을
  만들었다. `content_studio_bridge_screen.dart`와 `tts_slider_preview.dart` 두 곳이었고
  분석기가 `unrelated_type_equality_checks`로 잡아줘서 바로 고쳤다.

## 남긴 40곳

바꾸지 않은 기준: **16진수 값이 토큰 값과 정확히 같고 의미까지 맞을 때만** 바꿨다.
토큰 81개 값과 전부 대조했다.

### 에셋에 묶인 색 (10곳)

- `lib/core/shared/widgets/sentence_affinity_bar.dart:9-13`
  친밀도 1~5단계 칩의 배경·글자색 5쌍. `assets/badges/affinity_N.svg` 뱃지와
  같은 계열로 맞춘 값이라 에셋을 바꾸지 않는 한 고정이다.
  이미 주석과 지역 상수로 뜻이 적혀 있어 따로 옮기지 않았다.

### home 일러스트 (30곳)

- `nest_preview.dart` 20곳, `character_info_sheet.dart` 7곳, `stage_preview_screen.dart` 3곳

전부 `CustomPainter`로 캐릭터와 둥지를 그리는 색이다. 토큰 81개 값과 대조했을 때
일치한 건 `nest_preview.dart:262`의 `0xFFFFFFFF` 한 곳뿐이고, 그것도 꽃잎을 그리는
흰색이라 `surface` 토큰으로 바꾸면 다크 모드에서 꽃잎이 어두워진다. 그래서 남겼다.

이 그림 색들은 토큰이 아니라 그림의 일부다. 정리하려면 `HomeTokens`가 아니라
일러스트용 팔레트를 따로 두는 게 맞다.

## 검증하지 못한 것

이 앱은 Drift sqlite3 FFI 때문에 `flutter run -d chrome` 프리뷰가 안 된다.
화면을 눈으로 본 것은 없다. analyze와 test 통과는 "컴파일되고 기존 테스트가 깨지지 않았다"는
뜻일 뿐이다.

실기기에서 볼 곳:

1. **다크 모드로 앱 전체를 한 바퀴** — 이번 변경의 핵심이다. 256곳이 라이트 색에서
   다크 색으로 바뀌었다. 특히 커뮤니티(게시판·질문·투표 보기와 댓글), 콘텐츠 제작
   (챗봇 시트, 영상, TTS)에 집중돼 있다. 라이트 모드는 값이 그대로라 변화가 없어야 한다.
2. **커뮤니티 글쓰기 두 화면**(일반 글쓰기, 질문 글쓰기) — 라이트와 **다크 둘 다**.
   Q&A 설정 박스, 구분선, 하단 툴바, 첨부 아이콘 색이 바뀐다.
   구분선이 너무 진하거나 박스가 배경에 묻히면 토큰 선택을 바꿔야 한다.
3. **환전 화면**(설정 > 환전) — 잔액 두 줄 색이 바뀐다.
4. **auth 네 화면** — 파란색이 `0xFF0066FF`에서 `0xFF0064FF`로 2단계 바뀌었다.
   구분이 안 되는 게 정상이다.
5. **콘텐츠 제작 챗봇** — 모드 선택 시트, 라우팅 시트, 말풍선 그라디언트.
   값이 그대로라 변화가 없어야 한다. 달라 보이면 잘못 바뀐 것이다.
6. **보관함 상단 탭 카드와 문장팩 카드, 최고 친밀도 금색 카드** — 역시 변화가 없어야 한다.
7. **스낵바** — 토스트 배경. 값 그대로.

`dart format`은 이번에 고친 파일에만 돌렸다. 몇 파일은 인덱스 버전에 80자 넘는 줄이
남아 있어서 포맷 줄바꿈이 diff에 함께 들어갔다. 색과 무관한 줄 변화는 그 때문이다.


---

# 4단계: Material 기본 팔레트 정리

3단계까지는 `AppColors`만 다뤘다. 이 단계는 `Colors.white`, `Colors.black`,
`Colors.grey.shade*`처럼 Material 기본 팔레트를 화면에서 직접 쓰는 자리를 정리한다.
`AppColors`와 달리 1:1 토큰 대응이 없어서 자리마다 역할을 보고 판단했다.

## 이전 단계와 다른 점: 라이트 모드도 조금 바뀐다

3단계까지는 "hex가 정확히 일치할 때만 치환"이라는 규칙을 지켰고, 그래서 라이트 모드는
값이 그대로였다. 이번에는 Material 회색조와 Parrokit 팔레트가 정확히 일치하지 않는다.
차이는 작지만 **라이트 모드에도 변화가 있다.**

| Material | hex | 토큰 | 토큰 라이트 hex |
|---|---|---|---|
| `grey.shade300` | `E0E0E0` | `borderStrong` | `BDC4CC` |
| `grey.shade400` | `BDBDBD` | `borderStrong` | `BDC4CC` |
| `grey.shade500` | `9E9E9E` | `textTertiary` | `8C95A1` |
| `grey.shade600` | `757575` | `textSecondary` | `5B636E` |
| `grey.shade700` | `616161` | `textSecondary` | `5B636E` |
| `grey[100]` | `F5F5F5` | `surfaceContainer` | `F7F8FA` |
| `grey[200]` | `EEEEEE` | `surfaceContainerHigh` | `F0F2F5` |
| `grey` | `9E9E9E` | `textTertiary` | `8C95A1` |
| `black87` | 87% 검정 | `textPrimary` | `111418` |
| `white` (배경) | `FFFFFF` | `surface` | `FFFFFF` (동일) |
| `blue` / `blue[600]` | `2196F3` / `1E88E5` | `primary` / `info` | `0064FF` |
| `blue[50]` | `E3F2FD` | `primarySoft` | `E8F1FF` |
| `red` / `red[400]` / `redAccent` | `F44336` 계열 | `danger` | `DC2626` |
| `green` / `green[700]` | `4CAF50` / `388E3C` | `success` | `16A34A` |
| `amber` | `FFC107` | `warning` | `F59E0B` |

Parrokit 팔레트는 Material 회색조보다 파란 기가 살짝 돈다(`textTertiary` `8C95A1`).
그래서 회색 글자와 테두리가 아주 조금 차가워진다.

## 새 토큰: `borderStrong`

입력창과 외곽선 버튼의 테두리에 쓸 색이 없었다. 기존 토큰은 둘 다 맞지 않는다.

- `divider` (`0x1A000000`, 10% 검정) — 너무 옅다. 폼 테두리로 쓰면 거의 안 보인다.
- `disabled` (`0xFFE9ECEF`) — 비활성 배경색이다. 테두리로 쓰기엔 역시 옅다.
- `textDisabled` (`0xFFADB5BD`) — 값은 맞지만 이름이 글자색이다.

그래서 한 쌍을 추가했다.

```dart
/// 입력창과 외곽선 버튼의 또렷한 테두리. 구분선보다 진하고 글자색보다 연하다.
static const Color borderStrong = Color(0xFFBDC4CC);
/// 다크 또렷한 테두리
static const Color borderStrongDark = Color(0xFF3F454E);
```

## 고친 것

전체 296곳 중 **122곳을 치환하고 174곳을 남겼다.**

### auth 네 화면 (37곳 치환, 11곳 유지)

`sign_up` 16, `sign_in` 8, `find_pw` 8, `onboarding` 9.
이 네 화면은 지금까지 라이트 전용이었다. Scaffold와 AppBar가 `Colors.white`,
제목과 뒤로가기 아이콘이 `Colors.black`이라 다크 모드에서 흰 화면이 그대로 나왔다.

- `backgroundColor: Colors.white` → `context.tokens.surface`
- `color: Colors.black` (제목, 뒤로가기) → `context.tokens.textPrimary`
- `BorderSide(color: Colors.grey.shade400)` → `context.tokens.borderStrong`
- `Colors.grey.shade600` → `textSecondary`, `shade500` → `textTertiary`
- 닉네임 중복 확인 표시 `Colors.green` / `Colors.red` → `success` / `danger`

**유지한 11곳:** 파란 버튼 위의 `foregroundColor: Colors.white`와
그 안의 `CircularProgressIndicator(color: Colors.white)`,
그림자용 `Colors.black.withValues(alpha: 0.05)`.
파란 배경 위의 흰 글자는 두 모드에서 똑같이 흰색이 맞다.

### 스켈레톤 (4곳)

```dart
baseColor: Colors.grey[300]!      → context.tokens.skeleton
highlightColor: Colors.grey[100]! → context.tokens.skeletonHighlight
```

`skeleton` / `skeletonHighlight` 토큰이 정확히 이 용도로 있었는데 쓰이지 않고 있었다.
`account_section.dart`, `editable_avatar.dart`.

### 바텀시트 드래그 핸들 (7곳)

`isDark ? Colors.grey.shade700 : Colors.grey.shade300` → `context.tokens.disabled`.
TTS 시트 5개, 영상 모델 시트 1개, 언어 시트 1개가 같은 코드를 복사해 쓰고 있었다.
다크에서 핸들이 `616161`에서 `2C3038`로 어두워진다. 핸들은 옅어야 하니 괜찮다.

### 투표 화면 (14곳)

`vote_screen`, `vote_comments_section`, `vote_sticky_comment_bar`가
`Colors.grey[400]`, `grey[500]`, `blue[600]`, `Colors.red`를 직접 쓰고 있었다.
파일 머리에 `// 커뮤니티 대표 색상인 Colors.blue[600]을 일관되게 활용하여 제작.`
라는 주석까지 있었다. 주석도 `AppTokens.primary`로 고쳤다.

특히 두 곳은 다크 모드에서 망가져 있었다.

```dart
// 전: 원형 버튼. 다크에서 검정 원이 검정 배경에 묻힌다
color: enabled ? Colors.black87 : Colors.grey[200],
child: Icon(icon, color: enabled ? Colors.white : Colors.grey),

// 후: 다크에서 밝은 원 + 어두운 아이콘으로 뒤집힌다
color: enabled ? context.tokens.textPrimary : context.tokens.disabled,
child: Icon(icon,
    color: enabled ? context.tokens.surface : context.tokens.textDisabled),
```

```dart
// 전: 입력창 둘레에 흰 테두리. 흰 배경 위에선 안 보이지만 다크에선 흰 링이 뜬다
border: Border.all(color: Colors.white, width: 1),
// 후
border: Border.all(color: context.tokens.surface, width: 1),
```

### 나머지 (60곳)

- `exchange_screen` 9 — 안내 배너의 `Colors.blue` → `info`, 토글 테두리와 글자
- `community_notification_screen` 4 — Scaffold·AppBar 흰 배경, 검정 아이콘
- `settings` 위험 동작 7 — `Colors.red` → `danger`
  (`leading_icon`, `nav_tile`, `editable_avatar`, `community_block_actions`)
- `question_write_screen` 2 — `Colors.black87` 제목, `isDark ? Colors.white : onSurface`
- `tts_voice_selection_sheet` 1 — `isDark ? Colors.white : Colors.black` → `textPrimary`
- `chat_bubble` 1, `recent_list_skeleton` 1 — `isDark ? Colors.white12 : Colors.black12`
  → `context.tokens.divider`
- `clip_list_view` 3, `clip_discover_screen` 1, `sentence_collection_preview` 1,
  `profile_edit_screen` 2, `account_section` 2, `video_screen` 2,
  `content_studio_hub_screen` 1, `stt_confirm_dialog` 1, `model_selector_sheet` 1,
  `tts_provider_selector` 1, `tts_audio_player_widget` 2 등

## 남긴 174곳

### 색 있는 배경 위의 흰색 (약 60곳)

파란 버튼, 그라디언트 원, 선택된 칩, 빨간 삭제 배경 위의 글자와 아이콘.
두 모드에서 흰색이 맞다. `app_theme.dart`의 `onPrimary: Colors.white`도 여기 속한다.

### 영상 위에 그리는 UI (약 45곳)

`clip_player_screen`, `shorts_page`, `subtitle_overlay`, `segment_timeline`,
`speed_menu`, `toggle_pill`, `circle_icon_button`, `clip_thumbnail_card`,
`episode_thumbnail`, `video_layer_placeholder`.
배경이 영상이거나 레터박스(`Colors.black`)라 테마 밝기와 무관하다.
이 파일들은 이미 `isLight ? ... : Colors.white` 꼴로 자체 분기를 갖고 있다.

### 그림자와 막 (46곳)

`Colors.black.withValues(alpha: ...)`. 그림자는 검정 기반이 맞다.
`app_shadows.dart`는 이미 `isDark ? 0.3 : 0.04`처럼 밝기별로 투명도를 달리 쓴다.
`barrierColor`도 같다.

### ShaderMask와 그라디언트 마스크 (5곳)

`gradient_icon.dart`, `more_card.dart`, `tts_provider_selector.dart:120`.
`ShaderMask`는 흰색을 마스크로 요구한다. 바꾸면 깨진다.
`tts_provider_selector.dart:120`에는 `// Required for ShaderMask` 주석이 있다.

### Shimmer 자식 (2곳)

`Container(color: Colors.white)`. Shimmer가 자식의 불투명한 픽셀에 그라디언트를
입히는 구조라 색 자체는 의미가 없다.

### home 일러스트 (약 10곳)

`stage_preview_screen`, `study_garden_preview`, `nest_preview`.
3단계에서와 같은 이유로 그림 색은 손대지 않았다.

### 장식 그라디언트 (2곳)

`folder_card.dart:66`의 `[Colors.deepPurpleAccent, Colors.blueAccent]`.
특별 폴더 카드 장식이라 브랜드 색에 가깝다. `AppColors.gradientStart/End`와 같은 성격이다.

### 기타 (약 4곳)

`video_layer_placeholder.dart:33`의 로딩 스피너 — 검정 레터박스 위다.
`shorts_badge.dart:31`의 `fixedColor` — 영상 위 뱃지.

## 스크립트가 망친 것, 손으로 고침

- `invalid_constant` 6곳 — `const Icon(..., color: Colors.black)` 같은 자리.
  가장 가까운 `const`를 벗겼다. 그만큼 const 캐시를 잃는다.
  `find_pw_screen`, `sign_up_screen`, `sign_in_screen`, `community_block_actions`,
  `video_screen`, `exchange_screen`, `editable_avatar`.
- `undefined_identifier` 1곳 — `vote_screen.dart`의 `_buildResults(ColorScheme, int)`가
  context 없는 메서드였다. `BuildContext`를 첫 인자로 받게 바꿨다.
- `unused_local_variable` 8곳 — 드래그 핸들과 삼항 축약으로 `isDark`가 미사용이 되어 삭제.

## 검증

| | 전 | 후 |
|---|---|---|
| `flutter analyze` | No issues found | No issues found |
| `flutter test` | +187 -1 | +187 -1 |

실패 1건은 원래 있던 `comment_usecases_test.dart`의
`AddCommentUseCase - 정상적으로 댓글이 추가되어야 한다` (mockito verify 불일치).
이번 작업과 무관하고 손대지 않았다.

Material 팔레트 직접 사용 296 → 174 (전부 의도적으로 남긴 것).
`context.tokens` 82개 파일 549곳. 화면에 남은 색 리터럴 40곳 (3단계와 같음).

`dart format`은 변경된 89개 파일에만 돌렸다.

## 확인 못 한 것

프리뷰가 없어서 **화면은 하나도 못 봤다.**
`flutter analyze`와 `flutter test` 통과는 "컴파일되고 기존 테스트가 깨지지 않았다"는
뜻일 뿐이다.

실기기에서 볼 곳:

1. **auth 네 화면을 다크 모드로** — 이번 변경에서 외형이 가장 크게 바뀌는 곳이다.
   지금까지 흰 화면이 강제됐는데 이제 다크를 따른다. 회원가입·로그인·비밀번호 찾기·
   온보딩 네 화면 모두. 입력창 테두리(`borderStrong`)가 다크 배경에서 보이는지,
   파란 버튼 위 흰 글자가 그대로인지.
2. **투표 화면** — 원형 버튼 두 개(이전/다음)가 다크에서 뒤집힌다.
   댓글 좋아요 하트, 입력 바. 라이트에서도 테두리 한 줄이 달라진다.
3. **알림 화면**(커뮤니티 > 알림) — Scaffold와 AppBar가 다크를 따른다.
4. **바텀시트 일곱 개의 드래그 핸들** — TTS 음성·모델·언어 선택, 영상 모델 선택.
   다크에서 더 어두워진다. 안 보일 정도면 `textDisabled`로 올려야 한다.
5. **스켈레톤 로딩** — 설정 계정 영역, 프로필 사진. 다크에서 깜빡임 색이 맞는지.
6. **회색 글자 전반** — 라이트 모드에서 회색이 아주 조금 차가워진다.
   `757575`가 `5B636E`로, `9E9E9E`가 `8C95A1`로.
7. **영상 재생과 쇼츠** — 변화가 **없어야** 한다. 달라 보이면 잘못 바뀐 것이다.

## 다음에 할 수 있는 것

1. `CollectionColors`의 잉크 네 색을 하나로 합치기 (디자인 결정)
2. `CollectionColors`에 다크 모드 값 추가 — 지금은 밝은 배경 전용이다
3. 좋아요 색 통일 — 지금 화면마다 셋이다.
   home `HomeTokens.like` (`FF657E`), 보관함 `CollectionColors.liked` (`FF768B`),
   커뮤니티 게시판 `tokens.primary` (파랑), 투표 댓글 `tokens.danger` (`DC2626`).
   이번에 투표 댓글의 `Colors.red`를 `danger`로 바꿨지만 이건 "빨강을 유지"한 것이고
   의미상으로는 맞지 않는다. 어느 색으로 합칠지는 디자인 결정이다.
4. home 일러스트용 팔레트 분리
5. 영상 위 UI를 위한 토큰 묶음 (`onVideo`, `onVideoMuted`, `videoScrim`) —
   지금은 `Colors.white` / `Colors.white70` / `Colors.black54`를 파일마다 직접 쓰고,
   `isLight ? ... : ...` 분기도 파일마다 다르게 복사돼 있다.
