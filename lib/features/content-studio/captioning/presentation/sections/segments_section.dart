import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:video_player/video_player.dart';

import '../widgets/segment_card.dart';

import '../providers/captioning_provider.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 자막 세그먼트 섹션.
class SegmentsSection extends StatefulWidget {
  const SegmentsSection({super.key, required this.vm, this.playerController});

  final CaptioningProvider vm;
  final VideoPlayerController? playerController;

  @override
  State<SegmentsSection> createState() => _SegmentsSectionState();
}

class _SegmentsSectionState extends State<SegmentsSection> {
  final ScrollController _scrollCtrl = ScrollController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addAndJump() {
    final newIndex = widget.vm.segmentForms.length;
    widget.vm.addSegment();

    // 페이지 번호를 즉시 업데이트하여 UI 반응성 개선
    setState(() => _currentPage = newIndex);
    _scrollToEnd();
  }

  void _deleteCurrentAndAdjust() {
    final total = widget.vm.segmentForms.length;
    if (total <= 1) {
      showToast('마지막 구간은 삭제할 수 없습니다.');
      return;
    }

    final deletedIndex = _currentPage;
    // 삭제된 인덱스의 이전(max 0)으로 타겟 설정
    final targetPage = (deletedIndex - 1).clamp(0, total - 2);

    widget.vm.removeSegment(deletedIndex);

    // 즉시 업데이트하여 "구간 X / Y" 텍스트 동기화
    setState(() => _currentPage = targetPage);
  }

  void _handleSelectSegment(int index) {
    setState(() => _currentPage = index);
    _scrollToSelectedSegment(index);
  }

  void _scrollToSelectedSegment(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;

      final position = _scrollCtrl.position;
      final target = ((index * _SegmentSwitchBarLayout.segmentWidth) +
              (_SegmentSwitchBarLayout.segmentWidth / 2) -
              (position.viewportDimension / 2))
          .clamp(0.0, position.maxScrollExtent);

      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;

      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final total = vm.segmentForms.length;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 0) ...[
          _SegmentSwitchBar(
            total: total,
            currentPage: _currentPage,
            isProcessing: vm.isSttProcessing,
            onSelect: _handleSelectSegment,
            onAdd: vm.isSttProcessing ? null : _addAndJump,
            colorScheme: cs,
            scrollController: _scrollCtrl,
          ),
          if (_currentPage < total)
            SegmentCard(
              playerController: widget.playerController,
              startCtl: vm.segmentForms[_currentPage].startCtl,
              endCtl: vm.segmentForms[_currentPage].endCtl,
              originalCtl: vm.segmentForms[_currentPage].originalCtl,
              pronCtl: vm.segmentForms[_currentPage].pronCtl,
              koCtl: vm.segmentForms[_currentPage].koCtl,
              onStartCommitted: () => vm.validateSegmentAt(_currentPage),
              onEndCommitted: () => vm.validateSegmentAt(_currentPage),
              onRangeUpdated: () => vm.validateSegmentAt(_currentPage),
              enabled: !vm.isSttProcessing,
              onDelete: vm.isSttProcessing ? null : _deleteCurrentAndAdjust,
            ),
        ],
      ],
    );
  }
}

class _SegmentSwitchBar extends StatelessWidget {
  const _SegmentSwitchBar({
    required this.total,
    required this.currentPage,
    required this.isProcessing,
    required this.onSelect,
    required this.onAdd,
    required this.colorScheme,
    required this.scrollController,
  });

  final int total;
  final int currentPage;
  final bool isProcessing;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAdd;
  final ColorScheme colorScheme;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = currentPage.clamp(0, total - 1).toInt();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segmentBg = context.tokens.surfaceContainer;
    final addBg = context.tokens.surfaceContainerHigh;
    final baseBg =
        isDark ? context.tokens.surfaceContainerHigh : context.tokens.surface;
    final contentWidth = (total * _SegmentSwitchBarLayout.segmentWidth) +
        _SegmentSwitchBarLayout.addWidth;

    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        height: 34,
        width: contentWidth,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: baseBg,
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              left: selectedIndex * _SegmentSwitchBarLayout.segmentWidth,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: _SegmentSwitchBarLayout.segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: colorScheme.primary),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < total; i++)
                  SizedBox(
                    width: _SegmentSwitchBarLayout.segmentWidth,
                    child: _SegmentSquareButton(
                      label: '구간 #${i + 1}',
                      isSelected: currentPage == i,
                      onTap: () => onSelect(i),
                      textColor: currentPage == i
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      backgroundColor:
                          currentPage == i ? Colors.transparent : segmentBg,
                    ),
                  ),
                SizedBox(
                  width: _SegmentSwitchBarLayout.addWidth,
                  child: _AddSegmentButton(
                    label: '+ 추가',
                    onTap: onAdd,
                    isEnabled: !isProcessing,
                    textColor: colorScheme.primary,
                    backgroundColor: addBg,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentSquareButton extends StatelessWidget {
  const _SegmentSquareButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.textColor,
    required this.backgroundColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: context.texts.bodySmall.copyWith(color: textColor),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSegmentButton extends StatelessWidget {
  const _AddSegmentButton({
    required this.label,
    required this.onTap,
    required this.isEnabled,
    required this.textColor,
    required this.backgroundColor,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isEnabled;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = isEnabled
        ? textColor
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style:
                  context.texts.bodySmall.copyWith(color: effectiveTextColor),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _SegmentSwitchBarLayout {
  static const double segmentWidth = 90.0;
  static const double addWidth = 78.0;
}
