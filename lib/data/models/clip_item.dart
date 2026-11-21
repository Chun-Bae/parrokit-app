import 'dart:typed_data';
import '../local/app_database.dart';

class ClipItem {
  final Clip clip;
  final List<Tag> tags;
  final List<Segment> segments;
  final Uint8List? thumbnail;

  const ClipItem({
    required this.clip,
    required this.tags,
    required this.segments,
    this.thumbnail,
  });

  ClipItem copyWith({
    Clip? clip,
    List<Tag>? tags,
    List<Segment>? segments,
    Uint8List? thumbnail,
    String? thumbPath,
  }) {
    return ClipItem(
      clip: clip ?? this.clip,
      tags: tags ?? this.tags,
      segments: segments ?? this.segments,
      thumbnail: thumbnail ?? this.thumbnail,
    );
  }
}
