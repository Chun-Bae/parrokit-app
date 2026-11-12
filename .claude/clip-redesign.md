# 보관함 클립 탭 개편 계획

2026-11-12 작성. 사용자가 "구조가 별로"라고 한 미디어 클립 부분의 개편안이다.
아직 아무것도 구현하지 않았다. 시안은 대화에 그림으로 보여줬다.

## 지금 구조와 문제

화면: 클립 탭 → 저장 위치(로컬/서버/클라우드) → 보기(유형별/태그별) → 그룹 → 컬렉션 → 클립.
영상 하나를 열려면 네 번을 고른다.

데이터(drift, schemaVersion 3):

| 표 | 하는 일 | 문제 |
|---|---|---|
| `clips` | 영상 + `collectionId`(하나) + `storageMode` + `filePath`/`sourceFilePath` | 클립이 폴더 하나에만 들어간다. 파일 정보가 여기와 아래 두 표에 흩어져 있다 |
| `collections`, `groups` | 이름 + `storageMode` + `remoteId` | 폴더가 저장 위치에 묶여서, 같은 폴더에 기기 영상과 Drive 영상을 같이 못 넣는다 |
| `group_collections` | 그룹 ↔ 컬렉션 | 정리 단계가 두 겹 |
| `clip_source_refs` | 서버/Drive 원격 문서·파일 id | `clip_cache_entries`와 키가 같은데 따로 있다 |
| `clip_cache_entries` | 원격 영상의 기기 캐시 | |
| `tags`, `clip_tags` | 태그 | 괜찮다. 화면에서 "태그로 보기" 탭으로 갈라진 게 문제 |

그룹·컬렉션은 Firestore `users/{uid}/namespaces/library/{groups|collections}/{remoteId}`와
Drive에도 저장 위치별로 따로 동기화된다(`library_entity_*` datasource). 영향 범위:
`storageMode` 37파일, `collectionId` 19파일, `groupId` 9파일.

## 바꿀 방향

**영상 한 목록 + 재생목록 + 저장 위치는 클립의 속성.**

1. 저장 위치를 맨 앞 선택에서 뺀다. 클립마다 기기·클라우드 배지, 목록 위에 필터 칩.
   위치 바꾸기는 클립 메뉴의 "클라우드로 옮기기 / 기기에 받아두기"
2. 그룹 → 컬렉션 두 겹을 "재생목록" 하나로. 클립 하나가 여러 재생목록에 들어간다
3. 태그는 필터 칩. "태그로 보기" 탭은 없앤다(기능은 칩으로 남는다)
4. 화면: 이어보기 한 줄 → 재생목록 칸 → 모든 클립(정렬·필터). 추가 버튼은 하나
5. 재생목록 화면: 이어서 재생, 섞기, 클립 목록(위치가 섞여도 된다)

## 단계 (각 단계는 따로 출시하고 되돌릴 수 있다)

### 1단계: 화면만 (데이터 그대로)
- 새 클립 탭을 별도 파일로 만들고, 기존 `library_screen`은 남긴다. 설정 스위치로 전환
  (실험 화면은 원본 유지 규칙)
- 저장 위치 선택을 없애고, 세 위치의 클립을 한 목록으로 합쳐 보여준다. 위치는 배지·필터
- "재생목록" 칸은 지금 컬렉션을 그대로 보여준다(그룹은 칸 위 작은 머리말이나 필터로)
- 이어보기는 `recent_clip_views`를 쓴다
- 위험: 낮음. 데이터를 바꾸지 않는다

### 2단계: 데이터 (drift v3 → v4)
- 새 표 `clip_files`: `clipId, location(device|server|gdrive), path, remoteDocId, remoteFileId,
  storagePath, downloadUrl, thumbnail*, cachedPath, storageBytes, cachedAt, lastAccessedAt`.
  `clips.filePath/sourceFilePath` + `clip_source_refs` + `clip_cache_entries`를 옮긴다
- 새 표 `playlists`(`id, name, remoteId, sortOrder`)와 `playlist_clips`(`playlistId, clipId, position`)
- 옮기기: 컬렉션 → 재생목록 1:1, `clips.collectionId` → `playlist_clips` 한 줄.
  그룹은 "그룹 이름 / 컬렉션 이름" 재생목록으로 펴거나 태그로 바꾼다(아래 결정 필요)
- 옛 표와 열은 한 버전 동안 지우지 않고 남긴다(읽기만). 다음 버전에서 정리
- 원격: Firestore에 `playlists`를 새로 쓰고, 옛 `groups/collections` 문서는 읽기 전용으로 둔다.
  Drive 폴더 구조는 파일 위치라 그대로 둔다(재생목록은 메타데이터로만)
- 확인: 실제 사용자 DB 복사본으로 마이그레이션 테스트, 백업 파일 복원도 확인
- 위험: 높음. 사용자 데이터 이동. 백업을 먼저 받게 안내한다

### 3단계: 정리
- 1단계 스위치와 옛 화면, 옛 표·열 제거. 코드 생성(`build_runner`) 다시

## 정해야 할 것
1. 그룹을 어떻게 옮길지: (a) "그룹 / 컬렉션" 이름의 재생목록으로 펴기, (b) 그룹을 태그로
   바꾸기, (c) 재생목록 묶음(폴더)으로 한 단계 남기기. 추천은 (b)
2. 서버(앱 서버 저장)는 지금 잠겨 있다. 계속 숨길지
3. 1단계를 별도 실험 화면으로 둘지, 바로 교체할지
