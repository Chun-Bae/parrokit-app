// 하루 목표와 학습 캘린더가 세는 것의 말(5차 466).
//
// 홈 한 화면이 '내가 연습한 문장'을 세 숫자로 말하고 있었다.
//   - 내 문장 기록 '연습한 문장 6'  → 한 번이라도 다룬 문장 **가짓수**
//   - 학습 캘린더 '누적 2문장'      → 따라 말한 **횟수** 누계
//   - 내 문장 기록 '따라 말하기 5회' → 따라 말한 횟수(기록 DB 기준)
// 셋 다 '문장'이라고 적혀 있어 어느 것이 맞는 수인지 알 수 없었다.
// 같은 문장을 다섯 번 따라 말해도 목표 '5문장'이 채워지므로, 목표와
// 캘린더가 세는 것은 가짓수가 아니라 횟수다.
//
// 그래서 '문장'은 가짓수에만 쓰고, 목표·캘린더는 '번'으로 적는다.

/// 목표와 캘린더가 세는 단위.
const String practiceCountUnit = '번';

/// '3 / 5번' 처럼.
String practiceOfGoalLabel(int done, int goal) =>
    '$done / $goal$practiceCountUnit';

/// 목표까지 남은 것.
String practiceRemainingLabel(int remaining) =>
    '$remaining$practiceCountUnit 남음';

/// 지금까지 쌓인 전체.
String practiceTotalLabel(int total) =>
    '지금까지 총 $total$practiceCountUnit 연습했어요';

/// 학습 캘린더 머리의 수(5차 501).
///
/// 전에는 '누적 N번'이라 처음부터 지금까지를 적었다. 그런데 그 값은 캘린더가
/// 따로 들고 있는 누계라, 같은 화면 위쪽 '내 문장 기록 · 따라 말하기 N회'와
/// 어긋났다(3번 vs 6번). 기록을 쌓기 시작한 때가 달라서인데, 보는 사람은
/// 같은 것을 세는 두 숫자가 다른 이유를 알 길이 없었다.
///
/// 그래서 캘린더가 **스스로 아는 것**, 곧 지금 펼친 달의 합을 적는다.
/// 날짜를 눌러 더해 보면 맞는 수라 어긋날 수 없다.
String practiceCalendarMonthLabel(int month, int total) =>
    '$month월 $total$practiceCountUnit';

/// 하루 목표를 정하는 창.
const String dailyGoalDialogTitle = '오늘의 연습 목표';
const String dailyGoalDialogQuestion = '하루에 몇 번 따라 말할까요?';

/// 캘린더에서 날짜를 아직 안 눌렀을 때.
const String practiceCalendarHint = '날짜를 누르면 그날 연습한 횟수를 볼 수 있어요.';

/// 단어 복습이 세는 단위(사용자 요청). 따라 말하기의 '번'과 가른다.
const String wordReviewCountUnit = '개';

/// 학습 캘린더 머리 옆에 적는 그달 단어 복습 수. 0이면 적지 않는다.
String? wordReviewMonthLabel(int total) =>
    total <= 0 ? null : '단어 $total$wordReviewCountUnit';

/// 날짜를 눌렀을 때 그날 복습한 단어 수. 0이면 적지 않는다.
String? wordReviewDayLabel(int count) =>
    count <= 0 ? null : '단어 $count$wordReviewCountUnit';
