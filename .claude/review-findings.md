# 코드 리뷰 발견 사항

묶음별로 적는다. 각 항목은 무엇이 문제였고, 어떻게 했고, 왜 그렇게 했는지.
고치지 않은 것은 "보류"로 두고 판단이 필요한 이유를 적는다.

## 묶음 1 — 상태·도메인 (`lib/core/state`, `lib/core/domain`)

### 고친 것

**1. ClipProvider가 태그 watch 스트림을 닫지 않았다**
`ClipTagMixin.startWatchingDistinctTags()`는 보관함 셸과 라이브러리 화면 두 곳에서
부르는데 짝인 `stopWatchingDistinctTags()`는 리포 전체에서 한 번도 부르지 않았다.
`ClipProvider`에 `dispose()`가 없어서 Drift watch 구독이 앱이 끝날 때까지 살아 있고,
태그 테이블이 바뀔 때마다 `notifyListeners()`를 불러 보관함을 떠난 뒤에도 전역
리빌드를 일으켰다. `ClipProvider.dispose()`에서 닫게 했다.

**2. 커뮤니티 알림 Provider 조립이 두 번 적혀 있었다**
`ChangeNotifierProxyProvider`의 `create`와 `update`가 use case 여섯 개와 messaging
service를 똑같이 40줄씩 조립했다. `update`는 `create` 직후 그 인스턴스를 받으므로
`update` 쪽 생성은 실제로 쓰이지도 않는 죽은 가지였다.
`_createCommunityNotificationProvider()`로 모았다.

**3. 클립 삭제가 실패를 조용히 삼켰다**
`deleteClipById`가 전체를 `try`로 감싸고 `catch (_) { return false; }`로 끝냈다.
DB 트랜잭션이 깨져도, 원격 문서 삭제가 막혀도 호출부는 `false`만 받았다.
파일 삭제 실패 두 곳도 빈 `catch`여서, 지워지지 않은 파일이 저장 용량에 계속
잡히는데 흔적이 없었다. 세 곳 모두 로그를 남기게 했다. 반환값과 흐름은 그대로다.

**4. 최근 본 클립 목록이 갱신을 버렸다** — 이 묶음에서 가장 실제 영향이 큰 버그
`_rebuildRecents`의 `if (_buildingRecents) return;`은 재진입을 막는 게 아니라
새로 들어온 행을 버리는 코드였다. 썸네일을 받아오는 동안(서버·클라우드 클립이면
내려받기까지 한다) 사용자가 다른 클립을 보면 그 갱신이 사라져서, 방금 본 클립이
최근 목록에 나타나지 않고 낡은 목록이 남았다. 마지막 행만 기억해 두고 현재 작업이
끝나면 이어서 한 번 더 만들도록 바꿨다.

**5. UserProvider가 라우터 Notifier를 닫지 않았다**
`routerRefreshNotifier`는 UserProvider가 직접 만든 `ChangeNotifier`인데
`dispose`에서 빠져 있었다. GoRouter가 `refreshListenable`로 붙잡고 있다.

**6. RevenueCat 로그아웃 실패가 기록되지 않았다**
`signOut`과 `deleteAccount`가 똑같이
`() async { try { await Purchases.logOut(); } catch (_) {} }();` 한 줄을 들고 있었다.
기다리지 않는 건 의도대로 뒀다 — 결제 쪽이 막혀도 앱 로그아웃이 기다리면 안 된다.
실패 로그만 남기고 한곳으로 모았다.

### 보류 — 판단이 필요하다

**가. 태그 watch를 화면 떠날 때 멈출지**
지금은 `ClipProvider.dispose()`에서만 닫으니 보관함을 떠난 뒤에도 구독이 산다.
보관함 셸과 라이브러리 화면이 같은 구독 하나를 공유하는 구조여서, 한 화면의
dispose에서 멈추면 다른 화면이 쓰던 구독까지 끊긴다. 참조 세기를 넣거나 구독
주인을 한 화면으로 정해야 하는데, 어느 쪽이든 구조 변경이라 혼자 정하지 않았다.

