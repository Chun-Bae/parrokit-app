import '../local/app_database.dart';

class ClipView {
  final Clip clip;
  final List<Segment> segments;
  ClipView({
    required this.clip,
    required this.segments,
  });
}
