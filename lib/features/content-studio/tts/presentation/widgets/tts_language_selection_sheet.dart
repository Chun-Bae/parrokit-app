import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_language.dart';
import 'package:parrokit/features/content-studio/tts/presentation/providers/tts_provider.dart';

class TtsLanguageSelectionSheet extends StatefulWidget {
  const TtsLanguageSelectionSheet({super.key, required this.provider});

  final TtsProvider provider;

  @override
  State<TtsLanguageSelectionSheet> createState() =>
      _TtsLanguageSelectionSheetState();
}

class _TtsLanguageSelectionSheetState extends State<TtsLanguageSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<TtsLanguage> _filteredLanguages = supportedTtsLanguages;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterLanguages(String query) {
    if (query.isEmpty) {
      setState(() => _filteredLanguages = supportedTtsLanguages);
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredLanguages = supportedTtsLanguages.where((lang) {
        return lang.displayName.toLowerCase().contains(lowerQuery) ||
            lang.ttsCode.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: context.tokens.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.tokens.disabled,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '언어 선택',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _searchController,
              onChanged: _filterLanguages,
              decoration: InputDecoration(
                hintText: '언어 검색...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: context.tokens.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 0, horizontal: AppSpacing.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: _filteredLanguages.length,
              itemBuilder: (context, index) {
                final lang = _filteredLanguages[index];
                final isSelected = widget.provider.language == lang.ttsCode;

                return ListTile(
                  title: Text(
                    lang.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded,
                          color: theme.colorScheme.primary)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  onTap: () {
                    if (widget.provider.language != lang.ttsCode) {
                      widget.provider.updateLanguage(lang.ttsCode);
                      widget.provider.fetchAvailableVoices();
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