**나. `deleteClipById`가 원격을 먼저 지우고 로컬 DB를 나중에 지운다**
원격 소스 삭제가 성공하고 그다음 DB 트랜잭션이 깨지면, 원본은 사라졌는데 로컬
행은 남아서 깨진 클립을 가리킨다. 호출부는 `false`를 받으니 사용자에게는
"삭제 실패"로 보이고 목록에는 남는다.
다만 `LibraryEntitySyncCoordinator.createGroup`에 "로컬을 먼저 하면 동시에 도는
pull이 방금 만든 걸 '원격에서 지워짐'으로 오인한다"는 설명이 달려 있다. 삭제도
같은 이유로 일부러 원격을 먼저 하는 것일 수 있다. 순서를 바꾸는 건 동기화 설계
판단이고, 지금 클립이 0개라 시뮬레이터로 확인할 수도 없어서 손대지 않았다.

**다. `AppUser` watch가 필드를 하나씩 적어서 베낀다**
`_startUserSubscription`의 `copyWith`가 열 개 남짓한 필드를 이름으로 나열한다.
앞으로 `AppUser`에 필드를 더하면 그 필드는 조용히 갱신되지 않는다. 지금은
`coins`가 `parrots`의 getter라 빠진 것이 없어 실제 버그는 아니다. 통째로 바꾸면
로컬 값이 원격 값에 밀리는 필드가 생길 수 있어서 그대로 뒀다.

**라. 루트 Provider에 `_disposed` 가드가 없다**
`await` 뒤에 `notifyListeners()`를 부르는 자리가 여럿인데 dispose 여부를 보지
않는다. 지금은 전부 앱 루트에 한 번 만들어지는 Provider라 앱이 끝날 때만
문제가 되어 그대로 뒀다. 화면마다 만들어지는 기능 Provider에서는 실제로 터질
수 있으니, 해당 묶음에서 다시 본다.

### 회귀 테스트를 넣지 않은 이유

4번은 테스트로 잡을 수 있는 종류지만, `ClipActivityProvider`를 세우려면
`ClipRepository` 전체를 대신할 가짜 구현이 필요하다. 수정 한 줄에 비해 품이
너무 커서 넣지 않았다.

## 묶음 2 — 데이터 (`lib/data/local`, `lib/data/models`)

### 고친 것

**7. `findOrCreate`가 찾기와 만들기로 나뉘어 있었다**
`CollectionsDao.findOrCreate`를 pull 동기화·클립 추가·클립 이동 세 곳에서 부른다.
select와 insert가 한 트랜잭션이 아니어서, pull이 도는 중에 사용자가 같은 이름의
콜렉션에 클립을 넣으면 양쪽이 "없다"를 보고 각각 insert할 수 있었다.
`transaction`으로 묶고, 똑같던 조회 구문은 `findByNameAndStorageMode`를 쓰게 했다.

**8. 찾은 콜렉션에 원격 id를 붙이지 않았다** — 이 묶음에서 가장 실제 영향이 큰 버그
`findOrCreate`는 `remoteId`를 받고도 기존 콜렉션을 찾으면 그 값을 버렸다.
pull의 `_resolveCollectionId`는 먼저 `findByRemoteId`로 찾고, 못 찾으면 이름으로
`findOrCreate`를 부르면서 `remoteId`를 넘긴다. 로컬에서 먼저 만든 콜렉션은
`remoteId`가 없으니 이름으로 매칭되는데, 그 값이 버려져서 끝까지 원격 문서와
연결되지 않았다. 그래서 pull은 매번 이름으로만 찾았고, 사용자가 그 콜렉션
이름을 바꾸면 다음 pull이 같은 내용의 콜렉션을 하나 더 만들었다.
받아 온 `remoteId`가 있고 찾은 콜렉션에 아직 없을 때만 붙인다. 이미 다른
`remoteId`가 붙어 있으면 건드리지 않는다.

**9. v2→v3 마이그레이션에 죽은 구간 64줄**
문서 주석은 "로컬/서버/gdrive가 섞인 콜렉션을 storageMode별로 분리한다"고
적혀 있는데, 그 루프는 한 번도 실행되지 않는다. 바로 위 UPDATE가 WHERE 없이
모든 클립의 `storage_mode`를 `'local'`로 덮어쓰고, 루프는 그 값을 다시 읽어
모드를 가르기 때문이다. `distinctModes`는 늘 `{'local'}`이라 `continue`에서
전부 빠지고, 뒤따르는 빈 콜렉션 정리까지 도달하지 않는다. 118줄 중 64줄이다.
v2에는 클립별 `storageMode` 컬럼이 없었으니(이 마이그레이션이 추가한다)
가를 것이 애초에 없었던 것으로 보인다. **코드는 지우지 않고 주석으로만 표시했다.**

