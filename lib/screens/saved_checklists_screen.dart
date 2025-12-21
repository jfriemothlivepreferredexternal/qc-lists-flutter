import 'package:flutter/material.dart';
import '../models/checklist_models.dart';
import '../services/storage_service.dart';
import '../services/property_filter.dart';
import '../widgets/app_menu.dart';
import 'checklist_screen.dart';

class SavedChecklistsScreen extends StatefulWidget {
  final String? initialBuildingFilter;
  final String? initialQCFilter;
  final String? highlightChecklistId; // ID of checklist to highlight
  const SavedChecklistsScreen({
    super.key, 
    this.initialBuildingFilter, 
    this.initialQCFilter,
    this.highlightChecklistId,
  });

  @override
  State<SavedChecklistsScreen> createState() => _SavedChecklistsScreenState();
}

class _SavedChecklistsScreenState extends State<SavedChecklistsScreen> {
  List<ChecklistData> _savedChecklists = [];
  Map<String, QCTemplate> _templates = {};
  bool _isLoading = true;
  String? _selectedQCFilter; // null means show all
  String? _selectedBuildingFilter; // null means show all buildings
  String? _highlightedChecklistId; // Track highlighted checklist
  final ScrollController _scrollController = ScrollController();

  String _getChecklistId(ChecklistData checklist) {
    return '${checklist.templateId}_${checklist.buildingNumber}_${checklist.unitNumber}';
  }

