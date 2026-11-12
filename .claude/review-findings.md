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

## 묶음 6 — 보관함 (`lib/features/collection`)

### 고친 것

**27. 쇼츠 무한 스크롤이 한 바퀴 뒤 멈췄다** — 이 묶음에서 가장 큰 것
`prefetchNextBatch`는 "이 길이에서는 이미 당겨왔다"를 `_lastPrefetchAtLength`로
기억하고 같으면 건너뛴다. 그런데 `removeItems`가 그 기억을 지우지 않았다.

- 10개 로드 → 5번 장면에서 당겨서 20개. `_lastPrefetchAtLength = 10`
- 10번 장면에 닿으면 화면이 앞 10개를 버리고 0번으로 점프. 길이가 다시 10
- 이제 길이(10)와 기억(10)이 같아서 prefetch가 늘 건너뛴다
- `itemCount`가 10이라 10번 장면에 다시 닿을 수도 없다

첫 한 바퀴를 돌고 나면 새 클립을 영영 안 불러오고 같은 10개만 돈다.
`removeItems`에서 기억을 지운다.

**28. 초기화에 실패한 영상 컨트롤러를 놓지 않았다**
`ClipPlayerViewModel.dispose`가 `_isInitialized && _controller != null`일 때만
놓았다. `_initVideo`는 컨트롤러를 먼저 만들고 `initialize()`를 기다린다. 파일이
깨졌거나 없어서 거기서 던지면, 또는 초기화 중에 사용자가 뒤로 가면
`_isInitialized`가 false인데 컨트롤러는 살아 있다. 네이티브 플레이어가 남는다.
이 앱은 서버·클라우드 클립을 내려받아 재생하니 드문 경우가 아니다.
`loadClip`의 catch에서도 놓는다.

**29. 태그 필터 조회가 겹치면 묵은 결과가 이겼다**
`applyNow`는 들어오는 쪽이 셋이다(디바운스, `showAll`, `startWatching`).
느린 조회가 나중에 끝나면 방금 고른 필터 결과를 예전 결과가 덮는다.
요청 번호로 막고, 로딩 표시를 내리는 것도 가장 최근 요청만 하게 했다.

**30. 이름 입력 대화상자의 컨트롤러를 놓지 않았다**
`_showNameEntryDialog`의 `TextEditingController`가 지역 변수인데 해제가 없다.
그룹·컬렉션 추가와 이름 변경 네 곳에서 쓰니 손댈 때마다 하나씩 쌓인다.

### 보류 — 판단이 필요하다

**거. 클립 내용이 바뀌어도 목록이 안 바뀔 수 있다**
`applyNow`의 `_sameIds`와 `library_tag_section`의 `Selector.shouldRebuild`가
둘 다 **클립 id만** 비교한다. DB watch는 바뀐 클립을 `_cache`에서 빼지만
`applyNow`를 다시 부르지는 않고 `notifyListeners()`만 한다. 목록 위젯은
`resultsVersion`만 select하므로 그 알림으로는 안 그려진다.
즉 **제목을 고친 클립이 태그 필터가 걸린 목록에서는 옛 제목으로 남을 수 있다.**
다만 폴더 화면은 `clipProvider.clipItems`라는 다른 경로를 쓰고, 지금 클립이
0개라 재현해 보지 못했다. id만 비교하는 건 불필요한 리빌드를 줄이려는
의도가 분명해서, 내용까지 비교하도록 바꾸면 그 의도를 뒤집는다. 손대지 않았다.

**너. `ShortsRepository`를 가짜로 바꿀 수 없다**
`ShortsProvider`가 구체 타입을 받고, 그 안에서 `FirebaseAuth.instance`를 읽는다.
27번 버그는 테스트로 잡기 딱 좋은 종류인데 넣지 못했다. 인터페이스로 빼는 건
구조 변경이라 혼자 정하지 않았다.

### 깨끗했던 것

- 타이머·구독 해제가 전부 되어 있다 (`memoTimer`, `_overlayTimer`, `_debounce`,
  `_clipsSub`/`_segmentsSub`/`_clipTagsSub`).
- 삼킨 예외 네 곳 중 셋이 "왜 넘어가도 되는지" 주석을 달고 있다.
- `vote_write_screen`의 투표 항목 컨트롤러는 추가·삭제·dispose가 전부 맞다.
- 가장 큰 파일(`sentence_collection_preview.dart`, 2064줄)은 테스트가
  스무 개 가까이 붙어 있다.

## 묶음 7 — 커뮤니티 글·질문·투표 (`board`, `question`, `vote`, `shared`)

### 고친 것

**31. 글 저장이 실패하면 올린 이미지가 그대로 남았다**
`AddPostUseCase`와 `AddQuestionUseCase`는 이미지를 먼저 Storage에 올리고 글
문서를 쓴다. 글 쓰기가 던지면 이미지는 아무도 가리키지 않는 채 남고, 아무도
치우지 않는다. 질문 글은 특히 자주 걸린다 — 크래커 차감이 저장 트랜잭션
안에서 잔액을 보고 모자라면 거절하는데, 그때 이미지는 이미 다 올라가 있다.
실패하면 올린 것을 지우고 다시 던진다.

**32. 글 수정이 저장보다 먼저 이미지를 지웠다** — 이 묶음에서 가장 큰 것
`EditPostUseCase`의 순서가 ①뺀 이미지 삭제 → ②새 이미지 업로드 → ③글 갱신
이었다. ③이 실패하면 ①에서 지운 이미지는 이미 사라졌는데 글은 그대로다.
글이 없어진 주소를 가리키고 되돌릴 방법이 없다. 순서를 바꿔서 저장이 끝난
뒤에 지운다. 회귀 테스트를 넣었고, 순서를 되돌리면 실제로 깨진다.

**33. 글 수정·삭제에서 "Bad state: No element"가 떴다**
`editPost`/`deletePost`가 `_posts.firstWhere(...)`를 `orElse` 없이 썼다. 목록에
없으면 `StateError`가 나고 그 메시지가 그대로 토스트에 떴다. `_posts`는 최신
20개만 들고 있고 차단한 사용자 글은 걸러지니 못 찾는 경우가 실제로 생긴다.

**34. 투표 기록 불러오기 실패가 조용했다**
`getMyVotes`·`getVotedPostIds`의 빈 catch. 실패하면 "아직 투표 안 함"으로
보이고, 그대로 누르면 서버가 "이미 투표한 게시글입니다"로 거절한다.
사용자는 영문을 모르고 흔적도 없었다. 로그만 남긴다.

### 보류 — 판단이 필요하다

**더. 글 목록이 20개에서 멈춘다. 페이징이 꽂혀는 있지만 돌지 않는다**
`_lastDocument`는 선언돼 있고 `getPosts(startAfter: _lastDocument)`로 넘겨지며
`refresh`일 때 null로 비워진다. 그런데 **어디에서도 값이 들어가지 않는다.**
`getPosts`가 `List<Post>`만 돌려주고 마지막 `DocumentSnapshot`을 주지 않기
때문이다. 그래서 `startAfter`는 늘 null이다.

지금은 호출부 전부가 `refresh: true`라 눈에 보이는 버그는 없다. 대신
**게시판·질문·투표 목록이 각각 최신 20개까지만 보이고 그 뒤는 볼 방법이 없다.**
무한 스크롤이 없다. 글이 쌓이면 바로 문제가 된다.
고치려면 `getPosts`가 마지막 스냅샷도 돌려주게 바꾸고 목록에 "더 보기"를
붙여야 하는데, 그건 기능 추가라 하지 않았다.
덧붙여 `refresh`의 기본값이 `false`라, 앞으로 누가 그냥 `fetchPosts()`를
부르면 같은 20개가 조용히 두 번 쌓인다.

