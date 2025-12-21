import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/subcontractor_issue.dart';
import '../models/checklist_models.dart';
import '../services/storage_service.dart';
import '../utils/tower_utils.dart';
import 'issue_card.dart';

class BuildingCard extends StatelessWidget {
  final String buildingName;
  final List<SubcontractorIssue> unresolvedIssues;
  final List<SubcontractorIssue> resolvedIssues;
  final Function(SubcontractorIssue) onToggleUnresolved;
  final Function(SubcontractorIssue) onToggleResolved;
  final String Function(String templateId) getTemplateName;
  final VoidCallback? onCopyComplete;
  final VoidCallback? onToggleResolvedSection;
  final bool isResolvedSectionCollapsed;
  final Function(SubcontractorIssue)? onIssueTap;

  const BuildingCard({
    super.key,
    required this.buildingName,
    required this.unresolvedIssues,
    required this.resolvedIssues,
    required this.onToggleUnresolved,
    required this.onToggleResolved,
    required this.getTemplateName,
    this.onCopyComplete,
    this.onToggleResolvedSection,
    this.isResolvedSectionCollapsed = true,
    this.onIssueTap,
  });

  void _copyBuildingIssues(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Copy Options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Copy All Option
              ListTile(
                leading: const Icon(Icons.copy_all),
                title: const Text('Copy All'),
                subtitle: const Text('Copy all unresolved issues for this building'),
                onTap: () {
                  Navigator.pop(context);
                  _copyAllIssues(context);
                },
              ),
              
              // Copy Uncopied Only Option
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Copy Uncopied Only'),
                subtitle: const Text('Copy only issues that haven\'t been copied yet'),
                onTap: () {
                  Navigator.pop(context);
                  _copyUncopiedIssues(context);
                },
              ),
              