**10. `CollectionsDao` 회귀 테스트와 DB 테스트 자리**
메모리 DB를 끼울 수 있게 `AppDatabase.withExecutor`를 넣고 테스트 5개를 더했다.
8번은 이 테스트가 실제로 잡는다. 테스트가 188개에서 193개로 늘었다.

### 보류 — 판단이 필요하다

**마. v2→v3 죽은 구간을 지울지**
위 9번. 내 판독으로는 도달 불가능이 분명하지만, 이미 사용자 기기에서 돌아간
마이그레이션이라 판독이 틀렸다면 복구 로직을 없애는 셈이 된다. 지우라고 하면
한 커밋으로 지운다.

**바. `(name, storage_mode)`에 unique index를 걸지**
7번의 트랜잭션은 막는 쪽이고, index는 못 생기게 하는 쪽이다. 스키마 변경이라
v4 마이그레이션이 필요하고, 이미 중복이 생긴 기기에서는 index 생성 자체가
실패하니 중복 병합 절차도 함께 정해야 한다.

**사. FK `onDelete`가 테이블마다 다르다**
`recentClipViews`, `clipTags`는 `onDelete: cascade`인데 `clipSourceRefs`,
`clipCacheEntries`, `segments`, `groupCollections`, `clips.collectionId`는 없다.
그래서 지우는 쪽에서 자식 행을 손으로 먼저 지워야 하고, 빠뜨리면 FK 예외가 난다.
`CollectionsDao.pruneIfEmpty`에 "그룹에 속한 콜렉션이 비어도 삭제되지 않던
원인이 이것이었다"는 주석이 이미 그 사고 기록이다.
지금 클립을 지우는 두 곳(`clip_repository_impl`, `clip_remote_library_sync_datasource`)은
둘 다 자식을 제대로 먼저 지우고 있어서 살아 있는 버그는 아니다. 다만 새로
지우는 코드를 쓰면 또 밟는다. 맞추려면 v4 마이그레이션이 필요하다.

**아. `UserPrefs.loadUser`의 기본값이 `AppUser`의 기본값과 다르다**
`AppUser`는 `parrots = 20, crackers = 1000`으로 새 유저에게 주는데,
`loadUser`는 키가 없으면 둘 다 0으로 읽는다. 저장했다 읽는 평소 경로에서는
값이 그대로라 손실이 없고, "모르면 0"이 통화로는 안전한 쪽이라 그대로 뒀다.
다만 같은 필드에 기본값이 두 개 있는 셈이니 적어 둔다.

### 깨끗했던 것

- 모델 8개의 `toJson`/`fromJson` 키가 모두 짝이 맞는다. `user.dart`가 `coins`를
  `parrots`의 옛 키로 읽는 것은 의도된 하위 호환이다.
- `GroupRepositoryImpl.deleteGroupById`는 `group_collections`를 먼저 지우고
  트랜잭션으로 묶는다. `GroupsDao.deleteGroupById`를 직접 부르면 FK 예외가
  나지만, 실제 호출부는 이 repository 한 곳뿐이다.
- `LibraryEntitySyncCoordinator`의 생성 순서(원격 먼저, 로컬 나중)는 동시에
  도는 pull이 방금 만든 것을 "원격에서 지워짐"으로 오인하는 레이스를 피하려는
  것이고, 주석에 그렇게 적혀 있다. 묶음 1의 보류 "나"도 같은 이유일 수 있다.

## 전 화면 공통 — 눌러도 아무 일도 없는 버튼 12개

리뷰 중에 리포 전체에서 `onPressed: () {}` / `onTap: () {}`을 찾았다.
전부 **고치지 않았다.** 비우는 게 맞는지, 기능을 넣는 게 맞는지, 눌리지 않게
회색으로 두는 게 맞는지는 버튼마다 다르고 전부 기능 판단이다.