**러. 이미지 업로드가 하나 실패하면 그 이미지만 조용히 빠진다**
`uploadImageToStorage`는 실패하면 null을 돌려주고, 세 use case 모두
`if (url != null)`로 건너뛴다. 사진 세 장을 붙였는데 하나가 실패하면 두 장만
올라간 글이 아무 말 없이 등록된다. 사용자가 쓴 것이 조용히 사라지는 거라
막는 쪽이 맞아 보이지만, 그러면 업로드가 한 번 흔들릴 때 글 전체가 막힌다.
동작이 바뀌는 판단이고 확인할 방법도 없어서 손대지 않았다.

**머. 이미 투표한 글을 다시 누르면 화면이 잠깐 바뀌었다가 되돌아온다**
서버는 재투표를 거절한다(`voterSnapshot.exists`). 그런데 `votePost`는 낙관적
업데이트를 먼저 해서, 선택이 옮겨졌다가 거절당하고 제자리로 돌아온다.
아예 못 누르게 할지, 지금처럼 둘지는 기능 판단이다.

### 깨끗했던 것

- `vote_screen.dart`는 `_voteSyncToken`으로 늦게 끝난 동기화를 버린다.
  같은 가드가 없어서 묶음 4·6에서 고친 자리들과 대비된다.
- `acceptAnswer`의 크래커 보상, `addQuestion`의 크래커 차감은 전부
  `runTransaction` 안에서 상태와 잔액을 먼저 확인한다.
- 삼킨 예외가 이 묶음에는 투표 저장소 두 곳뿐이었다.

## 묶음 8 — 커뮤니티 알림·활동·메뉴·차단

### 고친 것

**35. 알림이 500개를 넘으면 전체 읽음·전체 삭제가 영영 실패했다** — 이 묶음에서 가장 큰 것
`markAllAsRead`와 `deleteAllNotifications`가 알림 전부를 `WriteBatch` 하나에
담았다. Firestore WriteBatch는 한 번에 500개까지다. 넘으면 commit이 통째로
거절되므로, 알림이 쌓인 사용자는 매번 "실패했어요" 토스트만 본다. 알림을
자동으로 정리하는 코드도 없으니 오래 쓰면 닿는 수다.
500개씩 나눠 보내고, 안 읽은 수를 0으로 맞추는 건 전부 성공한 뒤에 한다.
테스트 6개를 넣었다 (501개·1001개로 경계를 넘긴다).

**36. 닉네임 선점이 남의 것을 덮어쓸 수 있었다**
`updateUserDisplayName`이 `WriteBatch`를 썼다. 배치는 읽지 않고 쓰기만 하므로
"이미 남이 쓰는 닉네임인지"를 볼 수 없다. 화면이 미리 `isNicknameAvailable`로
확인하지만 확인과 저장 사이가 벌어져 있어서, 그 사이에 다른 사람이 선점하면
`batch.set`이 그대로 덮어썼다. `nicknames` 컬렉션을 두는 목적이 무너진다.
`runTransaction`으로 먼저 읽고 다른 uid가 쓰고 있으면 던진다.
덧붙여 `oldNickname == newNickname`일 때 배치가 `set` 다음 `delete`를 같은
문서에 보내서 방금 쓴 자기 선점을 지웠다. 그것도 막았다.

**37. 프로필 사진을 올리기 전에 예전 사진을 지웠다**
`_saveProfile`이 ①예전 프사 삭제 → ②새 사진 업로드 → ③저장 순서였다.
②나 ③이 실패하면 예전 사진은 사라졌고 새 사진은 반영되지 않는다. 사용자가
프로필 사진을 통째로 잃는다. 네트워크가 흔들릴 때 실제로 걸린다.
올리고, 저장하고, 저장이 끝난 뒤에 지운다. 묶음 7의 글 수정과 같은 종류다.

**38. 활동 목록도 늦게 끝난 조회를 받아들였다**
`_loadPage`를 `fetchActivities`(초기화)와 `loadMore`(다음 쪽)에서 부르는데,
`loadMore`만 자기 중복을 막는다. loadMore가 도는 중에 다른 활동 유형 탭으로
넘어가면 늦게 끝난 옛 조회가 새 목록 뒤에 엉뚱한 항목을 붙이고 커서까지
덮어썼다. 요청 번호로 막았다.

### 눈에 띈 것

**페이징이 되는 곳과 안 되는 곳이 한 리포 안에 있다**
`ActivityProvider`는 `_nextCursor`를 `page.nextCursor`로 제대로 갱신하고
`hasMore`도 추적한다. 반면 `CommunityProvider`의 글 목록(묶음 7 "더" 항목)은
`_lastDocument`가 선언만 돼 있고 값이 들어가지 않는다. 똑같은 기능인데
한쪽은 완성돼 있고 한쪽은 절반이다. 글 목록을 고칠 때 활동 쪽을 본보기로
쓰면 된다.

### 깨끗했던 것

- 이 묶음에는 삼킨 예외도, `orElse` 없는 `firstWhere`도 없었다.
- `CommunityNotificationProvider`는 `_isActive && hasListeners` 가드를 두고
  실패마다 `AppLogger`를 남긴다. 리포에서 가장 꼼꼼하게 쓰인 Provider다.
- 알림 저장소의 `markAsRead`·`deleteNotification`은 트랜잭션 안에서
  `isRead`를 먼저 보고 안 읽은 것만 카운터를 줄인다. 이중 차감이 안 난다.

## 묶음 9 — TTS (`lib/features/content-studio/tts`)

### 고친 것

**39. 캐시 키가 32비트 해시라 다른 글의 음성이 나올 수 있었다** — 이 묶음에서 가장 큰 것
`TtsRemoteDataSource.generateTts`가 결과를 임시 폴더에 캐시하는데, 파일명을
파라미터 문자열의 `String.hashCode`로 만들었다. 32비트라 서로 다른 스크립트가
같은 값이 될 수 있다. 그러면 캐시 히트로 판단해서 **다른 글의 음성을 돌려준다.**
패롯을 내고 엉뚱한 음성을 받는데 왜 그런지 알 방법이 없다.
`sha256` 앞 32자로 바꿨다. `crypto`는 이미 의존성에 있었다.

**40. 보이스 목록 조회가 겹치면 옛 결과가 이겼다**
언어 고르기 시트가 `updateLanguage` 직후 `fetchAvailableVoices`를 `await` 없이
부른다. 빠르게 두 번 고르면 늦게 끝난 쪽이 이긴다. 다른 언어의 보이스 목록이
뜰 뿐 아니라, 뒤따르는 "현재 voiceId가 목록에 없으면 초기화" 때문에 **방금 고른
보이스가 지워진다.** 요청 번호로 막았다.

**41. 보이스 미리듣기도 겹치면 엉뚱한 음성이 났다**
재생 버튼은 그 보이스가 로딩 중일 때만 꺼져서, A를 누른 직후 B를 누를 수 있다.
A가 늦게 끝나면 화면에는 B가 재생 중으로 표시되는데 A 음성이 나온다.
`_previewLoadingVoiceId`가 이미 들고 있는 값으로 막았다 (새 필드 없음).

**42. 패롯 차감 실패가 조용했다**
`generateTts`가 성공한 뒤 `userProvider.addCoins(-cost)`를 기다리지 않았다.
차감이 실패하면 사용자는 음성을 받고 패롯은 안 깎인 채로 흔적이 없다.
앞서 고친 결제·광고 보상은 사용자가 손해 보는 쪽이었고 이건 앱이 손해 보는
쪽이다. 결과는 이미 손에 들어갔으니 되돌리지 않고 기록만 남긴다.

