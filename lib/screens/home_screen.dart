import 'package:flutter/material.dart';
import 'template_selection_screen.dart';
import 'saved_checklists_screen.dart';
import 'template_edit_screen.dart';
// import 'issues_dashboard_screen.dart';
import 'building_selection_screen.dart';
import 'template_filter_selection_screen.dart';
import 'checklist_screen.dart';
import 'sub_lists_screen.dart';
import 'all_issues_grouped_screen.dart';
import '../models/checklist_models.dart';
import '../services/storage_service.dart';
import '../services/property_filter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    _checkPropertyPopup();
  }
  
  Future<void> _checkPropertyPopup() async {
    // Load saved property first
    await PropertyFilter.loadProperty();
    
    // Check if we should show popup (daily or when no property selected)
    final shouldShowDaily = await PropertyFilter.shouldShowDailyPopup();
    final noPropertySelected = PropertyFilter.selectedProperty == 'HIDE_ALL';
    
    if (shouldShowDaily || noPropertySelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPropertySelectionPopup();
      });
    }
  }
  
  void _showPropertySelectionPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Select Property',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please select which property you want to work with:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                // Property selection buttons in content area for better scalability
                ...PropertyFilter.getAvailableProperties().map((property) => 
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          PropertyFilter.setProperty(property);
                        });
                        PropertyFilter.markPopupShown();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        property,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              PropertyFilter.markPopupShown();
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16),
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _goToNewChecklist(BuildContext context) async {
    final templates = await StorageService.loadTemplates();
    final templateNames = templates.values.map((t) => t.name).toList();
    
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
    
    if (selectionData == null) return;
    
    final selectedTemplateName = selectionData['templateName'] as String;
    final selectedBuilding = selectionData['building'] as String;
    final selectedUnit = selectionData['unit'] as String;
    
    // Find the template by name to get the template ID
    final templateEntry = templates.entries.firstWhere(
      (entry) => entry.value.name == selectedTemplateName,
      orElse: () => throw Exception('Template not found'),
    );
    
    final templateId = templateEntry.key;
    final template = templateEntry.value;
    
    // Check if a checklist with this building/unit/template/property combination already exists
    final existingChecklists = await StorageService.getSavedChecklists();
    final existingChecklist = existingChecklists.where((checklist) =>
      checklist.buildingNumber == selectedBuilding &&
      checklist.unitNumber == selectedUnit &&
      checklist.templateId == templateId &&
      checklist.property == (PropertyFilter.selectedProperty ?? 'Alamira')
    ).firstOrNull;
    
    if (existingChecklist != null && mounted) {
      // Navigate to the existing checklist with a toast message
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChecklistScreen(checklistData: existingChecklist),
        ),
      );
      
      // Show toast message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigated to existing checklist for Building $selectedBuilding, Unit $selectedUnit'),
          duration: const Duration(seconds: 3),
        ),
      );
      return; // Don't create a new checklist
    }
    
    // Create a new checklist with the selected template
    final checklistData = ChecklistData(
      templateId: templateId,
      buildingNumber: selectedBuilding,
      unitNumber: selectedUnit,
      property: PropertyFilter.selectedProperty ?? 'Alamira',
      items: template.items.map((item) => ChecklistItem(text: item)).toList(),
    );
    
    // Navigate to the checklist screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChecklistScreen(checklistData: checklistData),
        ),
      );
    }
  }

  void _goToSavedChecklists(BuildContext context) {
    // Show sync warning toast immediately
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lists are NOT synced with any other users. See the About section for more info.'),
        duration: Duration(seconds: 4),
        backgroundColor: Colors.orange,
      ),
    );
    
    StorageService.getSavedChecklists().then((allChecklists) async {
      // Load templates to filter out checklists with invalid templates
      final templates = await StorageService.loadTemplates();
      
      // Filter checklists to only include those with valid templates
      final validChecklists = allChecklists.where((checklist) => 
        templates.containsKey(checklist.templateId)
      ).toList();
      
      // Sort by most recent activity (latest timestamp from any checked item)
      validChecklists.sort((a, b) {
        DateTime? aLatest;
        DateTime? bLatest;
        
        // Find the latest timestamp in checklist A
        for (final item in a.items) {
          if (item.timestamp != null) {
            try {
              final parts = item.timestamp!.split(' ');
              if (parts.length >= 2) {
                final dateParts = parts[0].split('/');
                final timeParts = parts[1].split(':');
                if (dateParts.length == 3 && timeParts.length == 3) {
                  final itemDate = DateTime(
                    int.parse(dateParts[2]), // year
                    int.parse(dateParts[0]), // month
                    int.parse(dateParts[1]), // day
                    int.parse(timeParts[0]), // hour
                    int.parse(timeParts[1]), // minute
                    int.parse(timeParts[2]), // second
                  );
                  if (aLatest == null || itemDate.isAfter(aLatest)) {
                    aLatest = itemDate;
                  }
                }
              }
            } catch (e) {
              // Skip invalid timestamps
            }
          }
        }
        
        // Find the latest timestamp in checklist B
        for (final item in b.items) {
          if (item.timestamp != null) {
            try {
              final parts = item.timestamp!.split(' ');
              if (parts.length >= 2) {
                final dateParts = parts[0].split('/');
                final timeParts = parts[1].split(':');
                if (dateParts.length == 3 && timeParts.length == 3) {
                  final itemDate = DateTime(
                    int.parse(dateParts[2]), // year
                    int.parse(dateParts[0]), // month
                    int.parse(dateParts[1]), // day
                    int.parse(timeParts[0]), // hour
                    int.parse(timeParts[1]), // minute
                    int.parse(timeParts[2]), // second
                  );
                  if (bLatest == null || itemDate.isAfter(bLatest)) {
                    bLatest = itemDate;
                  }
                }
              }
            } catch (e) {
              // Skip invalid timestamps
            }
          }
        }
        
        // Sort by most recent activity (nulls go to end)
        if (aLatest == null && bLatest == null) return 0;
        if (aLatest == null) return 1;
        if (bLatest == null) return -1;
        return bLatest.compareTo(aLatest);
      });
      
      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (context) => BuildingSelectionScreen(
            onBuildingSelected: (buildingNumber) {
              Navigator.pop(context, {'type': 'building', 'value': buildingNumber});
            },
            onChecklistSelected: (checklist) {
              Navigator.pop(context, {'type': 'checklist', 'value': checklist});
            },
            recentChecklists: validChecklists,
          ),
        ),
      );
      
      if (result == null) return;
      
      if (result['type'] == 'checklist') {
        // Navigate directly to the selected checklist
        final ChecklistData checklist = result['value'];
        final checklistResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChecklistScreen(
              checklistData: checklist,
              previousScreen: 'building_selection',
              previousScreenData: {
                'recentChecklists': validChecklists,
                'highlightId': '${checklist.templateId}_${checklist.buildingNumber}_${checklist.unitNumber}',
              },
            ),
          ),
        );
        
        // When returning from checklist, go back to building selection with highlighting
        if (checklistResult != 'home') {
          final highlightId = '${checklist.templateId}_${checklist.buildingNumber}_${checklist.unitNumber}';
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BuildingSelectionScreen(
                onBuildingSelected: (buildingNumber) async {
                  // Handle building selection - continue with normal flow
                  final allTemplates = await StorageService.loadTemplates();
                  final templateNames = allTemplates.values.map((t) => t.name).toList();
                  final selectedTemplate = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TemplateFilterSelectionScreen(
                        templateNames: templateNames,
                        onTemplateSelected: (templateName) {
                          Navigator.pop(context, templateName);
                        },
                      ),
                    ),
                  );
                  if (selectedTemplate != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SavedChecklistsScreen(
                          initialBuildingFilter: buildingNumber,
                          initialQCFilter: selectedTemplate,
                        ),
                      ),
                    );
                  }
                },
                onChecklistSelected: (selectedChecklist) {
                  // Handle another recent checklist selection
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChecklistScreen(
                        checklistData: selectedChecklist,
                        previousScreen: 'building_selection',
                        previousScreenData: {
                          'recentChecklists': validChecklists,
                          'highlightId': '${selectedChecklist.templateId}_${selectedChecklist.buildingNumber}_${selectedChecklist.unitNumber}',
                        },
                      ),
                    ),
                  );
                },
                recentChecklists: validChecklists,
                highlightChecklistId: highlightId,
              ),
            ),
          );
        }
        return;
      }
      
      // Handle building selection (existing flow)
      final selectedBuilding = result['value'] as String;
      final allTemplates = await StorageService.loadTemplates();
      final templateNames = allTemplates.values.map((t) => t.name).toList();
      final selectedTemplate = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => TemplateFilterSelectionScreen(
            templateNames: templateNames,
            onTemplateSelected: (templateName) {
              Navigator.pop(context, templateName);
            },
          ),
        ),
      );
      if (selectedTemplate == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SavedChecklistsScreen(
            initialBuildingFilter: selectedBuilding,
            initialQCFilter: selectedTemplate,
          ),
        ),
      );
    });
  }

  void _goToSubLists(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubListsScreen(),
      ),
    );
  }

  void _goToIssuesByUnit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllIssuesGroupedScreen(),
      ),
    );
  }

  void _editTemplates() async {
    // Show password dialog first
    final passwordController = TextEditingController();
    
    try {
      final isAuthorized = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password Required'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter password to edit templates:'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  final isCorrect = passwordController.text == 'drum';
                  Navigator.pop(context, isCorrect);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final isCorrect = passwordController.text == 'drum';
                Navigator.pop(context, isCorrect);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // Only proceed if password is correct
      if (isAuthorized == true && mounted) {
        // Load templates
        final templates = await StorageService.loadTemplates();
        
        if (!mounted) return;
        
        // Show template selection dialog
        final selectedTemplateId = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Template to Edit'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final templateId = templates.keys.elementAt(index);
                  final template = templates[templateId]!;
                  return ListTile(
                    title: Text(template.name),
                    subtitle: Text('${template.items.length} items'),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => Navigator.pop(context, templateId),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

        // If a template was selected, navigate to edit screen
        if (selectedTemplateId != null && mounted) {
          final result = await Navigator.push<QCTemplate>(
            context,
            MaterialPageRoute(
              builder: (context) => TemplateEditScreen(template: templates[selectedTemplateId]!),
            ),
          );

          if (result != null && mounted) {
            templates[selectedTemplateId] = result;
            await StorageService.saveTemplates(templates);
          }
        }
      } else if (isAuthorized == false && mounted) {
        // Show error message for wrong password
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always dispose the controller in finally block
      passwordController.dispose();
    }
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'About QC Lists',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This app does not sync QC data between users. Each user maintains their own local copy of checklists and will generally be responsible for certain QC lists as determined by the superintendent.\n\nIn case a user wants to see which lists have already been completed by others, all lists are sent to a website which will be accessible soon.\n\nNot having anything synced between app users helps simplify data alignment when lists are being made in areas where internet connectivity is limited.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('New Checklist'),
              onTap: () {
                Navigator.pop(context);
                _goToNewChecklist(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('View Saved Checklists'),
              onTap: () {
                Navigator.pop(context);
                _goToSavedChecklists(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Sub Lists'),
              onTap: () {
                Navigator.pop(context);
                _goToSubLists(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.view_list),
              title: const Text('Issues by Unit'),
              onTap: () {
                Navigator.pop(context);
                _goToIssuesByUnit(context);
              },
            ),
            const Divider(),
            // ListTile(
            //   leading: const Icon(Icons.assignment_late),
            //   title: const Text('Issues Dashboard'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(builder: (context) => const IssuesDashboardScreen()),
            //     );
            //   },
            // ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Templates'),
              onTap: () {
                Navigator.pop(context);
                _editTemplates();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showAbout(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get app title dynamically
    final appTitle = context.findAncestorWidgetOfExactType<MaterialApp>()?.title ?? 'Maison';
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(appTitle),
        actions: [
          IconButton(
            onPressed: () => _showMenu(context),
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Property Filter at top
            Container(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Individual property chips
                        ...PropertyFilter.getAvailableProperties().map((property) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(property),
                            selected: PropertyFilter.selectedProperty == property,
                            onSelected: (selected) {
                              setState(() {
                                PropertyFilter.setProperty(selected ? property : null);
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
            
            const Icon(
              Icons.checklist_rtl,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Quality Control Lists',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Create and manage your checklists',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Main Action Buttons - Custom Layout
            Column(
              children: [
                // Top row - Orange buttons (taller)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 100,
                        child: ElevatedButton.icon(
                          onPressed: () => _goToNewChecklist(context),
                          icon: const Icon(Icons.add_circle_outline, size: 24),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'New List',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              textScaler: TextScaler.linear(1.0),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 100,
                        child: ElevatedButton.icon(
                          onPressed: () => _goToSavedChecklists(context),
                          icon: const Icon(Icons.list_alt, size: 24),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Saved Lists',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              textScaler: TextScaler.linear(1.0),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Bottom row - Blue buttons (smaller)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 75,
                        child: ElevatedButton.icon(
                          onPressed: () => _goToSubLists(context),
                          icon: const Icon(Icons.people, size: 24),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Sub Lists',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              textScaler: TextScaler.linear(1.0),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 75,
                        child: ElevatedButton.icon(
                          onPressed: () => _goToIssuesByUnit(context),
                          icon: const Icon(Icons.view_list, size: 24),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Issues by Unit',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              textScaler: TextScaler.linear(1.0),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade400,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}