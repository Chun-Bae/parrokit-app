import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart';

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
    setState(() {
      _checkedCollectionIdsForTabA = collectionIds.toSet();
    });
  }

  Future<void> _loadTabBSelections(int collectionId) async {
    final clipProvider = context.read<ClipProvider>();
    final groupIds = await clipProvider.getGroupIdsForCollection(collectionId);
    setState(() {
      _checkedGroupIdsForTabB = groupIds.toSet();
    });
  }

  Future<void> _saveTabA() async {
    if (_selectedGroupIdForTabA == null) return;
    final clipProvider = context.read<ClipProvider>();
    await clipProvider.updateCollectionsForGroup(
        _selectedGroupIdForTabA!, _checkedCollectionIdsForTabA.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('그룹 매핑이 저장되었습니다.')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveTabB() async {
    if (_selectedCollectionIdForTabB == null) return;
    final clipProvider = context.read<ClipProvider>();
    await clipProvider.updateGroupsForCollection(
        _selectedCollectionIdForTabB!, _checkedGroupIdsForTabB.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('콜렉션 매핑이 저장되었습니다.')),
      );
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
                  Tab(text: '콜렉션 기준'),
                ],
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
              labelText: '대상 그룹 선택',
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
              labelText: '대상 콜렉션 선택',
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
              child: const Text('콜렉션에 저장'),
            ),
          ),
        ),
      ],
    );
  }
}