### 보류 — 판단이 필요하다

**버. 저장한 문장의 id도 32비트 해시다**
`my_sentence_store.dart`의 `idFor`가
`'my-$language-${text.trim().hashCode.toUnsigned(32)}'`를 문서 id로 쓴다.
같은 문장을 두 번 저장하면 합쳐지게 하려는 의도는 분명하지만, **서로 다른
문장이 같은 id가 되면 하나가 다른 하나를 덮어쓴다.** 저장한 문장이 사라지는
것이다. 1000문장이면 확률이 1e-4 언저리로 낮지만 0은 아니다.
TTS 캐시와 달리 여기는 id가 사용자 데이터의 신원이라, 바꾸면 이미 저장된
문장이 전부 끊긴다. 새 id로 쓰면서 옛 id도 읽는 이행 절차가 필요하고
그건 설계 판단이라 손대지 않았다.

### 보안 쪽으로 확인한 것

- API 키가 앱에 없다. TTS는 전부 Firebase Functions(`generateTts`,
  `listTtsVoices`, `listElevenLabsVoices`)를 거친다.
- 리포 전체에서 `AppLogger`에 키·토큰·비밀번호 값이 들어가는 자리는 없다.

### 깨끗했던 것

- `TtsProvider`는 엔진별 설정을 `GoogleTtsSettings`·`ElevenLabsTtsSettings`·
  `GeminiTtsSettings`로 나눠 들고 있어서 값이 서로 새지 않는다.
- 미리듣기 `AudioPlayer`는 시트 `dispose`에서 닫는다.
- 입력 240자 제한은 `TextField(maxLength: 240)`이 실제로 막고 있어서,
  Provider 쪽 `if (newText.length <= 240)` 가드는 도달하지 않는 방어선이다.

## 묶음 10 — 챗봇·영상·허브 (`chat-bot`, `video`, `hub`)

### 고친 것

**43. 콘텐츠 제작 Provider 셋에 dispose 가드가 없었다** — 이 묶음에서 가장 큰 것
`TtsProvider`, `VideoProvider`, `ChatBotProvider`는 `content_studio_hub_screen`에서
만들어진다. 앱 루트가 아니라 **화면마다** 만들어지고 화면을 떠나면 실제로
dispose된다. 그런데 셋 다 비동기 작업이 끝난 뒤 `notifyListeners`를 부른다.
TTS는 몇 초, 영상은 5초마다 폴링이고 몇 분 걸린다. 그 사이에 화면을 떠나면
dispose 뒤에 불린다.
**debug 빌드에서는 `ChangeNotifier`의 assert에 걸려 빨간 화면이 뜨고, release
에서는 조용히 넘어간다.** 사용자 피해는 없고 개발 중에만 터져서 더 늦게 보인다.
`notifyListeners`를 덮어써서 dispose 뒤에는 그냥 돌아가게 했다.
묶음 1에서 "루트 Provider라 지금은 문제가 안 된다"고 보류했던 항목인데,
화면마다 만드는 Provider에서는 실제로 걸린다.

**44. 영상 내려받기가 끊기면 반쯤 쓰인 파일이 남았다**
`prepareGeneratedVideoForCaptioning`이 생성된 영상을 임시 폴더로 내려받는다.
끊기면 반쯤 쓰인 mp4가 그대로 남는다. 영상이라 작지 않고 아무도 가리키지
않는다. `HttpClient`도 닫지 않아 연결이 정리되지 않았다. 둘 다 고쳤다.

**45. 영상 생성 뒤 패롯 차감 실패가 조용했다**
TTS와 같은 종류. 기다리고 실패하면 기록을 남긴다.

### 보류 — 판단이 필요하다

**서. 오류 로그 39곳이 Crashlytics에 안 간다**
`AppLogger.e`는 release에서 `FirebaseCrashlytics.recordError`를 부른다.
`debugPrint`는 안 부른다. 그런데 아직 `debugPrint`를 쓰는 자리가 11개 파일
39곳 있다. **그 실패들은 배포 뒤에 보이지 않는다.**

| 파일 | 횟수 |
|------|------|
| `chat-bot/presentation/chat_bot_provider.dart` | 9 |
| `chat-bot/presentation/widgets/chat_bot_sheet.dart` | 7 |
| `core/speech/phrase_recognizer.dart` | 7 |
| `core/content/cloud_sentence_assist.dart` | 4 |
| `chat-bot/data/repositories/ai_chat_repository_impl.dart` | 3 |
| `community/shell/data/services/community_image_service.dart` | 2 |
| `core/infrastructure/services/sso/naver_sso_service.dart` | 2 |
| `core/infrastructure/services/cache_service.dart` | 2 |
| 나머지 3개 파일 | 각 1 |

기계적으로 바꿀 수는 있지만 자리마다 `w`가 맞는지 `e`가 맞는지 다르고,
전부 `e`로 바꾸면 Crashlytics로 가는 양이 확 는다. 어느 선까지 올릴지는
판단이라 손대지 않았다. 챗봇(19곳)과 SSO(3곳)부터 보는 걸 권한다 —
돈과 로그인이 걸린 자리다.

**어. 영상 생성 폴링에 시간 제한이 없다**
`_startPolling`이 5초마다 `done`을 묻는데 멈추는 조건이 `done`과 예외뿐이다.
백엔드 작업이 끝났다고 보고하지 않으면 영원히 돈다. 화면을 떠나면
`dispose`가 타이머를 끊으므로 무한정은 아니지만, 사용자가 화면을 열어 둔
채 기다리면 과금되는 Cloud Function을 계속 부른다. 상한을 몇 분으로 둘지는
Veo 쪽 응답 시간을 알아야 정할 수 있어서 손대지 않았다.

### 깨끗했던 것

- `VideoProvider`는 `_pollingTimer`와 `_recentRefreshTimer`를 `dispose`에서
  둘 다 끊는다.
- `veo31ModelById`는 `orElse`가 있고, 비용 계산도 `durationSeconds <= 0`을
  먼저 막는다.
- 1080p가 8초만 지원하는 제약이 `isDurationLocked`와 `updateResolution`
  양쪽에 들어가 있어서 설정이 어긋나지 않는다.

## 묶음 11 — 공용 위젯·테마 (`lib/core/shared`)

### 고친 것

**46. 백그라운드 오디오 초기화가 한 번 실패하면 영영 안 살아났다** — 이 묶음에서 가장 큰 것
`BgAudio.ensureAudioHandler`는 `AudioService.init`의 Future를 `_booting`에
담아 재진입을 막는다. 그런데 **실패한 Future도 계속 들고 있었다.** 실패한
Future는 await할 때마다 같은 실패를 돌려주므로, 한 번 넘어지면 앱이 꺼질
때까지 백그라운드 재생이 안 살아난다. 실패하면 `_booting`을 비운다.

**47. 오프라인 안내 창이 겹쳐 쌓였다**
`OfflineScreen.build` 안에서 `addPostFrameCallback`으로 창을 띄웠다. 이 위젯은
`ThemeProvider`를 watch하므로 테마가 바뀌면 build가 다시 돌고 창이 하나씩 더
쌓인다. `barrierDismissible: false`라 닫을 수도 없다. 상태를 가진 호스트
위젯으로 옮겨 `initState`에서 한 번만 띄운다.