| 화면 | 버튼 | 파일 |
|------|------|------|
| 커뮤니티 목록 | 상단 검색 | `community/shell/presentation/community_shell_screen.dart:161` |
| 게시글 보기 | 알림 끄기 | `community/board/presentation/board_view_screen.dart:284` |
| 게시글 댓글 입력 | 사진 첨부 | `community/board/presentation/widgets/board_comment_input_bar.dart:73` |
| 질문 쓰기 | 이미지 | `community/question/presentation/question_write_screen.dart:289` |
| 질문 쓰기 | 마이크 | `community/question/presentation/question_write_screen.dart:293` |
| 질문 쓰기 | 링크 | `community/question/presentation/question_write_screen.dart:297` |
| 질문 쓰기 | 태그 | `community/question/presentation/question_write_screen.dart:301` |
| 홈 무대 | 문장 추가 (filledTonal) | `home/dashboard/presentation/stage_preview_screen.dart:1586` |
| 보관함 둘러보기 | "Parrokit 제공 — 전체" | `collection/shell/presentation/widgets/sentence_collection_preview.dart:621` |
| 보관함 단어 미리보기 | 카드 전체 | `collection/shell/presentation/widgets/word_collection_preview.dart:281` |
| 더보기 | 앱 정보 줄 | `settings/more/presentation/sections/info_section.dart:54` |

눈여겨볼 것 둘:

- **홈 무대의 "문장 추가"는 `IconButton.filledTonal`이다.** 칠해진 버튼은 앱에서
  가장 "누르라"고 말하는 모양인데 아무 일도 없다. 질문 쓰기의 네 개는 아이콘
  버튼이라 덜 눈에 띄지만, 네 개가 나란히 전부 죽어 있다.
- **더보기의 앱 정보 줄은 기능이 없는 게 맞아 보인다** (버전을 보여 주는 줄,
  `showArrow: false`). 그런데 `onTap: () {}`이라 눌리면 물결 효과는 난다.
  이건 `onTap: null`로 두면 끝이지만, 눌리는 느낌이 사라지는 눈에 보이는
  변화라 역시 손대지 않았다.

의도적으로 비운 것 둘은 위 목록에서 뺐다 — 쇼츠 재생 컨트롤의 부모 탭 막기
(`shorts_page_control_section.dart:65`, 주석 있음)와 `subtitle_tile.dart`의
스켈레톤 placeholder.

## 묶음 3 — 커뮤니티 셸 (`lib/features/community/shell` 및 그 part 파일들)

### 고친 것

**11. 되돌리기가 엉뚱한 항목을 건드렸다 (세 곳, 같은 버그)** — 이 묶음에서 가장 큰 것
`toggleCommentLike`, `toggleLike`, `toggleScrap` 모두 낙관적으로 먼저 수를 바꾸고,
서버 호출이 실패하면 **await 전에 잡아 둔 인덱스**로 되돌렸다.
그 await 사이에 `fetchComments`가 목록을 비우거나, `addComment`가 항목을 더하거나,
`fetchPosts`가 글 목록을 갈아끼우거나, `setBlockedUserIds`가 차단된 작성자를 걸러
새 리스트를 만들 수 있다. 목록이 달라졌으면 그 인덱스는 다른 항목을 가리키고,
되돌리기가 멀쩡한 댓글·글의 좋아요·추천·스크랩 수를 1 깎는다.
세 곳 모두 id로 다시 찾게 했다.

**12. 묵은 오류 메시지가 다른 화면 토스트로 샜다**
`CommunityProvider._errorMessage`는 투표 쓰기와 질문 쓰기가
`showToast(provider.errorMessage ?? '...')`로 읽는다. 글쓰기·수정·삭제·투표·질문
경로는 전부 시작할 때 null로 비우는데, 댓글 네 메서드와 추천·스크랩 두 메서드는
실패할 때 값만 넣고 비우지 않았다. 댓글이 한 번 실패한 뒤 투표를 올리다 실패하면
투표 실패 토스트에 아까 댓글 오류 문구가 떴다. 여섯 메서드도 시작할 때 비운다.

**13. 댓글 등록이 실패하면 쓴 글이 사라졌다**
게시글·질문·투표 세 화면이 똑같이 서버에 보내기 전에 입력창을 먼저 비웠다.
실패하면 토스트와 함께 빈 입력창만 남아서, 길게 쓴 답글을 그대로 날렸다.
미리 비우는 건 그대로 두고 실패했을 때 쓴 글을 돌려준다.

**14. 댓글 쓰기와 댓글 수 올리기가 따로 날아갔다**
`addComment`가 댓글 문서를 쓰고 나서 별도로 `commentCount`를 올렸다. 둘째가
실패하면 예외만 올라가는데 댓글은 이미 올라가 있다. 사용자가 다시 쓰면 같은
댓글이 두 개 남는다. `WriteBatch`로 묶었다. 같은 파일의 `toggleCommentLike`는
이미 `runTransaction`으로 같은 짝을 묶고 있었다.

