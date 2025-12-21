import 'package:flutter/material.dart';
import '../models/subcontractor_issue.dart';
import '../models/checklist_models.dart';
import '../services/subcontractor_issue_service.dart';

import '../widgets/building_card.dart';
import '../screens/issue_detail_screen.dart';
import '../screens/template_selection_screen.dart';
import '../screens/checklist_screen.dart';
import '../services/storage_service.dart';

class SubcontractorDetailScreen extends StatefulWidget {
  final String subcontractorName;

  const SubcontractorDetailScreen({
    super.key,
    required this.subcontractorName,
  });

  @override
  State<SubcontractorDetailScreen> createState() => _SubcontractorDetailScreenState();
}

class _SubcontractorDetailScreenState extends State<SubcontractorDetailScreen> {
  Map<String, List<SubcontractorIssue>> unresolvedIssuesByBuilding = {};
  Map<String, List<SubcontractorIssue>> resolvedIssuesByBuilding = {};
  bool isLoading = true;
  Map<String, QCTemplate> templates = {};
  Map<String, bool> collapsedResolvedSections = {}; // Track which buildings have collapsed resolved sections
  final ScrollController _scrollController = ScrollController();
  double _savedScrollPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadIssues() async {
    final data = await SubcontractorIssueService.loadIssuesForSubcontractor(widget.subcontractorName);
    
    setState(() {
      unresolvedIssuesByBuilding = data['unresolvedIssuesByBuilding'];
      resolvedIssuesByBuilding = data['resolvedIssuesByBuilding'];
      templates = data['templates'];
      isLoading = false;
    });
  }

  String _getTemplateName(String templateId) {
    return templates[templateId]?.name ?? 'Unknown Template';
  }