**48. 토큰에서 2dp 이내인 생숫자 반지름 42곳을 토큰으로 바꿨다**
`BorderRadius.circular`에 생숫자가 69곳 남아 있었다. 그중 3·5→`xs`,
9·10·13·14→`md`, 17·18→`lg`, 22→`xl`로 42곳을 바꿨다(24개 파일).
반지름은 레이아웃 크기를 바꾸지 않아 넘침이 생길 수 없고, 2dp 차이는 눈에
안 띈다. 시뮬레이터로 홈과 더보기를 찍어 확인했다.

### 보류 — 판단이 필요하다

**저. 남은 생숫자 반지름 27곳**
| 값 | 곳 | 가장 가까운 토큰까지 | 왜 안 바꿨나 |
|----|----|------|------|
| 6 | 12 | 2 (xs=4) / 2 (sm=8) | 양쪽이 똑같이 떨어져 있어 정할 수 없다 |
| 30, 32 | 10 | 6, 8 (xxl=24) | 눈에 보이게 달라진다 |
| 28 | 2 | 4 (xxl=24) | 같은 이유 |
| 40, 50 | 3 | pill로 볼지 큰 모서리로 볼지 다르다 | 의미 판단이 필요하다 |

**처. `AppSheet`를 뺄지 — 시트 35곳**
`showModalBottomSheet`가 35곳이고 **전부 `useRootNavigator: true`**다
(어젯밤 UI 작업에서 맞춘 것). 나머지는 제각각이다:
`isScrollControlled` 26곳, `backgroundColor`가 `Colors.transparent` 13곳,
`Theme.of(...)` 4곳, `cs.surface` 3곳, `context.tokens...` 2곳, 안 준 곳 13곳.
공용으로 뺄 가치는 있지만 35개 호출부를 전부 고쳐야 하고 결과가 35개 화면에
보인다. 그중 대부분은 지금 시뮬레이터로 열어 볼 수 없다. 눈으로 못 보고
35곳을 바꾸는 건 하지 않았다.

**커. `AppCard`를 뺄지 — `BoxDecoration` 271곳**
숫자는 크지만 대부분은 카드가 아니다(그라디언트, 테두리만, 원형 등).
"무엇을 카드로 볼지"부터 정해야 하고 그건 디자인 판단이다. 기준을 정해
주면 그 기준에 맞는 것만 뽑아 바꿀 수 있다.

**터. 친밀도 칩 색이 라이트·다크 공용이다**
`affinityChipColors`가 단계별 파스텔 배경 다섯 쌍을 그대로 들고 있다.
다크에서도 밝은 파스텔 칩이 된다. 다만 주석에 `assets/badges/affinity_N.svg`
뱃지 그림과 같은 계열로 맞춘 것이라고 적혀 있어서, 색을 바꾸면 그림과
어긋난다. 그림까지 같이 봐야 하는 일이라 손대지 않았다.

### 깨끗했던 것

- **`AppTokens`는 라이트·다크 32개 토큰이 모두 서로 다른 값을 갖는다.**
  한쪽에만 있거나 값이 같은 토큰이 하나도 없다.
- 이 묶음에는 삼킨 예외가 하나도 없다.
- `SentenceAffinity`는 `isMax => next == null`로 정의해서, `!isMax`일 때
  `next!`가 항상 안전하다. 불변식이 타입으로 지켜진다.
- `learning_language_picker`의 검색 컨트롤러는 `dispose`에서 닫는다.

## 묶음 12 — 앱 셸·라우터·인프라 (`lib/core/{app,infrastructure,content,speech}`)

### 고친 것

**49. 백업이 DB 없이 "완료"될 수 있었다** — 이번 리뷰 전체에서 가장 위험한 것
`BackupService._doCompress`가 파일을 읽다 실패하면 빈 catch로 넘기면서,
manifest에는 그 파일이 들어간 것처럼 적었다. 그래서:
1. DB를 못 읽으면 zip에 DB 없이 백업이 "완료"된다
2. manifest에는 DB가 있다고 적혀 있다
3. 복원하면 `Missing file from archive`로 실패한다

**백업이 쓸모없다는 걸 복원하는 순간에야 알게 된다.** 보통 그때는 원본이 없다.
- DB를 못 읽으면 백업 자체를 실패시킨다.
- 미디어 한 장 못 읽는 건 넘어가되 **실제로 담은 것만** manifest에 적는다.
- 앞뒤가 안 맞는 곳도 있었다: 읽기 실패는 삼키면서, 바로 아래 manifest를
  만들 때 부르는 `file.lengthSync()` 실패는 안 잡혀서 백업 전체가 넘어갔다.
- 바이트를 이미 들고 있으므로 sha256도 그걸로 계산한다(파일을 두 번 안 읽는다).

**50. SSO 로그인 실패가 배포 뒤에 보이지 않았다**
카카오는 `catch (e) { return null; }` 한 줄이라 **기록이 아예 없었고**,
네이버·애플은 `debugPrint`만 했다. `debugPrint`는 Crashlytics로 안 간다.
`AppLogger.e`로 바꿨다. 사용자가 직접 취소한 경우는 오류가 아니므로
카카오(`PlatformException` code `CANCELED`)와 애플
(`SignInWithAppleAuthorizationException.canceled`)은 구분해서 `d`로 뺐다.
네이버는 취소를 구분할 방법을 못 찾아 전부 `e`로 올린다.

**51. 로그아웃 실패가 공급자별로 기록되지 않았다**
`signOut`이 네이버·카카오·구글·Firebase를 차례로 부르는데 넷 다 빈 catch였다.
하나가 실패해도 계속하는 건 맞다 — 로그아웃은 사용자가 나가겠다는 것이다.
다만 특히 Firebase 로그아웃이 실패하면 로컬은 비워지는데 세션은 남는다.
동작은 그대로 두고 공급자 이름과 함께 기록만 남긴다.

**52. 광고 ID가 비면 조용히 광고가 꺼졌다**
`.env`에 `ADMOB_*` 키가 없으면 빈 문자열이 되고 `load()`가 그냥 돌아간다.
**배포 빌드에서 키 하나가 빠지면 광고 수익이 0인 채로 아무도 모른다.**
비면 `AppLogger.e`로 남긴다(release에서는 Crashlytics까지 간다).

**53. 배포 빌드에서 라우터 진단 로그가 켜져 있었다**
`debugLogDiagnostics: true`가 고정이라 화면을 옮길 때마다 경로를 기기 로그에
찍는다. 글 id·클립 id가 그대로 섞여 나간다. `!kReleaseMode`로 바꿨다.

### 보류 — 판단이 필요하다

**퍼. 인트로 화면이 통째로 빠져 있다**
`buildAppRouter(seenIntro: ...)`는 인자를 받기만 하고 쓰지 않는다. 주석에는
"인트로를 봤는지에 따라 초기 경로 결정"이라고 적혀 있지만 `initialLocation`은
늘 대시보드다. `/intro` 경로 상수와 `isOnIntro` 가드는 있는데 **그 경로의
`GoRoute`가 없어서 아무도 갈 수 없다.** `IntroPrefs.hasSeen()` 결과는
bootstrap에서 읽어서 버려진다. 인트로를 붙일 생각이면 자리가 그대로 있고,
안 붙일 생각이면 `IntroPrefs`까지 지울 수 있다. 기능 판단이라 주석만 고쳤다.

