// ============================================================================
// lib/features/content-studio/captioning/presentation/screens/captioning_screen.dart
// ============================================================================
//
// [역할]
// 캡션링 화면. Provider에서 상태와 로직을 가져옴.
// 모든 섹션을 단일 스크롤 페이지에 표시.
//
// [레이어]
// Presentation Layer > Screen
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/local/app_database.dart' as db;

import '../providers/captioning_provider.dart';
import '../widgets/exit_confirm_sheet.dart';
import '../../../hub/presentation/content_studio_app_bar.dart';
import '../../../hub/presentation/studio_hub_provider.dart';
import '../sections/sections.dart';

/// 클립 에디터 화면.
class CaptioningScreen extends StatelessWidget {
  const CaptioningScreen({
    super.key,
    this.clipId,
    this.initialCollectionName,
    this.onClose,
    this.showAppBar = true,
  });

  final int? clipId;
  final String? initialCollectionName;
  final Future<void> Function(Object? result)? onClose;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CaptioningProvider(
        clipProvider: context.read<ClipProvider>(),
        userProvider: context.read<UserProvider>(),
        collectionsDao: context.read<db.AppDatabase>().collectionsDao,
        clipId: clipId,
        initialCollectionName: initialCollectionName,
      ),
      child: _CaptioningBody(
        onClose: onClose,
        showAppBar: showAppBar,
      ),
    );
  }
}

class _CaptioningBody extends StatefulWidget {
  const _CaptioningBody({
    required this.onClose,
    required this.showAppBar,
  });

  final Future<void> Function(Object? result)? onClose;
  final bool showAppBar;

  @override
  State<_CaptioningBody> createState() => _CaptioningBodyState();
}

class _CaptioningBodyState extends State<_CaptioningBody> {
  bool _hasHandledClose = false;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CaptioningProvider>();
    final userProvider = context.watch<UserProvider>();
    final showAppBar = widget.showAppBar;

    final hubProvider = context.watch<StudioHubProvider?>();

    // 저장 후 닫기 - 한 번만 처리
    if (vm.shouldClose && !_hasHandledClose) {
      _hasHandledClose = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _close(context, vm.closeResult);
        }
      });
    }

    if (hubProvider?.pendingCaptionFilePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && hubProvider != null) {
          hubProvider.consumePendingCaptionFile((path) {
            vm.setExistingFile(path);
          });
        }
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _showExitConfirmation(context, vm);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: showAppBar
            ? ContentStudioAppBar(
                title: '편집',
                coins: userProvider.coins,
                onBack: () => _showExitConfirmation(context, vm),
                backgroundColor: Theme.of(context).colorScheme.surface,
              )
            : null,
        body: SafeArea(
          top: !showAppBar,
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  FileSection(vm: vm),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: MetadataInputsSection(vm: vm),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (vm.isSaving || vm.isSttProcessing)
                            ? null
                            : vm.save,
                        child: vm.isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('저장'),
                      ),
                    ),
                  ),
                ],
              ),
              if (vm.isSaving)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              if (vm.isLoadingForEdit)
                Positioned.fill(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            '클립 정보를 불러오고 있어요',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExitConfirmation(
      BuildContext context, CaptioningProvider vm) async {
    if (vm.isSttProcessing) return;
    final result = await showExitConfirmSheet(context);
    if (result == true && context.mounted) {
      await _close(context, null);
    }
  }

  Future<void> _close(BuildContext context, Object? result) async {
    final onClose = widget.onClose;
    if (onClose != null) {
      await onClose(result);
      return;
    }

    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    }
  }
}
