import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/property_filter.dart';
import '../models/checklist_models.dart';
import 'subcontractor_detail_screen.dart';

class SubcontractorStats {
  final String name;
  final int issuesResolved;
  final int totalIssues;
  
  SubcontractorStats({
    required this.name,
    required this.issuesResolved,
    required this.totalIssues,
  });
  
  double get resolutionRate {
    if (totalIssues == 0) return -1; // Special value for 0/0 cases
    return issuesResolved / totalIssues;
  }
}

class SubListsScreen extends StatefulWidget {
  const SubListsScreen({super.key});

  @override
  State<SubListsScreen> createState() => _SubListsScreenState();
}

class _SubListsScreenState extends State<SubListsScreen> {
  List<String> recentSubs = [];
  List<SubcontractorStats> sortedSubcontractors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadRecentSubcontractors(),
      _calculateSubcontractorStats(),
    ]);
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadRecentSubcontractors() async {
    final recent = await StorageService.getRecentSubcontractors();
    recentSubs = recent;
  }

  Future<void> _calculateSubcontractorStats() async {
    final allSubcontractors = [
      'No Sub yet',
      'Sub A',
      'Sub B', 
      'Sub C',
      'APL',
      'AEP',
      'Appliances',
      'Asphalt',
      'Blinds',
      'Brick',
      'Cabinet supply',
      'Carpet',
      'Carpentry',
      'Cleaning',
      'Concrete',
      'Countertops',
      'Drywall/rc',
      'Eastway/swan',
      'Electrical',
      'Fire alarm',
      'Fire suppression',
      'Flooring',
      'Framing',
      'Gas',
      'Gypcrete',
      'HVAC',
      'Insulation',
      'Internet',
      'Landscaping',
      'Light fixtures',
      'Lumber',
      'Plumbing',
      'Pool',
      'Siding',
      'Site work',
      'Tile',
      'Windows'
    ];

    // Load all saved checklists
    final allChecklists = await StorageService.getSavedChecklists();
    
    // Filter checklists by global property filter
    final filteredChecklists = allChecklists
        .where((checklist) => PropertyFilter.matchesFilter(checklist.property))
        .toList();
    
    // Calculate stats for each subcontractor
    final statsMap = <String, SubcontractorStats>{};
    
    for (final subcontractor in allSubcontractors) {
      int totalIssues = 0;
      int issuesResolved = 0;
      
      for (final checklist in filteredChecklists) {
        for (final item in checklist.items) {
          if (item.hasIssue && item.subcontractor == subcontractor) {
            totalIssues++;
            if (item.isChecked) {
              issuesResolved++;
            }
          }
        }
      }
      
      statsMap[subcontractor] = SubcontractorStats(
        name: subcontractor,
        issuesResolved: issuesResolved,
        totalIssues: totalIssues,
      );
    }
    
    // Sort: 0/0 cases at bottom, others by resolution rate (highest first)
    final statsWithIssues = statsMap.values.where((s) => s.totalIssues > 0).toList();
    final statsWithoutIssues = statsMap.values.where((s) => s.totalIssues == 0).toList();
    
    statsWithIssues.sort((a, b) => b.resolutionRate.compareTo(a.resolutionRate));
    statsWithoutIssues.sort((a, b) => a.name.compareTo(b.name));
    
    sortedSubcontractors = [...statsWithIssues, ...statsWithoutIssues];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subcontractor Lists'),
        backgroundColor: Colors.orange.shade300,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Left side - All subcontractors sorted by issue resolution
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'All Subcontractors (by issue resolution rate)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: sortedSubcontractors.length,
                          itemBuilder: (context, index) {
                            final stats = sortedSubcontractors[index];
                            final subcontractor = stats.name;
                            
                            // Format the statistics display
                            String subtitle;
                            Color? subtitleColor;
                            if (stats.totalIssues == 0) {
                              subtitle = 'No issues assigned';
                              subtitleColor = Colors.grey;
                            } else {
                              final percentage = (stats.resolutionRate * 100).round();
                              subtitle = '${stats.issuesResolved}/${stats.totalIssues} resolved ($percentage%)';
                              if (stats.resolutionRate >= 0.8) {
                                subtitleColor = Colors.green;
                              } else if (stats.resolutionRate >= 0.5) {
                                subtitleColor = Colors.orange;
                              } else {
                                subtitleColor = Colors.red;
                              }
                            }
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  subcontractor,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                subtitle: Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SubcontractorDetailScreen(
                                        subcontractorName: subcontractor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(width: 16),
            // Right side - Recent selections
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  if (recentSubs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No recent selections',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: recentSubs.length,
                        itemBuilder: (context, index) {
                          final subcontractor = recentSubs[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: ListTile(
                              title: Text(
                                subcontractor,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.blue,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SubcontractorDetailScreen(
                                      subcontractorName: subcontractor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}