**허. "임시 보관 파일 삭제"가 편집 중인 영상도 지운다**
`CacheService.clearCache()`가 `getTemporaryDirectory()`를 통째로 지운다.
거기에는 `FileStagingService`가 쓰는 `video_staging` 폴더도 들어 있다.
클립을 만들다 말고 더보기에서 캐시를 지우면 올려 둔 영상이 사라진다.
화면 문구는 "앱이 잠깐 보관해 둔 파일들"이라 틀린 말은 아니지만,
작업 중인 파일은 캐시가 아니다. `video_staging`만 빼는 게 맞아 보이는데
그러면 그만큼 용량이 안 줄어든다. 어느 쪽인지는 제품 판단이다.

### 깨끗했던 것 — 눈여겨볼 만한 곳

- **`google_drive_storage_service.dart`(896줄)에 `catch`가 하나도 없다.**
  전부 `StateError`를 한국어 메시지와 함께 던지고 `AppLogger`로 남긴다.
  이번 리뷰에서 본 파일 중 오류 처리가 가장 잘 되어 있다.
- 백업의 **복원** 쪽은 손댈 데가 없었다. 경로 탈출 검사(`..`와 절대경로),
  sha256 검증, 실패 시 임시 폴더 정리, 교체 전 기존 DB 백업까지 있다.
- `lib/core/content`는 11개 테스트 파일이 붙어 있다. 리포에서 가장 촘촘하다.
- `sentence_transfer.dart`는 파싱 실패를 삼키지 않고 한국어 `FormatException`
  으로 바꿔 던진다.

## 묶음 13 — 설정·더보기 (`lib/features/settings`)

앞서 "돈이 걸린 경로" 절에서 고친 셋(코인 충전·광고 보상·페이월)과
묶음 8의 프로필 사진 순서가 이 묶음에 속한다. 나머지를 여기 적는다.

### 고친 것

**54. 탈퇴해도 닉네임이 영영 묶여 있었다**
`deleteAccount`가 `users` 문서와 Firebase Auth 계정만 지우고 `nicknames`
문서는 그대로 뒀다. `isNicknameAvailable`은 그 문서가 있는지만 보므로
**탈퇴한 계정의 닉네임은 아무도 다시 쓸 수 없다.** 본인이 다시 가입해도
못 쓴다. 탈퇴 한 번에 닉네임 하나가 영구히 사라진다.
`releaseNickname`을 넣고, 남이 이미 가져간 것이면 건드리지 않게 했다.
부르는 자리는 **Auth 계정 삭제 뒤**다 — 그쪽이 던지는 일이 드물지 않은데
(흔한 건 `requires-recent-login`), 먼저 풀면 계정은 살아 있는데 닉네임만
빼앗긴 상태가 된다.

**55. Crashlytics에 예외 객체 대신 문자열이 올라갔다**
`AppLogger.e`는 `error` 인자가 있으면 그걸 Crashlytics에 넘기고, 없으면
**메시지 문자열 자체를 오류로 기록한다.** 네 곳이 `AppLogger.e('... $e')`로
예외를 메시지에 끼워 넣고 `error`는 비워 뒀다. 그러면 스택 트레이스가 안
붙고, `$e` 내용이 조금만 달라도 전부 다른 이슈로 쪼개져서 몇 번 일어났는지도
안 보인다. (IAP 초기화·구매 복원, 환전, FFmpeg) `error: e`로 넘긴다.

### 보류 — 판단이 필요하다

**고. 탈퇴가 중간에 실패하면 문서만 지워진 상태가 된다**
`deleteAccount`는 ①users 문서 삭제 → ②Auth 계정 삭제 순이다. ②가
`requires-recent-login`으로 던지는 건 흔한 일인데, 그러면 **문서는 없는데
계정은 살아 있는 상태**가 된다. 그 상태로 앱을 쓰면 라우터가 닉네임 없는
사용자로 보고 온보딩으로 보내고, 문서가 새로 만들어진다. 복구는 되지만
사용자 입장에선 "탈퇴했는데 다시 가입 화면"이다.
제대로 하려면 탈퇴 전에 재인증을 요구하거나, Auth 삭제 트리거로 도는
Cloud Function에서 정리해야 한다. 둘 다 설계 판단이라 손대지 않았다.

### 깨끗했던 것

- 환전 화면은 수량 검증, 잔액 확인, 1000 단위 제한, 진행 중 버튼 비활성화,
  실패 시 서버에서 유저를 다시 읽어 롤백까지 되어 있다.
- `backup_progress_dialog`는 콜백마다 `mounted`를 본다.
- 이 묶음에 삼킨 예외는 한 곳뿐이었다.

## 묶음 14 — 인증 (`lib/features/auth`)

**이 네 화면은 로그인 상태라 시뮬레이터로 못 봤다. 코드만 봤다.**
고친 것은 둘 다 "삼키던 예외를 잡아 안내한다"뿐이라 기존 성공 경로는
건드리지 않았다.

### 고친 것

**56. 이메일 로그인·회원가입·비밀번호 찾기가 조용히 실패했다**
세 화면 모두 `on FirebaseAuthException`만 잡고 일반 catch가 없었다.
Firestore 문서 쓰기 실패, 타임아웃(`loadUserDocument`에 5초 제한이 있다),
그 밖의 예외는 아무 데도 안 잡혀 비동기 오류로 사라진다. 토스트도 안 뜨고
화면도 그대로다. **사용자 눈에는 버튼이 먹통인 것으로 보인다.**
같은 파일의 SSO 네 경로(구글·카카오·네이버·애플)는 이미 일반 catch를 두고
있었다. 이메일 경로 셋만 빠져 있었다.

**57. 닉네임 중복 확인이 조용히 실패하거나 사라진 화면을 건드렸다**
회원가입과 온보딩의 `_checkNickname`이 await 결과를 바로 `setState`에 넣었다.
try도 `mounted` 검사도 없다. 네트워크가 흔들리면 아무 안내가 없고, 확인을
누른 뒤 뒤로 가면 사라진 화면에 `setState`가 불려 터진다.
**`analyze`는 이걸 못 잡는다** — `use_build_context_synchronously`는
`BuildContext`를 보지 `setState`를 보지 않고, `context.read`는 await 전에
끝나기 때문이다. 프로필 수정 화면에 이미 있던 모양(try/catch + mounted)으로
맞췄다. 실패하면 `_hasCheckedNickname`도 false로 되돌린다 — 확인 안 된
닉네임으로 가입이 진행되면 안 된다.

### 깨끗했던 것

- 네 화면 모두 컨트롤러를 `dispose`에서 닫는다.
- SSO 네 경로는 처음부터 `FirebaseAuthException`과 일반 예외를 나눠 받고 있다.


---

# 정리 — 네가 판단할 것만

묶음 14개를 다 돌았다. 고친 것 57개, 아래는 **내가 정하지 않고 남긴 것**이다.
급한 순서로 묶었다.

## 1. 출시 전에 보는 게 좋은 것

### 저장한 문장 id가 32비트 해시다 (묶음 9 "버")
`my_sentence_store.dart`의 `idFor`가
`'my-$language-${text.trim().hashCode.toUnsigned(32)}'`를 **문서 id**로 쓴다.
서로 다른 문장이 같은 id가 되면 **하나가 다른 하나를 덮어쓴다. 저장한 문장이
사라진다.** 1000문장이면 확률이 1e-4 언저리로 낮지만 0이 아니고, 쌓일수록 는다.
TTS 캐시 쪽은 같은 문제라 sha256으로 바꿨다(고침 39). 여기는 id가 사용자
데이터의 신원이라 바꾸면 **이미 저장된 문장이 전부 끊긴다.** 새 id로 쓰면서
옛 id도 읽는 이행이 필요하다.

