import 'package:flutter/material.dart';

import '../models/checklist_models.dart';
import '../services/property_filter.dart';
import 'saved_checklists_screen.dart';

class BuildingSelectionScreen extends StatelessWidget {
  final void Function(String buildingNumber) onBuildingSelected;
  final void Function(ChecklistData checklist)? onChecklistSelected;
  final List<ChecklistData> recentChecklists;
  final String? highlightChecklistId; // ID of checklist to highlight

  const BuildingSelectionScreen({
    super.key, 
    required this.onBuildingSelected, 
    required this.recentChecklists,
    this.onChecklistSelected,
    this.highlightChecklistId,
  });

  String _getChecklistId(ChecklistData checklist) {
    return '${checklist.templateId}_${checklist.buildingNumber}_${checklist.unitNumber}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Building')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Property display
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(left: 16, right: 16, bottom: 16),
            color: Colors.blue.shade100,
            child: Text(
              '${PropertyFilter.selectedProperty ?? 'All Properties'}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          // See All Checklists Button
          Padding(
            padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('See All Checklists'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade100,
                  foregroundColor: Colors.blue.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SavedChecklistsScreen(
                        initialBuildingFilter: null,
                        initialQCFilter: null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Recent Lists
          Builder(
            builder: (context) {
              // Filter recent checklists by global property filter
              final filteredRecentChecklists = recentChecklists
                  .where((checklist) => PropertyFilter.matchesFilter(checklist.property))
                  .toList();
              
              if (filteredRecentChecklists.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('3 Most Recent Lists:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...filteredRecentChecklists.take(3).map((checklist) {
                      final isHighlighted = highlightChecklistId == _getChecklistId(checklist);
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: isHighlighted ? Border.all(
                                color: Colors.orange,
                                width: 3,
                              ) : null,
                            ),
                            child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.blue.shade200),
                              ),
                            ),
                            onPressed: onChecklistSelected != null ? () {
                              onChecklistSelected!(checklist);
                            } : null,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Building ${checklist.buildingNumber}, Unit ${checklist.unitNumber}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Template: ${checklist.templateId}',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.shade300),
                                  ),
                                  child: Text(
                                    '${checklist.items.where((item) => item.isChecked).length} ✓',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
          // Building Grid
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0, bottom: 24.0),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              children: List.generate(12, (index) {
                final buildingNumber = (index + 1).toString();
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => onBuildingSelected(buildingNumber),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Building $buildingNumber', style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