              // Pick Tower Option
              ListTile(
                leading: const Icon(Icons.apartment),
                title: const Text('Pick Tower'),
                subtitle: const Text('Select a specific tower to copy from'),
                onTap: () {
                  Navigator.pop(context);
                  _showTowerSelection(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyAllIssues(BuildContext context) {
    final buffer = StringBuffer();
    final updatedChecklists = <ChecklistData>{};
    
    // Copy all unresolved issues for the building
    for (final issue in unresolvedIssues) {
      if (!issue.originalItem.isChecked) {
        final description = issue.issueDescription?.isNotEmpty == true 
            ? issue.issueDescription! 
            : issue.itemText;
        final formattedLocation = TowerUtils.formatBuildingTowerUnit(
            issue.buildingNumber, issue.unitNumber);
        buffer.writeln('$formattedLocation - $description');
        
        // Mark as copied and track checklist for saving
        issue.copied = true;
        updatedChecklists.add(issue.parentChecklist);
      }
    }
    
    _finalizeCopy(context, buffer, updatedChecklists, 'all unresolved issues');
  }

  void _copyUncopiedIssues(BuildContext context) {
    final buffer = StringBuffer();
    final updatedChecklists = <ChecklistData>{};
    
    // Copy only uncopied unresolved issues
    for (final issue in unresolvedIssues) {
      if (!issue.originalItem.isChecked && !issue.copied) {
        final description = issue.issueDescription?.isNotEmpty == true 
            ? issue.issueDescription! 
            : issue.itemText;
        final formattedLocation = TowerUtils.formatBuildingTowerUnit(
            issue.buildingNumber, issue.unitNumber);
        buffer.writeln('$formattedLocation - $description');
        
        // Mark as copied and track checklist for saving
        issue.copied = true;
        updatedChecklists.add(issue.parentChecklist);
      }
    }
    
    _finalizeCopy(context, buffer, updatedChecklists, 'uncopied issues');
  }

  void _showTowerSelection(BuildContext context) {
    // Get unique tower numbers from unresolved issues
    final towers = <String>{};
    for (final issue in unresolvedIssues) {
      if (!issue.originalItem.isChecked) {
        towers.add(TowerUtils.getTowerNumber(issue.unitNumber));
      }
    }
    
    final sortedTowers = towers.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Tower',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...sortedTowers.map((tower) => ListTile(
                leading: const Icon(Icons.apartment),
                title: Text('Tower $tower'),
                onTap: () {
                  Navigator.pop(context);
                  _showTowerCopyOptions(context, tower);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  void _showTowerCopyOptions(BuildContext context, String tower) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tower $tower Options',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Copy All for Tower
              ListTile(
                leading: const Icon(Icons.copy_all),
                title: Text('Copy All (Tower $tower)'),
                subtitle: Text('Copy all unresolved issues for tower $tower'),
                onTap: () {
                  Navigator.pop(context);
                  _copyTowerIssues(context, tower, false);
                },
              ),
              
              // Copy Uncopied Only for Tower
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: Text('Copy Uncopied Only (Tower $tower)'),
                subtitle: Text('Copy only uncopied issues for tower $tower'),
                onTap: () {
                  Navigator.pop(context);
                  _copyTowerIssues(context, tower, true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyTowerIssues(BuildContext context, String tower, bool uncopiedOnly) {
    final buffer = StringBuffer();
    final updatedChecklists = <ChecklistData>{};
    
    // Copy issues for the specific tower
    for (final issue in unresolvedIssues) {
      final issueTower = TowerUtils.getTowerNumber(issue.unitNumber);
      final shouldInclude = !issue.originalItem.isChecked && 
                           issueTower == tower &&
                           (!uncopiedOnly || !issue.copied);
      
      if (shouldInclude) {
        final description = issue.issueDescription?.isNotEmpty == true 
            ? issue.issueDescription! 
            : issue.itemText;
        final formattedLocation = TowerUtils.formatBuildingTowerUnit(
            issue.buildingNumber, issue.unitNumber);
        buffer.writeln('$formattedLocation - $description');
        
        // Mark as copied and track checklist for saving
        issue.copied = true;
        updatedChecklists.add(issue.parentChecklist);
      }
    }
    
    final copyType = uncopiedOnly ? 'uncopied issues for tower $tower' : 'all issues for tower $tower';
    _finalizeCopy(context, buffer, updatedChecklists, copyType);
  }

  void _finalizeCopy(BuildContext context, StringBuffer buffer, Set<ChecklistData> updatedChecklists, String copyType) {
    if (buffer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No $copyType to copy'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Save all updated checklists
    for (final checklist in updatedChecklists) {
      StorageService.saveChecklist(checklist);
    }
    
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    // Refresh UI to show copy icons
    onCopyComplete?.call();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${buildingName.toLowerCase()} $copyType copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Building header with copy button (only if there are unresolved issues)
          if (unresolvedIssues.isNotEmpty) 
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      buildingName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${unresolvedIssues.length} unresolved issue${unresolvedIssues.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _copyBuildingIssues(context),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade200,
                      foregroundColor: Colors.blue.shade800,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$buildingName - All Issues Resolved',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Unresolved issues section
          if (unresolvedIssues.isNotEmpty)
            _buildIssuesSection(
              'Unresolved Issues:', 
              unresolvedIssues, 
              isResolved: false,
              onToggle: onToggleUnresolved,
              onIssueTap: onIssueTap,
            ),
          
          // Resolved issues section
          if (resolvedIssues.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Resolved Issues:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onToggleResolvedSection,
                    icon: Icon(
                      isResolvedSectionCollapsed ? Icons.expand_more : Icons.expand_less,
                      size: 16,
                      color: Colors.purple.shade700,
                    ),
                    label: Text(
                      '${resolvedIssues.length} resolved',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isResolvedSectionCollapsed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: resolvedIssues.map((issue) => IssueCard(
                    issue: issue,
                    isResolved: true,
                    onToggle: () => onToggleResolved(issue),
                    getTemplateName: getTemplateName,
                    onTap: onIssueTap != null ? () => onIssueTap!(issue) : null,
                  )).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildIssuesSection(
    String title, 
    List<SubcontractorIssue> issues, {
    required bool isResolved,
    required Function(SubcontractorIssue) onToggle,
    Function(SubcontractorIssue)? onIssueTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isResolved ? Colors.purple.shade700 : Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ...issues.map((issue) => IssueCard(
            issue: issue,
            isResolved: isResolved,
            onToggle: () => onToggle(issue),
            getTemplateName: getTemplateName,
            onTap: onIssueTap != null ? () => onIssueTap(issue) : null,
          )),
        ],
      ),
    );
  }
}