### 글 목록이 20개에서 멈춘다 (묶음 7 "더")
`_lastDocument`가 선언돼 있고 `getPosts(startAfter:)`로 넘어가는데 **어디에서도
값이 들어가지 않는다.** `getPosts`가 마지막 `DocumentSnapshot`을 안 돌려주기
때문이다. 지금 호출부가 전부 `refresh: true`라 버그로는 안 보이지만,
**게시판·질문·투표가 각각 최신 20개까지만 보이고 그 뒤는 볼 방법이 없다.**
`ActivityProvider`는 같은 일을 제대로 하고 있으니 그걸 본보기로 쓰면 된다.
덧붙여 `refresh`의 기본값이 `false`라, 앞으로 누가 그냥 `fetchPosts()`를
부르면 같은 20개가 조용히 두 번 쌓인다.

### 눌러도 아무 일 없는 버튼 12개 (전 화면 공통 절)
커뮤니티 검색, 게시글 알림 끄기, 댓글 사진 첨부, 질문 쓰기의 이미지·마이크·
링크·태그 네 개, 홈 무대의 `filledTonal` "문장 추가", 보관함 "전체"와 단어
카드, 더보기 앱 정보 줄. 기능을 넣을지, 지울지, 회색으로 둘지는 전부 다르다.
특히 홈의 "문장 추가"는 **칠해진 버튼**이라 가장 누르라고 말하는 모양이다.

### 결제에 서버 검증과 지급 재시도가 없다 (돈 경로 "파")
결제 성공을 클라이언트가 판단하고 클라이언트가 코인을 더한다. 지급이 실패하면
지금은 안내만 하고 끝이다. 이번에 "화면이 사라져서 지급을 아예 안 하던" 경로
셋은 막았지만(고침 24·25·26), 지급 자체가 실패하는 경우는 여전히 남는다.

### 탈퇴가 중간에 실패하면 문서만 지워진다 (묶음 13 "고")
①users 문서 삭제 → ②Auth 계정 삭제 순인데 ②의 `requires-recent-login`은
흔하다. 그러면 문서는 없는데 계정은 살아 있고, 다시 들어가면 온보딩으로 간다.
"탈퇴했는데 다시 가입 화면"이 된다. 재인증을 먼저 받거나 Auth 삭제 트리거로
도는 Cloud Function이 필요하다.

### 오류 로그 35곳이 Crashlytics에 안 간다 (묶음 10 "서")
`debugPrint`는 Crashlytics로 안 간다. 이번에 SSO 3곳을 `AppLogger.e`로
바꿨지만(고침 50) 아직 **11개 파일 35곳**이 남았다. 챗봇 19곳이 가장 많다.
자리마다 `w`가 맞는지 `e`가 맞는지 다르고, 전부 `e`로 올리면 Crashlytics로
가는 양이 는다. 파일별 횟수는 묶음 10 절에 표로 있다.

### iOS에서 `exit(0)`을 부른다 (묶음 11 "47" 커밋 메모)
오프라인 안내 창의 "확인"이 `exit(0)`이다. 애플 심사 지침은 앱이 스스로
종료하는 걸 권하지 않는다. 정책 판단이라 그대로 뒀다.

## 2. 데이터가 걸린 것

### 캐시 삭제가 편집 중인 영상도 지운다 (묶음 12 "허")
`CacheService.clearCache()`가 임시 폴더를 통째로 지우는데 거기에
`FileStagingService`의 `video_staging`이 들어 있다. 클립을 만들다 말고
더보기에서 캐시를 지우면 올려 둔 영상이 사라진다. 작업 중인 파일은 캐시가
아니지만, 빼면 그만큼 용량이 안 줄어든다.

### 클립 내용이 바뀌어도 목록이 안 바뀔 수 있다 (묶음 6 "거")
`applyNow`의 `_sameIds`와 `library_tag_section`의 `Selector.shouldRebuild`가
둘 다 **클립 id만** 비교한다. 제목을 고친 클립이 태그 필터가 걸린 목록에서
옛 제목으로 남을 수 있다. id만 비교하는 건 불필요한 리빌드를 줄이려는
의도가 분명해서 뒤집지 않았다. 클립이 0개라 재현도 못 했다.

### `(name, storage_mode)`에 unique index를 걸지 (묶음 2 "바")
트랜잭션으로 막아 뒀지만(고침 7) index는 못 생기게 하는 쪽이다. 스키마
변경이라 v4 마이그레이션이 필요하고, 이미 중복이 생긴 기기에서는 index
생성 자체가 실패하니 병합 절차도 함께 정해야 한다.

### FK `onDelete`가 테이블마다 다르다 (묶음 2 "사")
`recentClipViews`·`clipTags`는 cascade인데 `clipSourceRefs`·`clipCacheEntries`·
`segments`·`groupCollections`·`clips.collectionId`는 없다. 지금 지우는 두 곳은
자식을 제대로 먼저 지우고 있어서 살아 있는 버그는 아니지만, 새로 지우는
코드를 쓰면 또 밟는다. 맞추려면 v4 마이그레이션이 필요하다.

### v2→v3 마이그레이션의 죽은 64줄을 지울지 (묶음 2 "마")
118줄 중 64줄이 도달 불가능이다(고침 9에서 주석으로 표시). 내 판독으로는
분명하지만 이미 사용자 기기에서 돌아간 마이그레이션이라, 틀렸다면 복구
로직을 없애는 셈이 된다. 지우라고 하면 한 커밋으로 지운다.

## 3. 구조·디자인

- **`AppSheet`를 뺄지** (묶음 11 "처") — 시트 35곳. 전부 `useRootNavigator: true`
  까지는 맞췄고 나머지 인자가 제각각이다. 35개 화면이 바뀌는데 대부분 지금
  열어 볼 수 없다.
- **`AppCard`를 뺄지** (묶음 11 "커") — `BoxDecoration` 271곳. 대부분은 카드가
  아니다. "무엇을 카드로 볼지" 기준을 주면 그에 맞는 것만 뽑을 수 있다.
- **남은 생숫자 반지름 27곳** (묶음 11 "저") — `6`이 12곳인데 4와 8에서 똑같이
  2dp 떨어져 있다. 28·30·32는 4dp 넘게 차이 나서 눈에 보이게 달라진다.
- **자막 편집기 터치 영역** (묶음 4 "타") — `segment_card`의 삭제·추가 32×32,
  `video_controls_bar`의 `_ControlButton` 34~36. 44pt보다 작다. 빽빽한 화면이라
  키우면 줄 간격이 밀리는데, 영상을 골라야 나오는 화면이라 못 봤다.
- **친밀도 칩 색이 라이트·다크 공용** (묶음 11 "터") — `affinity_N.svg` 뱃지
  그림과 색을 맞춘 것이라 그림까지 같이 봐야 한다.
- **목표 버튼이 상태에 따라 다른 컨트롤** (묶음 5 "하") — 목표를 채우면 라벨 없는
  `IconButton`(44pt 미만), 못 채우면 `TextButton.icon`('목표 설정'). 같은 동작인데
  모양도 글자도 바뀐다.
- **시간 표시 규칙이 둘** (묶음 3 "차") — 알림은 7일 넘으면 "11/5", 글은 "100일 전".
- **댓글 입력 제출 함수가 세 화면에 거의 같은 모양** (묶음 3 "카") — 컨트롤러 이름,
  대상 id, 토스트 문구, 스크롤 처리가 달라 공유할 표면이 작다.
- **인트로 화면이 통째로 빠져 있다** (묶음 12 "퍼") — `/intro` 상수와 가드는 있는데
  `GoRoute`가 없어 아무도 갈 수 없다. `IntroPrefs.hasSeen()` 결과는 버려진다.
  붙일 거면 자리가 그대로 있고, 안 붙일 거면 `IntroPrefs`까지 지울 수 있다.

