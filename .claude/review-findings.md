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
