import 'package:flutter/material.dart';
import '../models/subcontractor_issue.dart';
import '../models/checklist_models.dart';
import '../services/storage_service.dart';
import '../services/subcontractor_issue_service.dart';
import '../services/property_filter.dart';
import '../widgets/issue_card.dart';
import '../widgets/issues_building_card.dart';
import '../utils/tower_utils.dart';
import 'issue_detail_screen.dart';
import 'template_selection_screen.dart';
import 'checklist_screen.dart';

class AllIssuesGroupedScreen extends StatefulWidget {
  const AllIssuesGroupedScreen({super.key});

  @override
  State<AllIssuesGroupedScreen> createState() => _AllIssuesGroupedScreenState();
}

class _AllIssuesGroupedScreenState extends State<AllIssuesGroupedScreen> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  Map<String, List<SubcontractorIssue>> _issuesByBuilding = {};
  Map<String, QCTemplate> _templates = {};
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  Map<String, bool> _collapsedResolvedSections = {}; // Track which buildings have collapsed resolved sections

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllIssues();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAllIssues();
    }
  }

  Future<void> _refreshData() async {
    await _loadAllIssues();
  }

  Future<void> _loadAllIssues() async {
    setState(() => _isLoading = true);
    
    _templates = await StorageService.loadTemplates();
    final allChecklists = await StorageService.getSavedChecklists();
    
    // Filter checklists by selected property
    final filteredChecklists = allChecklists.where((checklist) {
      return PropertyFilter.matchesFilter(checklist.property);
    }).toList();
    
    // Extract all issues from filtered checklists
    final allIssues = <SubcontractorIssue>[];
    
    for (final checklist in filteredChecklists) {
      for (final item in checklist.items) {
        if (item.hasIssue) {
          final issue = SubcontractorIssue(
            itemText: item.text,
            buildingNumber: checklist.buildingNumber,
            unitNumber: checklist.unitNumber,
            issueDescription: item.issueDescription,
            templateId: checklist.templateId,
            isResolved: item.isChecked,
            originalItem: item,
            parentChecklist: checklist,
          );
          allIssues.add(issue);
        }
      }
    }
    
    // Group issues by building number
    final groupedIssues = <String, List<SubcontractorIssue>>{};
    
    for (final issue in allIssues) {
      final buildingKey = issue.buildingNumber;
      if (!groupedIssues.containsKey(buildingKey)) {
        groupedIssues[buildingKey] = [];
      }
      groupedIssues[buildingKey]!.add(issue);
    }
    
    // Sort each building's issues by tower then unit
    for (final buildingNumber in groupedIssues.keys) {
      groupedIssues[buildingNumber]!.sort((a, b) {
        // First sort by tower number
        final aTower = int.parse(TowerUtils.getTowerNumber(a.unitNumber));
        final bTower = int.parse(TowerUtils.getTowerNumber(b.unitNumber));
        final towerComparison = aTower.compareTo(bTower);
        
        if (towerComparison != 0) return towerComparison;
        
        // Then sort by unit number
        final aUnit = int.parse(a.unitNumber);
        final bUnit = int.parse(b.unitNumber);
        return aUnit.compareTo(bUnit);
      });
    }
    
    setState(() {
      _issuesByBuilding = groupedIssues;
      _isLoading = false;
    });
  }

  String _getTemplateName(String templateId) {
    return _templates[templateId]?.name ?? 'Unknown Template';
  }

  void _toggleResolvedSection(String buildingNumber) {
    setState(() {
      // Initialize the state if it doesn't exist, then toggle it
      if (_collapsedResolvedSections.containsKey(buildingNumber)) {
        _collapsedResolvedSections[buildingNumber] = !_collapsedResolvedSections[buildingNumber]!;
      } else {
        _collapsedResolvedSections[buildingNumber] = false; // First click expands
      }
    });
  }

  void _navigateToIssueDetail(SubcontractorIssue issue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IssueDetailScreen(
          issue: issue,
          getTemplateName: _getTemplateName,
        ),
      ),
    ).then((_) {
      // Only do a full refresh when returning from issue detail
      // since the user might have made changes in the detail screen
      _loadAllIssues();
    });
  }

  Future<void> _toggleIssueResolution(SubcontractorIssue issue) async {
    // Update the underlying data - the IssueCard will handle its own visual state
    await SubcontractorIssueService.toggleIssueChecked(issue);
    
    // Show toast about what happens when returning
    if (mounted) {
      final isNowChecked = issue.originalItem.isChecked;
      final message = isNowChecked 
        ? 'Issue marked complete. Will move to resolved section when you return.'
        : 'Issue marked incomplete. Will move to unresolved section when you return.';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          backgroundColor: isNowChecked ? Colors.purple.shade300 : Colors.red.shade300,
        ),
      );
    }
  }

  Future<void> _navigateToCreateTemplate() async {
    // Load templates for selection
    final allTemplates = await StorageService.loadTemplates();
    final templateNames = allTemplates.values.map((t) => t.name).toList();
    
    // Navigate to template selection
    final selectionData = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateSelectionScreen(
          templateNames: templateNames,
          onTemplateSelected: (data) {
            Navigator.pop(context, data);
          },
        ),
      ),
    );
    
    if (selectionData != null) {
      // Handle template selection and navigation to checklist
      await _handleTemplateSelection(selectionData, allTemplates);
      // Refresh data after handling template selection
      await _loadAllIssues();
    }
  }

  Future<void> _handleTemplateSelection(Map<String, dynamic> selectionData, Map<String, QCTemplate> allTemplates) async {
    final selectedTemplateName = selectionData['templateName'] as String;
    final selectedBuilding = selectionData['building'] as String;
    final selectedUnit = selectionData['unit'] as String;
    
    // Find the template by name
    final templateEntry = allTemplates.entries.firstWhere(
      (entry) => entry.value.name == selectedTemplateName,
      orElse: () => throw Exception('Template not found'),
    );
    
    final templateId = templateEntry.key;
    final template = templateEntry.value;
    
    // Check if checklist already exists
    final existingChecklists = await StorageService.getSavedChecklists();
    final existingChecklist = existingChecklists.where((checklist) =>
      checklist.buildingNumber == selectedBuilding &&
      checklist.unitNumber == selectedUnit &&
      checklist.templateId == templateId
    ).firstOrNull;
    
    if (existingChecklist != null && mounted) {
      // Navigate to existing checklist
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChecklistScreen(checklistData: existingChecklist),
        ),
      ).then((_) {
        // Refresh data when returning from checklist
        _loadAllIssues();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigated to existing checklist for Building $selectedBuilding, Unit $selectedUnit'),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // Create new checklist
      final checklistData = ChecklistData(
        templateId: templateId,
        buildingNumber: selectedBuilding,
        unitNumber: selectedUnit,
        items: template.items.map((item) => ChecklistItem(text: item)).toList(),
      );
      
      // Navigate to checklist screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChecklistScreen(checklistData: checklistData),
          ),
        ).then((_) {
          // Refresh data when returning from checklist
          _loadAllIssues();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('All Subs'),
          backgroundColor: Colors.green.shade300,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_issuesByBuilding.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('All Subs'),
          backgroundColor: Colors.green.shade300,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'No issues found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToCreateTemplate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Issue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Sort building numbers numerically
    final sortedBuildingNumbers = _issuesByBuilding.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Subs'),
        backgroundColor: Colors.blue.shade300,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property display
            if (PropertyFilter.selectedProperty != null && PropertyFilter.selectedProperty != 'HIDE_ALL')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Text(
                  PropertyFilter.selectedProperty!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    fontSize: 16,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Issues by Unit',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _navigateToCreateTemplate,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Issue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade300,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: sortedBuildingNumbers.length,
                  itemBuilder: (context, buildingIndex) {
                    final buildingNumber = sortedBuildingNumbers[buildingIndex];
                    final buildingIssues = _issuesByBuilding[buildingNumber]!;
                    
                    // Separate unresolved and resolved issues
                    final unresolvedIssues = buildingIssues.where((issue) => !issue.isResolved).toList();
                    final resolvedIssues = buildingIssues.where((issue) => issue.isResolved).toList();
                    
                    return IssuesBuildingCard(
                      buildingNumber: buildingNumber,
                      unresolvedIssues: unresolvedIssues,
                      resolvedIssues: resolvedIssues,
                      onToggleUnresolved: _toggleIssueResolution,
                      onToggleResolved: _toggleIssueResolution,
                      getTemplateName: _getTemplateName,
                      onCopyComplete: () => setState(() {}),
                      onToggleResolvedSection: () => _toggleResolvedSection(buildingNumber),
                      isResolvedSectionCollapsed: _collapsedResolvedSections[buildingNumber] ?? true,
                      onIssueTap: _navigateToIssueDetail,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}