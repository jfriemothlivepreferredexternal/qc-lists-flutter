import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/subcontractor_issue.dart';
import '../utils/tower_utils.dart';
import '../widgets/issue_card.dart';

class IssuesBuildingCard extends StatelessWidget {
  final String buildingNumber;
  final List<SubcontractorIssue> unresolvedIssues;
  final List<SubcontractorIssue> resolvedIssues;
  final Function(SubcontractorIssue) onToggleUnresolved;
  final Function(SubcontractorIssue) onToggleResolved;
  final String Function(String) getTemplateName;
  final VoidCallback? onCopyComplete;
  final VoidCallback onToggleResolvedSection;
  final bool isResolvedSectionCollapsed;
  final Function(SubcontractorIssue) onIssueTap;

  const IssuesBuildingCard({
    super.key,
    required this.buildingNumber,
    required this.unresolvedIssues,
    required this.resolvedIssues,
    required this.onToggleUnresolved,
    required this.onToggleResolved,
    required this.getTemplateName,
    this.onCopyComplete,
    required this.onToggleResolvedSection,
    required this.isResolvedSectionCollapsed,
    required this.onIssueTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Building header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: [
              Text(
                'Building $buildingNumber',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${unresolvedIssues.length + resolvedIssues.length} issues',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              // Copy Button
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy Issues',
                onPressed: () => _showTowerSelectionAndCopy(context),
              ),
            ],
          ),
        ),
        
        // Unresolved issues section
        if (unresolvedIssues.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Unresolved Issues',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ),
          ...unresolvedIssues.map((issue) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: IssueCard(
              issue: issue,
              isResolved: issue.isResolved,
              onToggle: () => onToggleUnresolved(issue),
              getTemplateName: getTemplateName,
              onTap: () => onIssueTap(issue),
            ),
          )),
          const SizedBox(height: 16),
        ],
        
        // Resolved issues section - collapsible
        if (resolvedIssues.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const Text(
                  'Resolved Issues',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(isResolvedSectionCollapsed 
                      ? Icons.keyboard_arrow_down 
                      : Icons.keyboard_arrow_up),
                  onPressed: onToggleResolvedSection,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          if (!isResolvedSectionCollapsed)
            ...resolvedIssues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: IssueCard(
                issue: issue,
                isResolved: issue.isResolved,
                onToggle: () => onToggleResolved(issue),
                getTemplateName: getTemplateName,
                onTap: () => onIssueTap(issue),
              ),
            )),
        ],
        const Divider(height: 32, thickness: 2),
      ],
    );
  }

  void _showTowerSelectionAndCopy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Tower to Copy',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Tower 1 Option
              ListTile(
                leading: const Icon(Icons.apartment),
                title: const Text('Tower 1'),
                subtitle: const Text('Copy all issues from Tower 1'),
                onTap: () {
                  Navigator.pop(context);
                  _copyIssuesFromTower(context, '1');
                },
              ),
              
              // Tower 2 Option
              ListTile(
                leading: const Icon(Icons.apartment),
                title: const Text('Tower 2'),
                subtitle: const Text('Copy all issues from Tower 2'),
                onTap: () {
                  Navigator.pop(context);
                  _copyIssuesFromTower(context, '2');
                },
              ),
              
              // Tower 3 Option
              ListTile(
                leading: const Icon(Icons.apartment),
                title: const Text('Tower 3'),
                subtitle: const Text('Copy all issues from Tower 3'),
                onTap: () {
                  Navigator.pop(context);
                  _copyIssuesFromTower(context, '3');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyIssuesFromTower(BuildContext context, String towerNumber) {
    final buffer = StringBuffer();
    
    // Combine all issues (resolved and unresolved)
    final allIssues = [...unresolvedIssues, ...resolvedIssues];
    
    // Filter issues for the selected tower and sort by unit number
    final towerIssues = allIssues
        .where((issue) => TowerUtils.getTowerNumber(issue.unitNumber) == towerNumber)
        .toList();
    
    // Sort by unit number to group them together
    towerIssues.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
    
    if (towerIssues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No issues found for Tower $towerNumber in Building $buildingNumber'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Add building header once at the top
    buffer.writeln('Building $buildingNumber Tower $towerNumber');
    buffer.writeln();
    
    // Group by unit number and add line breaks between different units
    String? previousUnit;
    for (final issue in towerIssues) {
      // Add line break when unit number changes
      if (previousUnit != null && issue.unitNumber != previousUnit) {
        buffer.writeln(); // Add extra line break between units
      }
      
      final description = issue.issueDescription?.isNotEmpty == true 
          ? issue.issueDescription! 
          : issue.itemText;
      
      final subcontractor = issue.originalItem.subcontractor ?? 'Unknown';
      
      buffer.writeln('${issue.unitNumber} - $subcontractor - $description');
      
      previousUnit = issue.unitNumber;
    }
    
    if (buffer.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${towerIssues.length} issues from Tower $towerNumber'),
          backgroundColor: Colors.green,
        ),
      );
      
      if (onCopyComplete != null) {
        onCopyComplete!();
      }
    }
  }
}
