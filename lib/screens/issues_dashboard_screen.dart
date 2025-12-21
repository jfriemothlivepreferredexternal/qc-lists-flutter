import 'package:flutter/material.dart';
import '../models/checklist_models.dart';
import '../services/storage_service.dart';
import 'building_template_issues_screen.dart';

class IssuesDashboardScreen extends StatefulWidget {
  const IssuesDashboardScreen({super.key});

  @override
  State<IssuesDashboardScreen> createState() => _IssuesDashboardScreenState();
}

class _IssuesDashboardScreenState extends State<IssuesDashboardScreen> {
  Map<String, QCTemplate> _templates = {};
  List<ChecklistData> _allChecklists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _templates = await StorageService.loadTemplates();
    _allChecklists = await StorageService.loadAllChecklists();
    
    setState(() => _isLoading = false);
  }

  // Calculate issues for a specific building/template combination
  Map<String, dynamic> _calculateIssueStats(int building, String templateId) {
    final buildingStr = building.toString();
    print('Looking for building "$buildingStr" template "$templateId"');
    print('All checklists: ${_allChecklists.map((c) => 'B${c.buildingNumber}/${c.templateId}').join(', ')}');
    
    final relevantChecklists = _allChecklists.where((checklist) =>
      checklist.buildingNumber == buildingStr &&
      checklist.templateId == templateId
    ).toList();
    
    print('Found ${relevantChecklists.length} relevant checklists for building "$buildingStr" template "$templateId"');

    final List<_IssueItem> issues = [];
    
    for (final checklist in relevantChecklists) {
      for (int i = 0; i < checklist.items.length; i++) {
        final item = checklist.items[i];
        // Include items with issues OR photos
        if ((item.hasIssue && item.issueDescription != null && item.issueDescription!.isNotEmpty) || 
            item.photos.isNotEmpty) {
          // Debug: Print issue found
          print('Found issue/photo in B${building} ${templateId}: hasIssue=${item.hasIssue}, photos=${item.photos.length}, desc="${item.issueDescription}", issueCreationTimestamp=${item.issueCreationTimestamp}');
          
          // Parse the timestamp from issue creation timestamp
          DateTime? issueDate;
          if (item.issueCreationTimestamp != null) {
            try {
              final parts = item.issueCreationTimestamp!.split(' ');
              if (parts.length >= 2) {
                final dateParts = parts[0].split('/');
                final timeParts = parts[1].split(':');
                if (dateParts.length == 3 && timeParts.length == 3) {
                  issueDate = DateTime(
                    int.parse(dateParts[2]), // year
                    int.parse(dateParts[0]), // month
                    int.parse(dateParts[1]), // day
                    int.parse(timeParts[0]), // hour
                    int.parse(timeParts[1]), // minute
                    int.parse(timeParts[2]), // second
                  );
                }
              }
            } catch (e) {
              // If parsing fails, use current date
              print('Error parsing timestamp: $e');
              issueDate = DateTime.now();
            }
          } else {
            print('No issue creation timestamp for issue!');
          }
          
          issues.add(_IssueItem(
            checklist: checklist,
            item: item,
            itemIndex: i,
            issueDate: issueDate ?? DateTime.now(),
          ));
        }
      }
    }

    if (issues.isEmpty) {
      return {'hasIssues': false};
    }

    final now = DateTime.now();
    final tenSecondsAgo = now.subtract(const Duration(seconds: 10));
    
    final hasOldIssues = issues.any((issue) => issue.issueDate.isBefore(tenSecondsAgo));
    final observedCount = issues.where((issue) => issue.item.isVerified || issue.item.isFlagged).length;
    final observedPercent = (observedCount / issues.length * 100).round();
    final hasFlaggedIssues = issues.any((issue) => issue.item.isFlagged);
    final hasVerifiedIssues = issues.any((issue) => issue.item.isVerified);
    
    return {
      'hasIssues': true,
      'hasOldIssues': hasOldIssues,
      'observedPercent': observedPercent,
      'totalIssues': issues.length,
      'hasFlaggedIssues': hasFlaggedIssues,
      'hasVerifiedIssues': hasVerifiedIssues,
    };
  }

  Color _getTextColor(Map<String, dynamic> stats) {
    if (!stats['hasIssues']) {
      return Colors.grey; // No issues
    }
    
    if (!stats['hasOldIssues']) {
      return Colors.black; // Only new issues
    }
    
    if (stats['observedPercent'] == 0) {
      return Colors.red; // Old issues, none observed
    }
    
    return Colors.green; // Old issues, some observed
  }

  String _getDisplayText(int building, String templateId, Map<String, dynamic> stats) {
    final templateName = _templates[templateId]?.name ?? templateId;
    final baseText = 'Building $building - $templateName';
    
    if (!stats['hasIssues']) {
      return baseText;
    }
    
    if (stats['hasOldIssues'] && stats['observedPercent'] > 0) {
      return '$baseText   ${stats['observedPercent']}%';
    }
    
    if (stats['hasOldIssues'] && stats['observedPercent'] == 0) {
      return '$baseText   0%';
    }
    
    return baseText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issues Dashboard'),
        backgroundColor: Colors.orange.shade300,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Legend
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Grey = Has no issues', style: TextStyle(fontSize: 14))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Black = Has only new issues (<10 seconds old)', style: TextStyle(fontSize: 14))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Red = Old issues that have NOT been looked at by senior management yet', style: TextStyle(fontSize: 14))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Green = Old issues that have been at least partially looked at by senior management', style: TextStyle(fontSize: 14))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Blue: Percentage of issues that senior management has looked at',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Total checklists debug info
              Text(
                'Total checklists: ${_allChecklists.length}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              
              // Building/Template list
              ..._templates.keys.map((templateId) {
                final templateName = _templates[templateId]?.name ?? templateId;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              templateName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(thickness: 2),
                    ...List.generate(12, (buildingIndex) {
                      final building = buildingIndex + 1;
                      final stats = _calculateIssueStats(building, templateId);
                      final textColor = _getTextColor(stats);
                      final baseText = 'Building $building - $templateName';
                      final hasPercentage = stats['hasOldIssues'] == true && stats['observedPercent'] != null;
                      return ListTile(
                        title: hasPercentage
                          ? RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: stats['hasOldIssues'] == true ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 16,
                                ),
                                children: [
                                  TextSpan(text: baseText),
                                  TextSpan(
                                    text: '   ${stats['observedPercent']}%',
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              baseText,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: stats['hasOldIssues'] == true ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                        trailing: stats['hasIssues'] == true
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (stats['hasVerifiedIssues'] == true)
                                  const Icon(Icons.star, color: Colors.blue, size: 20),
                                if (stats['hasVerifiedIssues'] == true && stats['hasFlaggedIssues'] == true)
                                  const SizedBox(width: 8),
                                if (stats['hasFlaggedIssues'] == true)
                                  const Icon(Icons.flag, color: Colors.blue, size: 20),
                              ],
                            )
                          : null,
                        enabled: stats['hasIssues'] == true,
                        onTap: stats['hasIssues'] == true
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BuildingTemplateIssuesScreen(
                                    buildingNumber: building,
                                    templateId: templateId,
                                    onIssuesUpdated: _loadData,
                                  ),
                                ),
                              );
                            }
                          : null,
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
    );
  }
}

// Helper class to track issue items with their metadata
class _IssueItem {
  final ChecklistData checklist;
  final ChecklistItem item;
  final int itemIndex;
  final DateTime issueDate;

  _IssueItem({
    required this.checklist,
    required this.item,
    required this.itemIndex,
    required this.issueDate,
  });
}
