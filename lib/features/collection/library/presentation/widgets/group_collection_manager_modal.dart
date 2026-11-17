import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart';

/// 저장하지 못했을 때 시트 안에 적는 말.
const String groupCollectionSaveFailed = '저장하지 못했어요. 잠시 뒤 다시 해 주세요.';

class GroupCollectionManagerModal extends StatefulWidget {
  final int? initialGroupId;
  final int? initialCollectionId;

  const GroupCollectionManagerModal({
    super.key,
    this.initialGroupId,
    this.initialCollectionId,
  });

  @override
  State<GroupCollectionManagerModal> createState() =>
      _GroupCollectionManagerModalState();
}

class _GroupCollectionManagerModalState
    extends State<GroupCollectionManagerModal> {
  bool _isLoading = true;
  List<Group> _allGroups = [];
  List<Collection> _allCollections = [];

  // Tab A State (Group -> Collections)
  int? _selectedGroupIdForTabA;
  Set<int> _checkedCollectionIdsForTabA = {};

  // Tab B State (Collection -> Groups)
  int? _selectedCollectionIdForTabB;
  Set<int> _checkedGroupIdsForTabB = {};

  @override
  void initState() {
    super.initState();
    _selectedGroupIdForTabA = widget.initialGroupId;
    _selectedCollectionIdForTabB = widget.initialCollectionId;
    _loadData();
  }

  Future<void> _loadData() async {
    final clipProvider = context.read<ClipProvider>();
    _allGroups = clipProvider.groups;
    _allCollections = await clipProvider.fetchAllCollections();

    if (_allGroups.isNotEmpty && _selectedGroupIdForTabA == null) {
      _selectedGroupIdForTabA = _allGroups.first.id;
    }
    if (_allCollections.isNotEmpty && _selectedCollectionIdForTabB == null) {
      _selectedCollectionIdForTabB = _allCollections.first.id;
    }

    if (_selectedGroupIdForTabA != null) {
      await _loadTabASelections(_selectedGroupIdForTabA!);
    }
    if (_selectedCollectionIdForTabB != null) {
      await _loadTabBSelections(_selectedCollectionIdForTabB!);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTabASelections(int groupId) async {
    final clipProvider = context.read<ClipProvider>();
    final collectionIds = await clipProvider.getCollectionIdsForGroup(groupId);
    if (!mounted) return;
    setState(() {
      _checkedCollectionIdsForTabA = collectionIds.toSet();
    });
  }

  Future<void> _loadTabBSelections(int collectionId) async {
    final clipProvider = context.read<ClipProvider>();
    final groupIds = await clipProvider.getGroupIdsForCollection(collectionId);
    if (!mounted) return;
    setState(() {
      _checkedGroupIdsForTabB = groupIds.toSet();
    });
  }

  /// 저장하다 실패하면 시트 안에 적는다. 토스트는 시트 뒤에 깔려
  /// 보이지 않는다(5차 391).
  String? _error;

  Future<void> _saveTabA() async {
    if (_selectedGroupIdForTabA == null) return;
    final clipProvider = context.read<ClipProvider>();
    try {
      await clipProvider.updateCollectionsForGroup(
          _selectedGroupIdForTabA!, _checkedCollectionIdsForTabA.toList());
    } catch (e) {
      AppLogger.w('[GroupCollectionManager] 그룹 저장 실패: $e');
      if (mounted) setState(() => _error = groupCollectionSaveFailed);
      return;
    }
    if (mounted) {
      // 시트를 닫고 알리므로 토스트가 보인다
      showToast('그룹에 담을 폴더를 저장했어요.');
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveTabB() async {
    if (_selectedCollectionIdForTabB == null) return;
    final clipProvider = context.read<ClipProvider>();
    try {
      await clipProvider.updateGroupsForCollection(
          _selectedCollectionIdForTabB!, _checkedGroupIdsForTabB.toList());
    } catch (e) {
      AppLogger.w('[GroupCollectionManager] 폴더 저장 실패: $e');
      if (mounted) setState(() => _error = groupCollectionSaveFailed);
      return;
    }
    if (mounted) {
      // 저장하고 시트를 닫는다. 전에는 닫지 않아, 알리는 말이 시트 뒤에
      // 깔려 보이지 않았고 저장됐는지 알 수 없었다(5차 391).
      // 시트를 닫고 알리므로 토스트가 보인다
      showToast('이 폴더가 들어갈 그룹을 저장했어요.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: '그룹 기준'),
                  Tab(text: '폴더 기준'),
                ],
              ),
              if (_error case final message?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(
                    message,
                    key: const ValueKey('group-collection-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildTabA(),
                    _buildTabB(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabA() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<int>(
            decoration: const InputDecoration(
              labelText: '옮길 그룹 고르기',
              border: OutlineInputBorder(),
            ),
            initialValue: _selectedGroupIdForTabA,
            items: _allGroups
                .map((g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(g.name),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedGroupIdForTabA = val);
                _loadTabASelections(val);
              }
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _allCollections.length,
            itemBuilder: (context, index) {
              final col = _allCollections[index];
              final isChecked = _checkedCollectionIdsForTabA.contains(col.id);
              return CheckboxListTile(
                title: Text(col.name),
                value: isChecked,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _checkedCollectionIdsForTabA.add(col.id);
                    } else {
                      _checkedCollectionIdsForTabA.remove(col.id);
                    }
                  });
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveTabA,
              child: const Text('그룹에 저장'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabB() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<int>(
            decoration: const InputDecoration(
              labelText: '옮길 폴더 고르기',
              border: OutlineInputBorder(),
            ),
            initialValue: _selectedCollectionIdForTabB,
            items: _allCollections
                .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedCollectionIdForTabB = val);
                _loadTabBSelections(val);
              }
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _allGroups.length,
            itemBuilder: (context, index) {
              final grp = _allGroups[index];
              final isChecked = _checkedGroupIdsForTabB.contains(grp.id);
              return CheckboxListTile(
                title: Text(grp.name),
                value: isChecked,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _checkedGroupIdsForTabB.add(grp.id);
                    } else {
                      _checkedGroupIdsForTabB.remove(grp.id);
                    }
                  });
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveTabB,
              child: const Text('폴더에 저장'),
            ),
          ),
        ),
      ],
    );
  }
}