  Future<void> _navigateToCreateTemplate() async {
    // Add current subcontractor to recent list
    await StorageService.addRecentSubcontractor(widget.subcontractorName);
    
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
      await _loadIssues();
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
        _loadIssues();
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
          _loadIssues();
        });
      }
    }
  }

  void _toggleResolvedSection(String buildingName) {
    setState(() {
      // Initialize the state if it doesn't exist, then toggle it
      if (collapsedResolvedSections.containsKey(buildingName)) {
        collapsedResolvedSections[buildingName] = !collapsedResolvedSections[buildingName]!;
      } else {
        collapsedResolvedSections[buildingName] = false; // First click expands
      }
    });
  }

  Future<void> _navigateToZoomMode(SubcontractorIssue issue) async {
    // Save current scroll position
    _savedScrollPosition = _scrollController.offset;
    
    // Navigate to issue detail screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IssueDetailScreen(
          issue: issue,
          getTemplateName: _getTemplateName,
        ),
      ),
    );
    
    // Refresh data when returning
    await _loadIssues();
    
    // Restore scroll position
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _savedScrollPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleToggleUnresolved(SubcontractorIssue issue) async {
    await SubcontractorIssueService.toggleIssueChecked(issue);
    // Let IssueCard handle its own visual state - no need to refresh whole screen
    
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

  Future<void> _handleToggleResolved(SubcontractorIssue issue) async {
    await SubcontractorIssueService.toggleIssueChecked(issue);
    // Let IssueCard handle its own visual state - no need to refresh whole screen
    
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subcontractorName),
        backgroundColor: Colors.orange.shade300,
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : unresolvedIssuesByBuilding.isEmpty && resolvedIssuesByBuilding.isEmpty
          ? _buildNoIssuesView()
          : _buildIssuesView(),
    );
  }

  Widget _buildNoIssuesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No issues found!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No issues for ${widget.subcontractorName} found.',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToCreateTemplate(),
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
    );
  }

  Widget _buildIssuesView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Issues by Building',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _navigateToCreateTemplate(),
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
            child: ListView(
              controller: _scrollController,
              children: _buildBuildingCards(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBuildingCards() {
    final allBuildings = {...unresolvedIssuesByBuilding.keys, ...resolvedIssuesByBuilding.keys}.toList();
    
    // Custom sorting: First collect all issues with their building info
    final buildingIssues = <String, List<SubcontractorIssue>>{};
    
    for (final buildingName in allBuildings) {
      final unresolvedIssues = unresolvedIssuesByBuilding[buildingName] ?? [];
      final resolvedIssues = resolvedIssuesByBuilding[buildingName] ?? [];
      buildingIssues[buildingName] = [...unresolvedIssues, ...resolvedIssues];
    }
    
    // Sort buildings by the earliest issue date, then by tower number, then by unit
    allBuildings.sort((a, b) {
      final aIssues = buildingIssues[a] ?? [];
      final bIssues = buildingIssues[b] ?? [];
      
      if (aIssues.isEmpty && bIssues.isEmpty) return 0;
      if (aIssues.isEmpty) return 1;
      if (bIssues.isEmpty) return -1;
      
      // Get earliest issue date for each building (day precision only)
      DateTime? aEarliestDate;
      DateTime? bEarliestDate;
      
      for (final issue in aIssues) {
        DateTime? issueDate;
        if (issue.originalItem.issueCreationTimestamp != null) {
          try {
            final parts = issue.originalItem.issueCreationTimestamp!.split(' ');
            if (parts.isNotEmpty) {
              final dateParts = parts[0].split('/');
              if (dateParts.length == 3) {
                // Create date with day precision only (set time to start of day)
                issueDate = DateTime(
                  int.parse(dateParts[2]), // year
                  int.parse(dateParts[0]), // month
                  int.parse(dateParts[1]), // day
                );
              }
            }
          } catch (e) {
            // If parsing fails, use current date
            issueDate = DateTime.now();
          }
        }
        
        if (issueDate != null) {
          if (aEarliestDate == null || issueDate.isBefore(aEarliestDate)) {
            aEarliestDate = issueDate;
          }
        }
      }
      
      for (final issue in bIssues) {
        DateTime? issueDate;
        if (issue.originalItem.issueCreationTimestamp != null) {
          try {
            final parts = issue.originalItem.issueCreationTimestamp!.split(' ');
            if (parts.isNotEmpty) {
              final dateParts = parts[0].split('/');
              if (dateParts.length == 3) {
                // Create date with day precision only (set time to start of day)
                issueDate = DateTime(
                  int.parse(dateParts[2]), // year
                  int.parse(dateParts[0]), // month
                  int.parse(dateParts[1]), // day
                );
              }
            }
          } catch (e) {
            // If parsing fails, use current date
            issueDate = DateTime.now();
          }
        }
        
        if (issueDate != null) {
          if (bEarliestDate == null || issueDate.isBefore(bEarliestDate)) {
            bEarliestDate = issueDate;
          }
        }
      }
      
      // Compare dates first (old to new)
      if (aEarliestDate != null && bEarliestDate != null) {
        final dateComparison = aEarliestDate.compareTo(bEarliestDate);
        if (dateComparison != 0) return dateComparison;
      } else if (aEarliestDate != null) {
        return -1; // a has date, b doesn't
      } else if (bEarliestDate != null) {
        return 1; // b has date, a doesn't
      }
      
      // Extract tower and unit numbers for sorting
      final aMatch = RegExp(r'Building (\d+)').firstMatch(a);
      final bMatch = RegExp(r'Building (\d+)').firstMatch(b);
      
      if (aMatch != null && bMatch != null) {
        final aTower = int.tryParse(aMatch.group(1)!) ?? 0;
        final bTower = int.tryParse(bMatch.group(1)!) ?? 0;
        
        // Compare tower numbers
        final towerComparison = aTower.compareTo(bTower);
        if (towerComparison != 0) return towerComparison;
        
        // If same tower, compare by unit number
        final aFirstIssue = aIssues.isNotEmpty ? aIssues.first : null;
        final bFirstIssue = bIssues.isNotEmpty ? bIssues.first : null;
        
        if (aFirstIssue != null && bFirstIssue != null) {
          final aUnit = int.tryParse(aFirstIssue.unitNumber) ?? 0;
          final bUnit = int.tryParse(bFirstIssue.unitNumber) ?? 0;
          return aUnit.compareTo(bUnit);
        }
      }
      
      // Fallback to string comparison
      return a.compareTo(b);
    });

    return allBuildings.map((buildingName) {
      final unresolvedIssues = unresolvedIssuesByBuilding[buildingName] ?? [];
      final resolvedIssues = resolvedIssuesByBuilding[buildingName] ?? [];

      return BuildingCard(
        buildingName: buildingName,
        unresolvedIssues: unresolvedIssues,
        resolvedIssues: resolvedIssues,
        onToggleUnresolved: _handleToggleUnresolved,
        onToggleResolved: _handleToggleResolved,
        getTemplateName: _getTemplateName,
        onCopyComplete: () => setState(() {}),
        onToggleResolvedSection: () => _toggleResolvedSection(buildingName),
        isResolvedSectionCollapsed: collapsedResolvedSections[buildingName] ?? true,
        onIssueTap: _navigateToZoomMode,
      );
    }).toList();
  }
}