**15. 게시판 필터 칩의 터치 영역이 36pt였다**
권장 최소치 44pt보다 작다. 가로 스크롤이라 바깥 `SizedBox`가 `ListView`를 가둬서
칩 안에서 패딩을 더 줘도 늘지 않는다. 높이를 44로 올리고 `zone2Height`도
60에서 68로 맞췄다. 시뮬레이터로 라이트·다크 확인했다.

**16. 세 탭의 빈 화면 모양이 둘로 갈려 있었다**
투표만 `AppEmptyState`를 쓰고 게시판·질문은 `Center(child: Text(...))` 한 줄이었다.
탭을 넘겨 가며 보는 자리라 눈에 띈다. 둘 다 `AppEmptyState`로 맞췄다.

**17. 시간 표시 함수 복사본 네 개**
`community_post_ui_utils.dart`에 `formatCommunityTimeAgo`가 이미 있는데 게시글
보기·질문 보기·투표 보기·투표 목록이 각각 글자까지 똑같은 `_formatTimeAgo`를
들고 있었다. 네 벌을 지우고 공용 함수를 쓴다.

**18. 삼킨 실패 두 곳에 로그를 넣었다**
`_fetchMissingUsers`(작성자 정보)와 `getLikedCommentIds`(댓글 좋아요 목록).
앞엣것은 캐시에 아무것도 넣지 않아서 계속 실패하면 목록을 다시 그릴 때마다
과금되는 Firestore 읽기를 반복한다. 뒤엣것은 실패하면 좋아요가 전부 안 눌린
것처럼 보인다. 둘 다 흔적이 없었다.

**19. `_notifyListenersSafe`가 아무것도 막지 않는다고 적었다**
`CommunityProvider`의 것은 `notifyListeners()` 한 줄인데 커뮤니티 전체에서 쉰 곳
넘게 부른다. 같은 이름이 `CommunityNotificationProvider`에도 있고 그쪽은
`if (_isActive && hasListeners)`로 실제로 막는다. 동작은 안 바꾸고 주석만 달았다.

### 보류 — 판단이 필요하다

**자. 좋아요·추천·스크랩에 진행 중 가드가 없다**
빠르게 두 번 누르면 두 요청이 겹친다. 끝나는 순서가 뒤집히면 서버 상태가
어느 쪽으로든 정해진다. 항목별 in-flight 가드가 표준적인 해법이지만, 누른 게
무시되는 순간이 생기니 반응성에 대한 판단이 필요하다.

**차. 시간 표시 규칙이 커뮤니티 안에서 둘이다**
알림 타일은 7일이 넘으면 "11/5"처럼 날짜로 바꾸고, 글 목록은 "100일 전"을
그대로 쓴다. 어느 쪽으로 맞출지는 문구 판단이다.

**카. 댓글 입력 제출 함수가 세 화면에 거의 같은 모양으로 있다**
공용으로 빼지 않았다. 컨트롤러 이름, 대상 id, 토스트 문구, 스크롤 처리가 다
달라서 공유할 표면이 생각보다 작다.

### 눈에 띈 죽은 코드

`community_shell_filters_section.dart`의 `_BoardChip`에 `isDropdown = label == '최신'`이
있고, 참이면 아래 화살표 아이콘을 붙인다. 그런데 `CommunityFilters.board`는
`['전체','자유','추천해요','꿀팁','일상','분석']`이라 `'최신'`이 없다. 한 번도
참이 되지 않는다. 지우지 않았다 — 정렬 드롭다운을 붙이려던 자리인지, 그냥
남은 것인지 알 수 없다.

### 깨끗했던 것

- 돈이 오가는 경로(`addQuestion`의 크래커 차감, `acceptAnswer`의 보상)는 전부
  `runTransaction` 안에서 잔액과 상태를 먼저 확인하고 쓴다. 제일 중요한 곳이
  제일 제대로 되어 있다.
- `flutter_lints`에 `use_build_context_synchronously`가 들어 있고 `analyze`가
  깨끗하다. "await 뒤 mounted 검사 누락"은 분석기가 이미 보고 있는 셈이라
  따로 훑지 않았다. `unreachable_from_main`도 켜져 있어서 최상위 죽은 코드도
  마찬가지다. 클래스 안의 안 쓰는 private 멤버는 분석기가 안 보므로 그쪽만 본다.