## 4. 동작을 바꿔야 해서 안 건드린 것

- **좋아요·추천·스크랩에 진행 중 가드 없음** (묶음 3 "자") — 빠르게 두 번 누르면
  두 요청이 겹친다. 가드를 넣으면 누른 게 무시되는 순간이 생긴다.
- **이미지 하나가 실패하면 그 이미지만 조용히 빠진다** (묶음 7 "러") — 사진 셋을
  붙였는데 하나가 실패하면 둘만 올라간 글이 아무 말 없이 등록된다. 막는 쪽이
  맞아 보이지만 그러면 업로드가 한 번 흔들릴 때 글 전체가 막힌다.
- **이미 투표한 글을 다시 누르면 화면이 잠깐 바뀐다** (묶음 7 "머") — 서버가
  거절하는데 낙관적 업데이트가 먼저 보인다. 아예 못 누르게 할지는 기능 판단.
- **영상 생성 폴링에 시간 제한 없음** (묶음 10 "어") — 상한을 몇 분으로 둘지는
  Veo 응답 시간을 알아야 정할 수 있다.
- **`UserPrefs.loadUser`의 기본값이 `AppUser`와 다르다** (묶음 2 "아") —
  `AppUser`는 20/1000, `loadUser`는 0/0. "모르면 0"이 통화로는 안전한 쪽이라
  그대로 뒀다.
- **루트 Provider의 dispose 가드** (묶음 1 "라") — 화면 Provider 셋은 고쳤다
  (고침 43). 루트 Provider는 앱이 끝날 때만 걸려서 그대로 뒀다.
- **태그 watch를 화면 떠날 때 멈출지** (묶음 1 "가") — 두 화면이 구독 하나를
  공유하는 구조라 참조 세기나 주인 정하기가 필요하다.
- **`deleteClipById`가 원격을 먼저 지운다** (묶음 1 "나") —
  `LibraryEntitySyncCoordinator`에 "로컬을 먼저 하면 pull이 오인한다"는 설명이
  있어서, 삭제도 같은 이유일 수 있다. 동기화 설계 판단이다.
- **`AppUser` watch가 필드를 하나씩 적어서 베낀다** (묶음 1 "다") — 앞으로 필드를
  더하면 조용히 갱신되지 않는다. 지금은 빠진 게 없다.
- **`_notifyListenersSafe`가 아무것도 막지 않는다** (묶음 3 "19") — 쉰 곳 넘는
  호출의 의미를 바꾸는 일이라 주석만 달았다.
- **`ShortsRepository`를 가짜로 못 바꾼다** (묶음 6 "너") — 구체 타입을 받고
  그 안에서 `FirebaseAuth.instance`를 읽는다. 쇼츠 버그(고침 27)는 테스트로
  잡기 좋은데 넣지 못했다.
- **`_BoardChip`의 `isDropdown`은 죽은 코드** (묶음 3) — `'최신'`이 필터 목록에
  없어 한 번도 참이 안 된다. 정렬 드롭다운 자리인지 그냥 남은 것인지 모른다.

---

# 2차 — 서버와 보안 규칙 (lib/ 밖)

1차 리뷰는 `lib/`만 돌았다. 2차에서 `functions/src`, `firestore.rules`,
`storage.rules`를 봤다. 아래는 고친 것이다.

## 서버 (functions/src)

### 1. 로그인 없이 부를 수 있던 유료 API 함수 셋
`generateTts`, `listTtsVoices`, `listElevenLabsVoices`에 인증 검사가 없었다.
세 함수 모두 ElevenLabs, Gemini, Google Cloud TTS의 과금 호출을 하는데,
함수 주소만 알면 로그인하지 않고도 호출할 수 있었다. 패롯 차감은 앱에서만
하므로 외부에서 직접 부르면 요금은 그대로 나가고 차감되는 것은 없다.
같은 파일의 `generateVideo`, `getVideoOperationStatus`,
`listVideoGenerations`는 이미 같은 검사를 하고 있었다.

### 2. 남의 영상 생성 요청을 조회할 수 있었다
`getVideoOperationStatus`가 내 기록에 없는 `operationName`도 그대로 Gemini에
물어봤다. 호출자는 로그인만 되어 있으면 됐고 소유권은 확인하지 않았다.
operationName을 알면 다른 사람이 만든 영상의 주소를 받을 수 있었고, 아무
이름이나 넣어도 유료 호출이 나갔다.

### 3. 오류 코드를 덮어쓰던 catch 넷
`generateTts`, `listTtsVoices`, `listElevenLabsVoices`,
`createNaverCustomToken`이 모든 오류를 하나의 코드로 다시 포장했다.
"로그인이 필요합니다", "지원하지 않는 엔진", "네이버 인증 실패"가 앱에서는
전부 같은 오류로 보였다.

### 4. 알림이 다시 전달되면 읽은 표시가 풀렸다
`saveNotification`이 이미 있는 알림 문서에도 `isRead:false`, `readAt:null`,
`createdAt`을 다시 썼다. Cloud Functions는 같은 이벤트를 두 번 보낼 수 있고,
투표 종료 알림은 보내는 중에 끊기면 다음 차례에 전부 다시 보낸다. 그러면
이미 읽은 알림이 안 읽음으로 되돌아가는데 이 길에서는
`unreadNotificationCount`를 올리지 않으므로, 뱃지 숫자와 실제 안 읽은
개수가 어긋난다.

### 5. 못 쓰게 된 FCM 토큰이 영영 쌓였다
앱은 자기 토큰만 `arrayRemove`할 수 있다. 앱을 지우거나 토큰이 바뀌면 옛
토큰은 아무도 치우지 않고 `fcmTokens`에 계속 쌓이고, 매번 발송 대상에
들어가 전부 실패한다. 발송 결과에서 등록이 끊긴 토큰만 골라 지운다.

### 6. 투표 종료 알림 팬아웃에 상한이 없었다
참여자 전원을 하나의 `Promise.all`에 넣었다. 한 명마다 트랜잭션 하나와
유저 문서 조회 하나, 발송 하나가 들어가므로 참여자가 많은 투표에서는 수천
개의 요청이 한꺼번에 나간다. 50명씩 끊는다.

### 7. 네이버 첫 로그인의 경쟁 상태
같은 계정으로 두 번 동시에 로그인하면 양쪽 다 `user-not-found`를 보고 둘 다
`createUser`를 부른다. 늦은 쪽은 `uid-already-exists`로 실패하는데, 그건
원하던 결과가 이미 이루어진 것이다. 전에는 로그인 실패가 됐다.

## 보안 규칙

에뮬레이터로 검증하는 환경을 `test_rules/`에 두고 31개 테스트를 썼다.
옛 규칙에 대고 돌리면 22개가 깨진다.

### 8. posts와 그 하위가 전부 `allow read, write: if true`
로그인하지 않은 누구나 아무 글이나 고치고 지울 수 있었다. 커뮤니티 전체를
지우는 데 계정도 필요하지 않았다. `users` 하위의 likes, scraps,
comment_likes, voted_posts도 같았다.

### 9. 닉네임 문서를 남이 가져갈 수 있었다
`allow write: if request.auth != null`이라, 로그인한 사람이면 남이 쓰는
닉네임 문서를 덮어쓰거나 지울 수 있었다.

### 10. 남의 크래커를 0으로 만들 수 있었다
답변 채택이 남의 크래커를 올려 주기 위한 `hasOnly(['crackers'])` 조건에 값
제한이 없었다. 올리는 쪽만 남겼다.

