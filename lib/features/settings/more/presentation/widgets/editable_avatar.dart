// ============================================================================
// lib/features/_entry/auth/presentation/widgets/editable_avatar.dart
// ============================================================================
//
// [역할]
// 편집 가능한 사용자 아바타 위젯.
// 프로필 이미지 표시 및 편집 버튼 제공.
//
// [레이어]
// Presentation Layer > Widgets
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 편집 가능한 사용자 아바타.
class EditableAvatar extends StatelessWidget {
  /// 사용자 프로필 이미지 URL
  final String? photoUrl;

  /// 아바타 크기
  final double size;

  /// 편집 후 선택된 URL을 돌려주는 콜백 (빈 문자열 ''은 제거를 의미)
  final Function(String)? onSelected;

  const EditableAvatar({
    super.key,
    required this.photoUrl,
    this.size = 72,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () async {
        if (onSelected == null) return;

        final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

        final choice = await showAppSheet<int>(
          context: context,
          builder: (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('사진에서 선택'),
                  onTap: () => Navigator.pop(context, 1),
                ),
                if (hasPhoto)
                  ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: context.tokens.danger),
                    title: Text('현재 사진 삭제',
                        style: TextStyle(color: context.tokens.danger)),
                    onTap: () => Navigator.pop(context, 2),
                  ),
              ],
            ),
          ),
        );

        if (choice == 1) {
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(
              source: ImageSource.gallery, imageQuality: 80);
          if (pickedFile != null) {
            onSelected!(pickedFile.path); // 로컬 파일 경로 리턴
          }
        } else if (choice == 2) {
          onSelected!(''); // 삭제(초기화)를 의미하는 빈 문자열 리턴
        }
      },
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHighest,
              border: Border.all(
                color: cs.outlineVariant,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: _buildAvatar(photoUrl, cs),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 2),
              ),
              child: Icon(
                Icons.edit_rounded,
                size: 12,
                color: cs.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, ColorScheme cs) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.person_outline,
          size: size * 0.55, // 크기에 비례하여 아이콘 크기 조정
          color: cs.onSurfaceVariant,
        ),
      );
    }
    if (photoUrl.startsWith('assets/avatars/')) {
      return SvgPicture.asset(
        photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }
    if (photoUrl.startsWith('/') || photoUrl.startsWith('file://')) {
      return Image.file(
        File(photoUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    // 그 외 일반 이미지 (Firebase Storage에서 가져온 JPG/PNG 등)
    // 과거에 저장된 SVG(Dicebear) URL일 경우 에러가 나면서 자동으로 errorBuilder가 실행되어 기본 아이콘을 보여줌
    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      width: size,
      height: size,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: context.tokens.skeleton,
        highlightColor: context.tokens.skeletonHighlight,
        child: Container(color: Colors.white),
      ),
      errorWidget: (context, url, error) => Center(
        child: Icon(
          Icons.person_outline,
          size: size * 0.55,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
