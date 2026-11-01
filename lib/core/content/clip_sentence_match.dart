import 'package:parrokit/core/speech/speech_match.dart';

/// 클립에 담긴 자막 한 줄. 클립 DB의 `Segments` 한 행에 해당한다.
class ClipSegmentRef {
  const ClipSegmentRef({
    required this.clipId,
    required this.clipTitle,
    required this.segmentId,
    required this.startMs,
    required this.endMs,
    required this.original,
    this.translation = '',
  });

  final int clipId;
  final String clipTitle;
  final int segmentId;
  final int startMs;
  final int endMs;

  /// 자막 원문. 내 문장 원문과 비교한다.
  final String original;
  final String translation;
}

enum ClipMatchKind {
  /// 공백·문장부호·대소문자만 빼면 같은 문장.
  exact('같은 문장'),

  /// 자막이 더 길고, 그 안에 내 문장이 통째로 들어 있다.
  contains('문장 포함'),

  /// 몇 글자만 다른 비슷한 문장.
  similar('비슷한 문장');

  const ClipMatchKind(this.label);
  final String label;
}

class ClipSentenceMatch {
  const ClipSentenceMatch({
    required this.segment,
    required this.kind,
    required this.score,
  });

  final ClipSegmentRef segment;
  final ClipMatchKind kind;

  /// 0~1. 정렬에만 쓰고 화면에는 종류만 보여준다.
  final double score;
}

/// 자막 목록을 가져오는 쪽. 실제로 클립 DB에서 어떻게 읽을지는 아직 정하지 않았다.
abstract class ClipSegmentSource {
  Future<List<ClipSegmentRef>> loadSegments();
}

/// 클립 검색이 아직 연결되지 않았을 때 던진다. 화면은 "준비 중" 안내를 보여준다.
class ClipSearchUnavailable implements Exception {
  const ClipSearchUnavailable([this.reason = '아직 준비 중이에요']);
  final String reason;

  @override
  String toString() => 'ClipSearchUnavailable: $reason';
}

/// 아직 구현이 없는 기본 자막 소스.
class UnavailableClipSegmentSource implements ClipSegmentSource {
  const UnavailableClipSegmentSource();

  @override
  Future<List<ClipSegmentRef>> loadSegments() =>
      Future.error(const ClipSearchUnavailable());
}

/// 이 정도 길이 미만인 문장은 "포함" 판정에서 뺀다. 짧은 단어가 아무 자막에나 들어가기 때문이다.
const clipContainsMinLength = 4;

/// 이 값 이상이면 비슷한 문장으로 본다.
const clipSimilarMinScore = 0.8;

/// [sentence]와 맞는 자막을 골라 가까운 순으로 돌려준다.
///
/// 1. 같은 문장(exact) → 2. 자막 안에 포함(contains) → 3. 비슷한 문장(similar) 순서다.
/// 종류가 같으면 점수가 높은 것, 그다음은 짧은 자막이 먼저다.
List<ClipSentenceMatch> matchClipSegments(
  String sentence,
  List<ClipSegmentRef> segments, {
  int limit = 10,
}) {
  final target = normalizeForMatch(sentence);
  if (target.isEmpty) return const [];
  final matches = <ClipSentenceMatch>[];
  final seen = <String>{};
  for (final segment in segments) {
    final text = normalizeForMatch(segment.original);
    if (text.isEmpty) continue;
    // 같은 클립의 같은 구간이 중복으로 들어와도 한 번만 센다.
    if (!seen.add('${segment.clipId}:${segment.startMs}')) continue;
    final match = _classify(target, text, segment);
    if (match != null) matches.add(match);
  }
  matches.sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.segment.original.length.compareTo(b.segment.original.length);
  });
  return matches.take(limit).toList(growable: false);
}

ClipSentenceMatch? _classify(
  String target,
  String text,
  ClipSegmentRef segment,
) {
  if (target == text) {
    return ClipSentenceMatch(
        segment: segment, kind: ClipMatchKind.exact, score: 1);
  }
  if (target.runes.length >= clipContainsMinLength && text.contains(target)) {
    return ClipSentenceMatch(
      segment: segment,
      kind: ClipMatchKind.contains,
      score: target.runes.length / text.runes.length,
    );
  }
  final score = sentenceSimilarity(target, text);
  if (score >= clipSimilarMinScore) {
    return ClipSentenceMatch(
        segment: segment, kind: ClipMatchKind.similar, score: score);
  }
  return null;
}

/// 내 문장으로 클립 자막을 찾는다. 자막은 [source]에서 가져온다.
class ClipSentenceFinder {
  const ClipSentenceFinder(this.source);

  final ClipSegmentSource source;

  Future<List<ClipSentenceMatch>> find(String sentence,
      {int limit = 10}) async {
    final segments = await source.loadSegments();
    return matchClipSegments(sentence, segments, limit: limit);
  }
}