### 11. Storage에서 남의 파일을 덮어쓸 수 있었다
모든 경로에 `allow write: if request.auth != null` 하나뿐이었다. 로그인한
사람은 누구나 남의 프로필 사진과 글 사진, 올려 둔 클립을 덮어쓰거나 지울
수 있었고, 아무 경로에나 파일을 올릴 수 있었다.

## 보류에서 꺼내 고친 것

### 12. 글 목록이 20개에서 멈추던 것 (데이터 쪽만)
`getPosts`가 커서를 안 돌려줘서 `_lastDocument`가 끝까지 null이었다.
`PostPage`로 커서와 `hasMore`를 돌려주고 `loadMorePosts()`를 더했다.
**화면은 건드리지 않았다.** 게시판·질문·투표 목록에 스크롤 끝 감지가 없어
`loadMorePosts`를 부르는 곳이 아직 없다.

### 13. 삼키던 오류 12곳을 AppLogger로
사용자가 아무 안내도 못 받는 다섯 곳은 `e`(Crashlytics까지), 설계상
넘어가기로 한 일곱 곳은 `w`로. 남은 `debugPrint` 25곳은 진행 로그여서
그대로 뒀다.

### 14. v2→v3 마이그레이션의 죽은 64줄
UPDATE가 WHERE 없이 모든 클립을 'local'로 덮어쓴 뒤 그 값으로 모드를 갈라서
분리 루프에 도달한 적이 없다.

### 15. 눌러도 아무 일 없던 버튼 11개를 비활성으로
여덟 자리. 기능을 넣을지 지울지는 각각 다른 판단이라, 그때까지 누를 수
없게 뒀다.

### 16. 비활성 TextButton이 배경에 묻혀 사라지던 테마 버그
`appTextButtonTheme`의 비활성 글자색이 `cs.surface`였다. 버튼이 놓인 배경과
같은 색이라 비활성 TextButton은 글자가 안 보이고 빈 자리만 남았다. 같은
파일의 다른 세 버튼 테마는 모두 `onSurface`를 쓴다. 15번을 하다 발견했다.

---

# 2차 보류 — 네가 판단할 것

## 1. 출시 전에 보는 게 좋은 것

### 투표 종료 알림이 10분마다 모든 투표 글을 읽는다
`onVoteEndNotification`이 `where('postType','==','vote')`로 **전부** 가져온
뒤 메모리에서 거른다. 상한도, 마감 시각 조건도, 보낸 표시 조건도 없다.
투표 글이 1만 개면 10분마다 1만 번 읽는다. 하루 144만 번이다. 지금은 글이
적어 안 보이지만 쌓이는 만큼 요금이 는다.
고치려면 새 투표 글에 `voteEndNotificationSentAt: null`을 넣고
`where('voteEndNotificationSentAt','==',null)`로 거르는 게 정석인데, 기존
글 보정과 복합 색인이 함께 필요하다.

> **3차: 의도한 설계, 유지.** 사용자가 직접 만든 구조라고 확인했다. 손대지 않는다.

### 네이버 토큰이 어느 앱 것인지 확인하지 않는다
`createNaverCustomToken`은 받은 access token을 네이버 `/nid/me`에 그대로
보내고, 응답의 id로 Firebase 커스텀 토큰을 만든다. 그 토큰이 **이 앱에
발급된 것인지** 확인하지 않는다. 다른 네이버 앱에 발급된 토큰으로도
`naver:<id>` 계정에 로그인할 수 있다는 뜻이다. 네이버 API로 이걸 확인할
방법이 있는지부터 알아봐야 한다.

### App Check이 없다
모든 Cloud Function이 `enforceAppCheck` 없이 열려 있다. 인증을 붙였으니
아무나는 못 부르지만, 계정 하나만 있으면 앱 밖에서 무제한으로 부를 수 있다.
영상·TTS·챗봇은 호출당 요금이 나간다.

### 패롯과 크래커를 앱이 직접 쓴다
규칙상 자기 user 문서는 통째로 쓸 수 있다. 즉 사용자가 자기 패롯·크래커를
원하는 값으로 바꿀 수 있다. 막으려면 지급·차감을 Cloud Function으로 옮기고,
규칙에서 그 두 필드의 클라이언트 쓰기를 아예 막아야 한다. 결제 서버 검증과
같은 작업이다.

### 네이버 이메일이 이미 다른 계정에 있으면 로그인이 영영 안 된다
`createUser`가 `auth/email-already-exists`로 실패한다. 구글로 먼저 가입한
사람이 네이버로 로그인하면 이 경우다. 계정을 합칠지, 이메일 없이 만들지
정해야 해서 그대로 뒀다.

## 2. 구조

### Provider를 테스트에서 만들 수 없다
`CommunityProvider()`는 생성자에서 `CommunityRepository()`와
`FirebaseUserService()`를 직접 만들고, 그 안에서
`FirebaseFirestore.instance`를 즉시 읽는다. 그래서 테스트에서 만들면
`[core/no-app]`으로 터진다. `VideoProvider`도 같다
(`VideoRemoteDataSource`가 `FirebaseFunctions.instance`를 필드로 들고 있다).

이번에 고친 버그 중 **낙관적 업데이트 되돌리기 다섯 곳**(댓글 좋아요, 추천,
스크랩, 글 수정·삭제)이 여기 막혀 테스트를 못 넣었다. `CommunityRepository`는
이미 `firestore`를 생성자로 받으니, Provider도 저장소를 받게만 하면 된다.
작은 변경인데 다섯 개 버그가 테스트로 묶인다.

> **3차: 처리.** `07a506d5`에서 CommunityProvider가 저장소·이미지 서비스·유저
> 서비스를 받게 했고 다섯 곳에 회귀 테스트를 넣었다. `21bc0b2e`에서 VideoProvider도
> use case를 다 받으면 Firebase를 건드리지 않게 했다.

### 백업 압축을 테스트할 수 없다
`_doCompress`는 isolate 안에서 도는 private static이고, `createBackup`은 끝에
파일 선택창을 띄운다. 1차에서 고친 가장 나쁜 버그(DB 없이 백업이 "완료"되고
manifest는 있다고 적던 것)에 테스트가 없는 이유다. 압축 부분을 따로 부를 수
있게 빼야 테스트가 가능하다.

> **3차: 처리.** `593c80e1`. 압축만 `BackupService.compressBackup`으로 공개했다.

### 글 목록 무한 스크롤을 붙일지
12번에서 데이터 쪽은 준비됐다. 게시판·질문·투표 목록에 스크롤 끝 감지를
붙이면 21번째 글부터 보인다. 세 화면의 동작이 바뀌고, 글이 20개 넘게 있어야
확인된다.

> **3차: 처리.** `bcc53d1f`. 자동 읽기와 '이전 글 더 보기' 버튼을 함께 붙였다.

### 죽은 버튼 11개에 무엇을 넣을지
15번에서 비활성으로 바꿔 뒀다. 기능을 넣기로 하면 그 자리에 그대로 연결하면
된다. 홈 무대의 '문장 추가'가 가장 눈에 띄는 자리다.

## 3. 배포

**규칙과 함수는 커밋만 했고 배포하지 않았다.** `firebase deploy`는 네가
해야 한다. 규칙을 배포하면 앱의 쓰기 권한이 곧바로 좁아지므로,
`test_rules`의 31개가 통과한다는 것과 별개로 실제 기기에서 글쓰기·추천·
댓글·투표를 한 번씩 해 보는 게 좋다.
