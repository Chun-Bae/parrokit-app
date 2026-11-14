// 지워졌거나 못 여는 글을 열었을 때의 안내(5차).
//
// 전에는 제목이 '게시글을 찾을 수 없습니다.'인 가짜 글을 만들어 보통 글처럼
// 그렸다. 작성자 '알 수 없음', 조회 0, 공감·스크랩 버튼, '첫 댓글을 남겨
// 보세요'와 댓글 입력칸까지 살아 있어서, 없는 글에 댓글을 쓰려다 실패했다.
const String missingPostTitle = '글을 볼 수 없어요';
const String missingPostDescription = '지워졌거나 비공개로 바뀐 글이에요.';
const String missingPostBackLabel = '뒤로 가기';