## 묶음 4 — 자막 제작 (`lib/features/content-studio/captioning`)

### 고친 것

**20. 파형 추출이 겹치면 엉뚱한 파형이 걸렸다** — 이 묶음에서 가장 큰 것
`_extractWaveform`은 호출한 쪽이 `await` 하지 않는다. 영상을 빠르게 두 번 고르면
ffmpeg 작업이 겹치는데, 둘 다 `aw_tmp_audio.pcm` **한 경로**에 쓰고 늦게 끝난
쪽이 `_waveformData`를 덮었다. 두 번째 영상 밑에 첫 번째 영상의 파형이 걸릴 수
있었고, 한쪽이 읽는 중에 다른 쪽 ffmpeg가 같은 파일을 덮어쓰기도 했다.
요청마다 번호와 파일 이름을 따로 주고, 자기보다 새 요청이 생겼으면 결과를
버린다. 자기가 만든 파일은 어떤 경로로 끝나든 `finally`에서 지운다 — 전에는
다 읽은 PCM을 그대로 뒀다(180초면 3MB쯤). `removePicked`에서도 번호를 올린다.
전에는 영상을 지운 뒤에 지운 영상의 파형이 뒤늦게 올라왔다.

**21. 편집 모드에서 세그먼트 스냅샷이 폼과 어긋났다**
`EditSegmentMixin`은 `segmentForms`와 겹침 판정용 스냅샷 목록을 짝으로 관리한다.
그런데 `CaptioningProvider._loadForEdit`는 믹스인을 건너뛰고 `segmentForms`를
직접 `clear`하고 `add`했다. 버린 폼의 컨트롤러 다섯 개가 해제되지 않았고,
스냅샷은 초기 폼 한 개짜리로 남은 채 폼만 N개가 됐다. 편집으로 연 클립에서는
"겹침 방지를 위해 구간을 자동 조정했습니다"가 엉뚱한 기준으로 돌았다.
`disposeSegmentForms` + `_fillSegmentsFromDraft`(= `ensureSegmentFormsLength` +
`setSegmentAt`)로 믹스인 경로를 지나가게 했다.

**22. 최종 저장이 깨진 파일을 남기거나 받아들였다**
`FileStagingService.finalize`는 복사 후 `dest.length() > 0`만 보고 성공으로 쳤다.
잘린 파일도 통과하고, 바로 임시 원본을 지우니 되돌릴 수 없다. 복사가 끊기면
반쯤 쓰인 파일이 `videos/` 에 남는데 `sweepOld`는 임시 폴더만 쓸어서 아무도
치우지 않는다. 길이를 원본과 비교하고, 실패하면 지우고 다시 던진다.
테스트 5개를 넣었다 (이 서비스는 테스트가 없었다).

**23. 저장 성공·실패 상태가 바로 덮어써졌다**
`save()`가 `_saveState`에 `success`/`error`를 넣고 나서 `finally`가
`_setSaving(false)`를 불렀고, 그건 조건 없이 `idle`을 넣는다. 두 enum 값이
밖에서 한 번도 보이지 않았다. `finally`를 뺐다. 지금은 `saveState`를 읽는
화면이 없어서 눈에 보이는 변화는 없다.

### 보류 — 판단이 필요하다

**타. 자막 편집기 컨트롤의 터치 영역이 44pt보다 작다**
- `segment_card.dart:108`, `:238` — 세그먼트 삭제·추가 버튼이 32×32
- `video_controls_bar.dart`의 `_ControlButton` — 아이콘 22~24 + 패딩 6 = 34~36

빽빽한 편집 화면이라 44로 키우면 줄 간격이 밀린다. 눈으로 보고 정해야 하는데,
이 화면은 영상을 고른 뒤라야 나와서 시뮬레이터로 확인하지 못했다. 추측으로
레이아웃을 바꾸지 않았다.

### 깨끗했던 것

- 컨트롤러·타이머·구독 해제가 전반적으로 잘 되어 있다. 처음 훑었을 때 아홉
  군데가 걸렸는데 전부 오탐이었다 (한 파일에 클래스가 여럿이라 생긴 것).
- `CaptioningProvider.save()`는 `isSaving` 동안 저장 버튼이 꺼져서 중복 제출이
  막힌다.

