import '../models/subcontractor_issue.dart';
import '../services/storage_service.dart';
import '../services/property_filter.dart';

class SubcontractorIssueService {
  static Future<Map<String, dynamic>> loadIssuesForSubcontractor(String subcontractorName) async {
    // Load templates for displaying template names
    final templates = await StorageService.loadTemplates();
    
    // Load all saved checklists
    final allChecklists = await StorageService.getSavedChecklists();
    
    // Filter checklists by global property filter
    final filteredChecklists = allChecklists
        .where((checklist) => PropertyFilter.matchesFilter(checklist.property))
        .toList();
    
    // Find all issues for this subcontractor
    final unresolvedIssues = <SubcontractorIssue>[];
    final resolvedIssues = <SubcontractorIssue>[];
    
    for (final checklist in filteredChecklists) {
      for (final item in checklist.items) {
        if (item.hasIssue && item.subcontractor == subcontractorName) {
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
          
          if (item.isChecked) {
            resolvedIssues.add(issue);
          } else {
            unresolvedIssues.add(issue);
          }
        }
      }
    }
    
    // Group and sort issues by building
    final groupedUnresolved = _groupAndSortIssuesByBuilding(unresolvedIssues);
    final groupedResolved = _groupAndSortIssuesByBuilding(resolvedIssues);
    
    return {
      'unresolvedIssuesByBuilding': groupedUnresolved,
      'resolvedIssuesByBuilding': groupedResolved,
      'templates': templates,
    };
  }

  static Map<String, List<SubcontractorIssue>> _groupAndSortIssuesByBuilding(
      List<SubcontractorIssue> issues) {
    // Group issues by building
    final grouped = <String, List<SubcontractorIssue>>{};
    
    for (final issue in issues) {
      final buildingKey = 'Building ${issue.buildingNumber}';
      if (!grouped.containsKey(buildingKey)) {
        grouped[buildingKey] = [];
      }
      grouped[buildingKey]!.add(issue);
    }
    
    // Sort buildings by number and issues by unit
    final allBuildingKeys = grouped.keys.toList();
    allBuildingKeys.sort((a, b) {
      final aNum = int.tryParse(a.split(' ')[1]) ?? 0;
      final bNum = int.tryParse(b.split(' ')[1]) ?? 0;
      return aNum.compareTo(bNum);
    });
    
    final sorted = <String, List<SubcontractorIssue>>{};
    
    for (final key in allBuildingKeys) {
      final buildingIssues = grouped[key]!;
      buildingIssues.sort((a, b) {
        final aUnit = int.tryParse(a.unitNumber) ?? 0;
        final bUnit = int.tryParse(b.unitNumber) ?? 0;
        return aUnit.compareTo(bUnit);
      });
      sorted[key] = buildingIssues;
    }
    
    return sorted;
  }

  static Future<void> toggleIssueResolution(SubcontractorIssue issue) async {
    // Toggle the resolution status
    issue.originalItem.isVerified = !issue.originalItem.isVerified;
    
    if (issue.originalItem.isVerified) {
      // Set verification timestamp
      final now = DateTime.now();
      issue.originalItem.verificationTimestamp = 
          '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    } else {
      // Clear verification timestamp
      issue.originalItem.verificationTimestamp = null;
    }
    
    // Save the updated checklist
    await StorageService.saveChecklist(issue.parentChecklist);
  }

  static Future<void> toggleIssueChecked(SubcontractorIssue issue) async {
    // Toggle the QC inspector checked status
    issue.originalItem.isChecked = !issue.originalItem.isChecked;
    
    if (issue.originalItem.isChecked) {
      // Set timestamp
      final now = DateTime.now();
      issue.originalItem.timestamp = 
          '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    } else {
      // Clear timestamp
      issue.originalItem.timestamp = null;
    }
    
    // Save the updated checklist
    await StorageService.saveChecklist(issue.parentChecklist);
  }

  static Future<void> uncheckResolvedIssue(SubcontractorIssue issue) async {
    // Update the original item
    issue.originalItem.isVerified = false;
    issue.originalItem.verificationTimestamp = null;
    
    // Save the updated checklist
    await StorageService.saveChecklist(issue.parentChecklist);
  }
}