  void _scrollToHighlightedChecklist() {
    if (_highlightedChecklistId == null || !_scrollController.hasClients) return;
    
    // Get filtered and sorted checklists to find the position
    final filteredChecklists = _getFilteredChecklists();
    final sortedChecklists = _getSortedChecklists(filteredChecklists);
    
    // Find the index of the highlighted checklist
    final targetIndex = sortedChecklists.indexWhere(
      (checklist) => _getChecklistId(checklist) == _highlightedChecklistId
    );
    
    if (targetIndex != -1) {
      // Calculate scroll position
      final double itemHeight = 120.0;
      final double targetPosition = targetIndex * itemHeight;
      final double maxScroll = _scrollController.position.maxScrollExtent;
      final double clampedPosition = targetPosition.clamp(0.0, maxScroll);
      
      _scrollController.animateTo(
        clampedPosition,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  List<ChecklistData> _getSortedChecklists(List<ChecklistData> checklists) {
    final sorted = List<ChecklistData>.from(checklists);
    sorted.sort((a, b) {
      // First sort by QC type (template ID)
      final qcComparison = a.templateId.compareTo(b.templateId);
      if (qcComparison != 0) return qcComparison;
      
      // Then by building number
      final buildingComparison = int.parse(a.buildingNumber).compareTo(int.parse(b.buildingNumber));
      if (buildingComparison != 0) return buildingComparison;
      
      // Then by tower number
      final towerComparison = _getTowerNumber(a.unitNumber).compareTo(_getTowerNumber(b.unitNumber));
      if (towerComparison != 0) return towerComparison;
      
      // Finally by unit number
      return int.parse(a.unitNumber).compareTo(int.parse(b.unitNumber));
    });
    return sorted;
  }

  @override
  void initState() {
  super.initState();
  _selectedBuildingFilter = widget.initialBuildingFilter;
  _selectedQCFilter = widget.initialQCFilter;
  _highlightedChecklistId = widget.highlightChecklistId;
  
  // Debug print
  print('DEBUG: SavedChecklistsScreen - PropertyFilter.selectedProperty = ${PropertyFilter.selectedProperty}');
  
  _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _highlightedChecklistId = null; // Clear highlight when leaving screen
    super.dispose();
  }

  Future<void> _loadData() async {
    final checklists = await StorageService.getSavedChecklists();
    final templates = await StorageService.loadTemplates();
    setState(() {
      _savedChecklists = checklists;
      _templates = templates;
      _isLoading = false;
    });
    
    // Auto-scroll to highlighted checklist after data loads
    if (_highlightedChecklistId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToHighlightedChecklist();
        });
      });
    }
  }

  List<String> _getUniqueQCTypes() {
    // Start with all saved checklists
    var filteredChecklists = _savedChecklists;
    
    // First, filter out checklists with invalid/missing templates
    filteredChecklists = filteredChecklists.where((checklist) {
      final template = _templates[checklist.templateId];
      return template != null; // Only include checklists with valid templates
    }).toList();
    
    // If a building filter is selected, only include checklists from that building
    if (_selectedBuildingFilter != null) {
      filteredChecklists = filteredChecklists.where((checklist) {
        return checklist.buildingNumber == _selectedBuildingFilter;
      }).toList();
    }
    
    // Extract unique QC types from the filtered checklists
    final qcTypes = <String>{};
    for (final checklist in filteredChecklists) {
      final template = _templates[checklist.templateId];
      if (template != null) {
        qcTypes.add(template.name);
      }
    }
    return qcTypes.toList()..sort();
  }

  List<ChecklistData> _getFilteredChecklists() {
    var filtered = _savedChecklists;
    
    // ALWAYS filter out invalid templates first
    filtered = filtered.where((checklist) {
      final template = _templates[checklist.templateId];
      return template != null;
    }).toList();
    
    // Then filter by QC type if selected
    if (_selectedQCFilter != null) {
      filtered = filtered.where((checklist) {
        final template = _templates[checklist.templateId];
        return template?.name == _selectedQCFilter;
      }).toList();
    }
    
    // Then filter by building if selected
    if (_selectedBuildingFilter != null) {
      filtered = filtered.where((checklist) {
        return checklist.buildingNumber == _selectedBuildingFilter;
      }).toList();
    }

    // Finally filter by global property filter
    filtered = filtered.where((checklist) {
      return PropertyFilter.matchesFilter(checklist.property);
    }).toList();

    return filtered;
  }

  List<String> _getUniqueBuildingNumbers() {
    // Start with all saved checklists
    var filteredChecklists = _savedChecklists;
    
    // First, filter out checklists with invalid/missing templates
    filteredChecklists = filteredChecklists.where((checklist) {
      final template = _templates[checklist.templateId];
      return template != null; // Only include checklists with valid templates
    }).toList();
    
    // If a QC filter is selected, only include checklists of that QC type
    if (_selectedQCFilter != null) {
      filteredChecklists = filteredChecklists.where((checklist) {
        final template = _templates[checklist.templateId];
        return template?.name == _selectedQCFilter;
      }).toList();
    }
    
    // Extract unique building numbers from the filtered checklists
    final buildingNumbers = <String>{};
    for (final checklist in filteredChecklists) {
      buildingNumbers.add(checklist.buildingNumber);
    }
    
    // Sort numerically and return
    final result = buildingNumbers.toList();
    result.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return result;
  }

  int _getEmailSentCountForBuilding(String building) {
    // Get checklists for this building that match current QC filter
    var filteredChecklists = _savedChecklists.where((checklist) {
      final template = _templates[checklist.templateId];
      return template != null && checklist.buildingNumber == building;
    }).toList();

    // If QC filter is selected, further filter by QC type
    if (_selectedQCFilter != null) {
      filteredChecklists = filteredChecklists.where((checklist) {
        final template = _templates[checklist.templateId];
        return template?.name == _selectedQCFilter;
      }).toList();
    }

    // Count how many have email sent = true
    return filteredChecklists.where((checklist) => checklist.emailSent).length;
  }

  String _getBuildingChipLabel(String building, List<String> availableBuildings) {
    final emailSentCount = _getEmailSentCountForBuilding(building);
    
    if (emailSentCount > 0) {
      return 'Building $building ($emailSentCount sent)';
    } else {
      return 'Building $building';
    }
  }

  String _getAllBuildingChipLabel() {
    if (_selectedQCFilter == null) {
      return 'All';
    }
    
    // Count total email sent for current QC filter across all buildings
    var totalEmailSent = _savedChecklists.where((checklist) {
      final template = _templates[checklist.templateId];
      bool matchesTemplate = template != null;
      bool matchesQC = template?.name == _selectedQCFilter;
      return matchesTemplate && matchesQC && checklist.emailSent;
    }).length;

    if (totalEmailSent > 0) {
      return 'All ($totalEmailSent sent)';
    } else {
      return 'All';
    }
  }

  String _getTowerFromUnit(String unitNumber) {
    final unit = int.tryParse(unitNumber);
    if (unit == null) return '';
    
    // Define the tower mappings for each floor
    const tower1Units = [101, 102, 103, 104, 201, 202, 203, 204, 301, 302, 303, 304];
    const tower2Units = [105, 106, 107, 108, 205, 206, 207, 208, 305, 306, 307, 308];
    const tower3Units = [109, 110, 111, 112, 209, 210, 211, 212, 309, 310, 311, 312];
    
    if (tower1Units.contains(unit)) {
      return 'Tower 1';
    } else if (tower2Units.contains(unit)) {
      return 'Tower 2';
    } else if (tower3Units.contains(unit)) {
      return 'Tower 3';
    }
    
    return '';
  }

  int _getTowerNumber(String unitNumber) {
    final unit = int.tryParse(unitNumber);
    if (unit == null) return 0;
    
    // Define the tower mappings for each floor
    const tower1Units = [101, 102, 103, 104, 201, 202, 203, 204, 301, 302, 303, 304];
    const tower2Units = [105, 106, 107, 108, 205, 206, 207, 208, 305, 306, 307, 308];
    const tower3Units = [109, 110, 111, 112, 209, 210, 211, 212, 309, 310, 311, 312];
    
    if (tower1Units.contains(unit)) {
      return 1;
    } else if (tower2Units.contains(unit)) {
      return 2;
    } else if (tower3Units.contains(unit)) {
      return 3;
    }
    
    return 0;
  }

  Future<void> _deleteChecklist(ChecklistData checklist) async {
    final template = _templates[checklist.templateId];
    if (template == null) return; // Skip if template doesn't exist
    
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Checklist'),
        content: Text('Are you sure you want to delete "${template.name} - Building ${checklist.buildingNumber}, ${_getTowerFromUnit(checklist.unitNumber)}, Unit ${checklist.unitNumber}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await StorageService.deleteChecklist(checklist);
        _loadData(); // Refresh the list
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error deleting checklist')),
          );
        }
      }
    }
  }

  Future<void> _loadChecklist(ChecklistData checklist) async {
    // Create navigation context data
    final contextData = {
      'buildingFilter': _selectedBuildingFilter,
      'qcFilter': _selectedQCFilter,
      'highlightId': _getChecklistId(checklist),
    };
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChecklistScreen(
          checklistData: checklist,
          previousScreen: 'saved_checklists',
          previousScreenData: contextData,
        ),
      ),
    );
    
    // Highlight this checklist when returning
    setState(() {
      _highlightedChecklistId = _getChecklistId(checklist);
    });
    
    // Always refresh the list when returning from checklist screen
    _loadData();
  }

  Future<void> _resendEmail(ChecklistData checklist) async {
    // Create navigation context data
    final contextData = {
      'buildingFilter': _selectedBuildingFilter,
      'qcFilter': _selectedQCFilter,
      'highlightId': _getChecklistId(checklist),
    };
    
    // Navigate to the checklist screen and trigger email
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChecklistScreen(
          checklistData: checklist,
          previousScreen: 'saved_checklists',
          previousScreenData: contextData,
        ),
      ),
    );
    
    // Highlight this checklist when returning
    setState(() {
      _highlightedChecklistId = _getChecklistId(checklist);
    });
    
    // Always refresh the list when returning
    _loadData();
  }

  Widget _buildChecklistsList() {
    final filteredChecklists = _getFilteredChecklists();
    
    if (filteredChecklists.isEmpty) {
      String message;
      
      // Build message based on active filters
      List<String> activeFilters = [];
      if (_selectedQCFilter != null) activeFilters.add(_selectedQCFilter!);

      if (_selectedBuildingFilter != null) activeFilters.add('Building $_selectedBuildingFilter');
      
      if (activeFilters.isEmpty) {
        message = 'No saved checklists found.';
      } else {
        message = 'No checklists found for ${activeFilters.join(', ')}.';
      }
      
      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }

    // Sort the checklists once outside the ListView
    final sortedChecklists = _getSortedChecklists(filteredChecklists);

    return ListView.builder(
      controller: _scrollController,
      itemCount: sortedChecklists.length,
      itemBuilder: (context, index) {
        final checklist = sortedChecklists[index];
        final template = _templates[checklist.templateId]!; // Safe since we filtered nulls
        final isHighlighted = _highlightedChecklistId == _getChecklistId(checklist);
        
        final completedItems = checklist.items.where((item) => item.isChecked).length;
        final totalItems = checklist.items.length;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isHighlighted ? Border.all(
              color: Colors.orange,
              width: 3,
            ) : null,
          ),
          child: Card(
            margin: EdgeInsets.zero,
            child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 0, 8), // Remove right padding entirely
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checklist.templateId, // Show shorthand (QC1, QC2, etc.)
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  template.name, // Show full name in smaller text
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'B${checklist.buildingNumber}T${_getTowerNumber(checklist.unitNumber)} Unit ${checklist.unitNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  checklist.emailSent ? 'Email sent ✓' : 'No email sent',
                  style: TextStyle(
                    color: checklist.emailSent ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${((completedItems / totalItems) * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: const EdgeInsets.all(4), // Reduce button padding
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32), // Smaller button
                  icon: Icon(
                    Icons.email,
                    size: 20, // Smaller icon
                    color: checklist.emailSent ? Colors.green : Colors.grey,
                  ),
                  onPressed: () => _resendEmail(checklist),
                  tooltip: checklist.emailSent ? 'Resend email' : 'Send email',
                ),
                IconButton(
                  padding: const EdgeInsets.all(4), // Reduce button padding
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32), // Smaller button
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20), // Smaller icon
                  onPressed: () => _deleteChecklist(checklist),
                  tooltip: 'Delete checklist',
                ),
              ],
            ),
            onTap: () async => await _loadChecklist(checklist),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Saved Checklists'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            onPressed: () => AppMenu.show(context, onTemplateEdited: _loadData),
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedChecklists.isEmpty
              ? const Center(
                  child: Text(
                    'No saved checklists found.\nCreate a checklist with building and unit numbers to see them here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    // Property filter display
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.all(16),
                      color: Colors.blue.shade100,
                      child: Text(
                        '${PropertyFilter.selectedProperty ?? 'All Properties'}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Show All Button
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0, left: 8.0, right: 8.0, bottom: 4.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.filter_alt_off),
                          label: const Text('Show All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade900,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedQCFilter = null;
                              _selectedBuildingFilter = null;
                            });
                          },
                        ),
                      ),
                    ),
                    // QC Type Filter Chips
                    if (_getUniqueQCTypes().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0, bottom: 4.0),
                              child: Text(
                                'QC Type:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  // "All" chip
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: FilterChip(
                                      label: const Text('All'),
                                      selected: _selectedQCFilter == null,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedQCFilter = null;
                                        });
                                      },
                                    ),
                                  ),
                                  // Individual QC type chips
                                  ..._getUniqueQCTypes().map((qcType) => Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: FilterChip(
                                      label: Text(qcType),
                                      selected: _selectedQCFilter == qcType,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedQCFilter = selected ? qcType : null;
                                        });
                                      },
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Building Filter Chips (show when there are available buildings)
                    Builder(
                      builder: (context) {
                        final availableBuildings = _getUniqueBuildingNumbers();
                        if (availableBuildings.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 8.0, bottom: 4.0),
                                child: Text(
                                  'Building:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    // "All Buildings" chip
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: FilterChip(
                                        label: Text(_getAllBuildingChipLabel()),
                                        selected: _selectedBuildingFilter == null,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedBuildingFilter = null;
                                          });
                                        },
                                      ),
                                    ),
                                    // Individual building chips using the cached availableBuildings
                                    ...availableBuildings.map((building) => Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: FilterChip(
                                        label: Text(_getBuildingChipLabel(building, availableBuildings)),
                                        selected: _selectedBuildingFilter == building,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedBuildingFilter = selected ? building : null;
                                          });
                                        },
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Filtered Checklists List
                    Expanded(
                      child: _buildChecklistsList(),
                    ),
                  ],
                ),
    );
  }
}