## 돈이 걸린 경로 — 세 곳에서 같은 모양의 버그

묶음 5를 보다가 `if (mounted)` 가드가 **화면 갱신이 아니라 지급을 막고 있는**
자리를 찾았다. 리포 전체를 훑어 세 곳을 고쳤다. 전부 사용자가 돈을 내거나
시간을 쓴 뒤에 아무것도 못 받는 경로다.

**24. 코인 충전: 결제는 됐는데 코인을 안 주고 끝났다**
`coin_store_section.dart`. `await Purchases.purchase(...)` 다음 지급이
`if (mounted)` 안에 있었다. 결제 시트가 떠 있는 사이에 화면이 사라지면 —
앱을 내렸다 올리거나, 다른 탭으로 가거나, 라우트가 새로 그려지면 —
`addCoins`가 아예 불리지 않았다. 오류도 안 뜬다.
Provider를 결제 시작 전에 잡아 두고, 지급은 화면 수명과 무관하게 한다.

**25. 광고 보상: 끝까지 봐도 코인을 못 받았다**
`ad_reward_section.dart`. `onRewarded` 콜백 맨 위에 `if (!mounted) return;`이
있었다. 보상형 광고는 전체 화면으로 30초쯤 도는데, 그 사이 더보기 화면을
떠나면 광고를 끝까지 봐도 코인도 쿨다운 기록도 없었다. 같은 방식으로 고쳤다.

**26. 페이월: 모르는 상품과 지급 실패가 조용히 넘어갔다**
`payment_section.dart`. 결제된 `productId`가 `CoinPackage.packages`에 없으면
`orElse`로 **첫 상품 기준** 코인을 준다. RevenueCat에만 상품을 올리고 앱
목록에 안 넣으면 낸 돈과 받는 코인이 어긋난 채 아무 흔적이 안 남는다.
`addCoins`도 기다리지 않고 불러서 실패가 사라졌다. 지급 동작은 그대로 두고
둘 다 로그와 안내를 남긴다.

### 보류

**파. 서버 영수증 검증과 지급 재시도가 없다**
결제 성공을 클라이언트에서 판단하고 클라이언트가 코인을 더한다. 지급이
실패하면 지금은 사용자에게 안내만 하고 끝이다. 재시도 큐나 서버 지급으로
옮기는 건 설계 판단이라 손대지 않았다.

### 가드가 맞게 걸려 있던 곳

같은 패턴을 리포 전체에서 찾아 네 곳을 봤는데 나머지 셋은 문제가 없었다.
- `clip_list_view.dart` — 확인 대화상자 뒤 `context.mounted` 검사는 삭제
  **전에** 있다. 화면이 사라졌으면 지우지 않는 게 맞다.
- `community_notification_list_section.dart` — 쓰기는 이미 끝났고 가드는
  토스트·이동에만 걸린다.
- `question_write_screen.dart` — 크래커 차감은 서버 트랜잭션에서 이미 했고,
  이 줄은 로컬 사본만 맞추는 것이다. `UserProvider`의 watch가 서버 값으로
  다시 덮어쓰므로 빠져도 저절로 맞는다.

## 묶음 5 — 홈 (`lib/features/home`)

고칠 것을 찾지 못했다. 이 묶음은 상태가 좋다.

- 삼킨 예외 다섯 곳이 전부 "왜 그냥 넘어가도 되는지" 주석을 달고 있다.
  (`// 파일을 읽지 못하면 앵무새 없이 둥지만 그린다.` 같은)
- `gapTimer`는 `dispose`에 직접 없지만 `dispose`가 부르는 `stopTts()`가
  취소한다. `passTimer`는 직접 취소한다.
- `handleTtsProgress`의 `end / text.length`는 바로 위에서 `text.isEmpty`를
  막는다.
- 테스트 파일이 다섯 개 붙어 있다 (stage_preview, nest_preview,
  sentence_history_dashboard, add_sentence_screen, home_tokens).

### 보류

**하. `today_practice_summary`의 목표 버튼이 상태에 따라 다른 컨트롤이 된다**
목표를 채우면 라벨 없는 `IconButton`(tooltip '목표 수정',
`visualDensity: compact`라 44pt 미만), 못 채우면 `TextButton.icon`(라벨
'목표 설정')이 된다. 같은 동작인데 모양도 글자도 바뀐다. 어느 쪽으로
맞출지는 디자인·문구 판단이다.
