// 글을 올린 사람의 작은 프로필 사진(5차 338, 사용자 요청).
//
// 사진이 없거나 아직 못 읽었으면 사람 아이콘을 그대로 보여 준다. 사진을
// 내려받다 실패해도 아이콘으로 돌아간다.

import 'package:flutter/material.dart';
import 'package:parrokit/core/content/author_profile.dart';

class AuthorAvatar extends StatefulWidget {
  const AuthorAvatar({
    super.key,
    required this.authorId,
    this.radius = 11,
    this.iconSize = 14,
  });

  /// 올린 사람의 uid. 비어 있으면 아이콘만 보여 준다.
  final String authorId;
  final double radius;
  final double iconSize;

  @override
  State<AuthorAvatar> createState() => _AuthorAvatarState();
}

class _AuthorAvatarState extends State<AuthorAvatar> {
  String? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _url = AuthorProfiles.cached(widget.authorId);
    // 프로필 사진이 바뀌면 다시 읽는다(5차 344, 사용자 신고).
    AuthorProfiles.revision.addListener(_onProfilesChanged);
    _load();
  }

  void _onProfilesChanged() {
    if (!mounted) return;
    final next = AuthorProfiles.cached(widget.authorId);
    setState(() {
      _failed = false;
      _url = next;
    });
    if (next == null) _load();
  }

  @override
  void dispose() {
    AuthorProfiles.revision.removeListener(_onProfilesChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AuthorAvatar old) {
    super.didUpdateWidget(old);
    if (old.authorId != widget.authorId) {
      _failed = false;
      _url = AuthorProfiles.cached(widget.authorId);
      _load();
    }
  }

  Future<void> _load() async {
    final requested = widget.authorId;
    final url = await AuthorProfiles.photoUrl(requested);
    if (!mounted || requested != widget.authorId || url == _url) return;
    setState(() => _url = url);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = _failed ? null : _url;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: colors.primary.withValues(alpha: 0.12),
      foregroundImage: url == null ? null : NetworkImage(url),
      onForegroundImageError:
          url == null ? null : (_, __) => setState(() => _failed = true),
      child: Icon(Icons.person_rounded,
          size: widget.iconSize, color: colors.primary),
    );
  }
}
