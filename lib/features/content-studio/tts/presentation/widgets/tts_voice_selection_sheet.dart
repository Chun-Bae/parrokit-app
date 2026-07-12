import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_google_models.dart';
import 'package:parrokit/features/content-studio/tts/presentation/providers/tts_provider.dart';

/// 커스텀 큐레이션 대상 등급(Standard/WaveNet)에 속하는 구글 보이스 1개.
class _GoogleVoiceEntry {
  const _GoogleVoiceEntry({
    required this.voiceId,
    required this.tier,
    required this.gender,
  });

  final String voiceId;
  final String tier;
  final String gender;
}

class TtsVoiceSelectionSheet extends StatefulWidget {
  const TtsVoiceSelectionSheet({super.key, required this.provider});

  final TtsProvider provider;

  @override
  State<TtsVoiceSelectionSheet> createState() => _TtsVoiceSelectionSheetState();
}

class _TtsVoiceSelectionSheetState extends State<TtsVoiceSelectionSheet> {
  List<_GoogleVoiceEntry> _entries = [];
  String? _selectedTier;
  String? _selectedGender;

  late final AudioPlayer _previewPlayer;
  String? _previewLoadingVoiceId;
  String? _previewPlayingVoiceId;

  @override
  void initState() {
    super.initState();
    _previewPlayer = AudioPlayer();
    _previewPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() => _previewPlayingVoiceId = null);
      }
    });
    _parseVoices();
    _initSelection();
  }

  @override
  void didUpdateWidget(covariant TtsVoiceSelectionSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.provider.availableVoices != oldWidget.provider.availableVoices) {
      _parseVoices();
      _initSelection();
    }
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  void _parseVoices() {
    final curatedTierIds = googleModels.map((m) => m.id).toSet();
    _entries = widget.provider.availableVoices
        .map((v) {
          final name = (v['name'] ?? '').toString();
          final parts = name.split('-');
          if (parts.length < 2) return null;
          final tier = parts[parts.length - 2];
          if (!curatedTierIds.contains(tier)) return null;
          return _GoogleVoiceEntry(
            voiceId: name,
            tier: tier,
            gender: (v['ssmlGender'] ?? '').toString(),
          );
        })
        .whereType<_GoogleVoiceEntry>()
        .toList()
      ..sort((a, b) => a.voiceId.compareTo(b.voiceId));
  }

  List<String> _tiersInOrder() {
    final available = _entries.map((e) => e.tier).toSet();
    return googleModels.map((m) => m.id).where(available.contains).toList();
  }

  List<String> _gendersFor(String tier) {
    final genders = _entries
        .where((e) => e.tier == tier)
        .map((e) => e.gender)
        .toSet()
        .toList();
    genders.sort();
    return genders;
  }

  List<_GoogleVoiceEntry> _candidatesFor(String tier, String gender) {
    return _entries.where((e) => e.tier == tier && e.gender == gender).toList();
  }

  void _initSelection() {
    final tiers = _tiersInOrder();
    if (tiers.isEmpty) {
      _selectedTier = null;
      _selectedGender = null;
      return;
    }

    final currentVoice = widget.provider.voiceId;
    final currentEntry = _entries.where((e) => e.voiceId == currentVoice).firstOrNull;

    _selectedTier = currentEntry?.tier ?? tiers.first;
    final genders = _gendersFor(_selectedTier!);
    _selectedGender = currentEntry?.gender ?? (genders.isNotEmpty ? genders.first : null);
  }

  void _selectTier(String tier) {
    setState(() {
      _selectedTier = tier;
      final genders = _gendersFor(tier);
      _selectedGender = genders.isNotEmpty ? genders.first : null;
    });
  }

  void _selectGender(String gender) {
    setState(() => _selectedGender = gender);
  }

  Future<void> _onPreviewTap(String voiceId) async {
    if (_previewPlayingVoiceId == voiceId) {
      await _previewPlayer.pause();
      if (mounted) setState(() => _previewPlayingVoiceId = null);
      return;
    }

    setState(() => _previewLoadingVoiceId = voiceId);
    final path = await widget.provider.previewGoogleVoice(voiceId);
    if (!mounted) return;
    setState(() => _previewLoadingVoiceId = null);

    if (path == null) {
      showToast('미리듣기를 재생할 수 없습니다.');
      return;
    }

    await _previewPlayer.setFilePath(path);
    await _previewPlayer.play();
    if (mounted) setState(() => _previewPlayingVoiceId = voiceId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    final tiers = _tiersInOrder();
    final genders = _selectedTier == null ? <String>[] : _gendersFor(_selectedTier!);
    final candidates = (_selectedTier == null || _selectedGender == null)
        ? <_GoogleVoiceEntry>[]
        : _candidatesFor(_selectedTier!, _selectedGender!);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              '보이스 선택',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.provider.isLoadingVoices)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (tiers.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  '선택할 수 있는 보이스가 없습니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: mutedText),
                ),
              ),
            )
          else ...[
            _SectionLabel(text: '모델 (Model)', mutedColor: mutedText),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: tiers.map((tier) {
                  final model = googleModels.firstWhere((m) => m.id == tier);
                  final isSelected = _selectedTier == tier;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ModelChoiceTile(
                      name: model.name,
                      description: model.description,
                      isSelected: isSelected,
                      onTap: () => _selectTier(tier),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(text: '성별 (Gender)', mutedColor: mutedText),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Wrap(
                spacing: AppSpacing.sm,
                children: genders.map((gender) {
                  final isSelected = _selectedGender == gender;
                  return ChoiceChip(
                    label: Text(googleGenderLabel(gender)),
                    selected: isSelected,
                    onSelected: (_) => _selectGender(gender),
                    selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    labelStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white : Colors.black),
                    ),
                    side: isSelected ? BorderSide(color: theme.colorScheme.primary) : null,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(text: '보이스', mutedColor: mutedText),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: candidates.isEmpty
                  ? Center(
                      child: Text(
                        '해당 조합의 보이스가 없습니다.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: mutedText),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final entry = candidates[index];
                        final isSelected = widget.provider.voiceId == entry.voiceId;
                        final isLoading = _previewLoadingVoiceId == entry.voiceId;
                        final isPlaying = _previewPlayingVoiceId == entry.voiceId;

                        return ListTile(
                          title: Text(
                            '보이스 ${index + 1}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                          leading: IconButton(
                            onPressed: isLoading ? null : () => _onPreviewTap(entry.voiceId),
                            icon: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(
                                    isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                  ),
                            color: theme.colorScheme.primary,
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          onTap: () {
                            widget.provider.updateVoiceId(entry.voiceId);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.mutedColor});

  final String text;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: mutedColor,
            ),
      ),
    );
  }
}

class _ModelChoiceTile extends StatelessWidget {
  const _ModelChoiceTile({
    required this.name,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : (isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainer),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
