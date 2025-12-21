import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/checklist_models.dart';
import '../services/storage_service.dart';

class ZoomModeView extends StatelessWidget {
  final List<ChecklistItem> items;
  final int zoomedItemIndex;
  final VoidCallback exitZoomMode;
  final VoidCallback debouncedSave;
  final VoidCallback checkAndNext;
  final VoidCallback goToNextItem;
  final VoidCallback goToPreviousItem;
  final Function(VoidCallback) setState;
  final String buildingNumber;
  final String unitNumber;
  final String templateName;

  const ZoomModeView({
    super.key,
    required this.items,
    required this.zoomedItemIndex,
    required this.exitZoomMode,
    required this.debouncedSave,
    required this.checkAndNext,
    required this.goToNextItem,
    required this.goToPreviousItem,
    required this.setState,
    required this.buildingNumber,
    required this.unitNumber,
    required this.templateName,
  });

  Future<void> _showIssueDialog(BuildContext context, ChecklistItem item) async {
    // Store original description for change detection
    final originalDescription = item.issueDescription;
    
    // If the item doesn't already have an issue, ask if they want to describe it
    if (!item.hasIssue) {
      final shouldDescribe = await showDialog<bool?>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Issue Found'),
            content: const Text('Add a description for this issue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          );
        },
      );
      
      if (shouldDescribe == null) {
        return; // User cancelled or dismissed dialog
      }
      
      if (!shouldDescribe) {
        // Set issue with no description but still need subcontractor
        final subcontractor = await _showSubcontractorDialog(context);
        if (subcontractor == null) {
          return; // User cancelled subcontractor selection
        }
        
        final now = DateTime.now();
        setState(() {
          item.hasIssue = true;
          item.issueDescription = '(no description)';
          item.subcontractor = subcontractor;
          // Set issue creation timestamp if this is a new issue
          if (item.issueCreationTimestamp == null) {
            item.issueCreationTimestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          }
          // Add timestamp if not already present
          if (item.timestamp == null) {
            item.timestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
          }
        });
        debouncedSave();
        return;
      }
    }
    
    // Show the description dialog
    final TextEditingController controller = TextEditingController(
      text: item.issueDescription == '(no description)' ? '' : (item.issueDescription ?? ''),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Describe Issue'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter issue description...',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            if (item.hasIssue && item.issueDescription != null && item.issueDescription!.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final shouldClear = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Clear Issue'),
                        content: const Text('Are you sure you want to clear this issue?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Yes'),
                          ),
                        ],
                      );
                    },
                  );
                  
                  if (shouldClear == true) {
                    setState(() {
                      item.hasIssue = false;
                      item.issueDescription = null;
                      item.subcontractor = null;
                    });
                    debouncedSave();
                    if (context.mounted) {
                      Navigator.of(context).pop({'action': 'clear'});
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear'),
              ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  // If description is empty, remove the issue flag
                  Navigator.of(context).pop({'action': 'clear'});
                } else {
                  // Need to save description and get subcontractor
                  Navigator.of(context).pop({'action': 'save', 'description': controller.text.trim()});
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    
    if (result == null) return; // User cancelled
    
    if (result['action'] == 'clear') {
      setState(() {
        item.hasIssue = false;
        item.issueDescription = null;
        item.subcontractor = null;
      });
      debouncedSave();
      return;
    }
    
    if (result['action'] == 'save') {
      final description = result['description'] as String;
      
      // Get subcontractor selection
      final subcontractor = await _showSubcontractorDialog(context);
      if (subcontractor == null) {
        return; // User cancelled subcontractor selection
      }
      
      final now = DateTime.now();
      final hasChanges = description != (originalDescription ?? '');
      
      setState(() {
        item.hasIssue = true;
        item.issueDescription = description;
        item.subcontractor = subcontractor;
        // Set issue creation timestamp if this is a new issue
        if (item.issueCreationTimestamp == null) {
          item.issueCreationTimestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        }
        // Add timestamp if not already present
        if (item.timestamp == null) {
          item.timestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        }
      });
      
      // Show creation date info popup only if issue was changed and has existing timestamp
      if (hasChanges && item.issueCreationTimestamp != null && originalDescription != null) {
        await _showCreationDateInfo(context);
      }
      
      debouncedSave();
    }
  }

  Future<String?> _showSubcontractorDialog(BuildContext context) async {
    final allSubcontractors = ['No Sub yet', 'Sub A', 'Sub B', 'Sub C', 'APL', 'AEP', 'Appliances', 'Asphalt', 'Blinds', 'Brick', 'Cabinet supply', 'Carpet', 'Carpentry', 'Cleaning', 'Concrete', 'Countertops', 'Drywall/rc', 'Eastway/swan', 'Electrical', 'Fire alarm', 'Fire suppression', 'Flooring', 'Framing', 'Gas', 'Gypcrete', 'HVAC', 'Insulation', 'Internet', 'Landscaping', 'Light fixtures', 'Lumber', 'Plumbing', 'Pool', 'Siding', 'Site work', 'Tile', 'Windows'];
    
    // Load recent subcontractors
    final recentSubs = await StorageService.getRecentSubcontractors();
    
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Subcontractor'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Row(
              children: [
                // Left side - All subcontractors
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'All Subcontractors',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: allSubcontractors.length,
                          itemBuilder: (context, index) {
                            final subcontractor = allSubcontractors[index];
                            return ListTile(
                              title: Text(
                                subcontractor,
                                style: const TextStyle(fontSize: 16),
                              ),
                              onTap: () async {
                                await StorageService.addRecentSubcontractor(subcontractor);
                                if (context.mounted) {
                                  Navigator.of(context).pop(subcontractor);
                                }
                              },
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (recentSubs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No recent selections',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: recentSubs.length,
                            itemBuilder: (context, index) {
                              final subcontractor = recentSubs[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: ListTile(
                                  title: Text(
                                    subcontractor,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                  onTap: () async {
                                    await StorageService.addRecentSubcontractor(subcontractor);
                                    if (context.mounted) {
                                      Navigator.of(context).pop(subcontractor);
                                    }
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreationDateInfo(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Issue Creation Dates',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Important Information:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '• If management questions why a "new" issue appears to have been known about for a while, it\'s because this is an edited version of an existing issue.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '• This preserves the historical record of when the issue was first discovered.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Tip: Create a new issue instead if you need a fresh creation date for tracking purposes.',
                        style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  void _duplicateItem(BuildContext context, ChecklistItem item) async {
    // Count existing duplicates to determine the next number
    int duplicateCount = 0;
    final baseText = item.text.replaceAll(RegExp(r' \(duplicate #\d+\)$'), '');
    
    for (final existingItem in items) {
      if (existingItem.text.startsWith(baseText)) {
        final match = RegExp(r' \(duplicate #(\d+)\)$').firstMatch(existingItem.text);
        if (match != null) {
          final number = int.parse(match.group(1)!);
          if (number > duplicateCount) {
            duplicateCount = number;
          }
        }
      }
    }
    
    // Check if we've reached the limit of 16 duplicates
    if (duplicateCount >= 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum of 16 duplicates per item reached'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Show confirmation dialog
    final shouldDuplicate = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Duplicate Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to duplicate this item?'),
              const SizedBox(height: 8),
              Text(
                'New item will be named:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  '"$baseText (duplicate #${duplicateCount + 1})"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Duplicate'),
            ),
          ],
        );
      },
    );
    
    if (shouldDuplicate != true) return;
    
    // Create duplicate item
    final duplicateItem = ChecklistItem(
      text: '$baseText (duplicate #${duplicateCount + 1})',
      isChecked: false,
      hasIssue: false,
      isVerified: false,
      isFlagged: false,
      photos: [], // Start with no photos
      isCopied: false,
    );
    
    setState(() {
      // Insert duplicate right after the current item
      items.insert(zoomedItemIndex + 1, duplicateItem);
    });
    
    debouncedSave();
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item duplicated as "${duplicateItem.text}"'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _takePicture(BuildContext context, ChecklistItem item) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (photo != null) {
      // Build descriptive filename
      final now = DateTime.now();
      String sanitizedText = item.text.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
      String sanitizedTemplate = templateName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
      String filename = 'B${buildingNumber}_U${unitNumber}_T${sanitizedTemplate}_Item_${sanitizedText}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.jpg';

      // Save to app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final newPath = '${directory.path}/$filename';
      await File(photo.path).copy(newPath);

      setState(() {
        item.photos.add(newPath);
        // Add timestamp if not already present
        if (item.timestamp == null) {
          item.timestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        }
      });
      debouncedSave();
      
      // Show confirmation toast
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo added to: ${item.text}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = items[zoomedItemIndex];
    final progress = (items.where((i) => i.isChecked).length + 1);
    final total = items.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Previous item (if not first item)
        if (zoomedItemIndex > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // Toggle previous item's check status
                    setState(() {
                      final item = items[zoomedItemIndex - 1];
                      item.isChecked = !item.isChecked;
                      
                      // Add timestamp when checking, remove when unchecking
                      if (item.isChecked) {
                        final now = DateTime.now();
                        item.timestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
                      } else {
                        item.timestamp = null;
                      }
                    });
                    debouncedSave();
                  },
                  child: Icon(
                    items[zoomedItemIndex - 1].isChecked 
                      ? Icons.check_circle 
                      : Icons.radio_button_unchecked,
                    color: items[zoomedItemIndex - 1].isChecked 
                      ? Colors.green 
                      : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: goToPreviousItem,
                    child: Text(
                      'Previous: ${items[zoomedItemIndex - 1].text}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        decoration: items[zoomedItemIndex - 1].isChecked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Skip, Issue, Camera, and Duplicate buttons for unchecked items - show above the task
        if (!item.isChecked) ...[
          Row(
            children: [
              // Skip button (1/4 width)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: goToNextItem,
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: Colors.blueGrey.shade600,
                    side: BorderSide(color: Colors.blueGrey.shade600, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Issue toggle button (1/4 width)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showIssueDialog(context, item),
                  icon: Icon(
                    item.hasIssue ? Icons.warning : Icons.warning_amber_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'Issue',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: item.hasIssue ? Colors.red.shade600 : Colors.orange.shade600,
                    backgroundColor: item.hasIssue ? Colors.red.shade50 : null,
                    side: BorderSide(
                      color: item.hasIssue ? Colors.red.shade600 : Colors.orange.shade600,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Camera button (1/4 width)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _takePicture(context, item),
                  icon: Icon(
                    item.photos.isNotEmpty ? Icons.camera_alt : Icons.camera_alt_outlined,
                    size: 18,
                  ),
                  label: Text(
                    item.photos.isEmpty ? 'Photo' : '${item.photos.length}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: item.photos.isNotEmpty ? Colors.teal.shade600 : Colors.teal.shade400,
                    backgroundColor: item.photos.isNotEmpty ? Colors.teal.shade50 : null,
                    side: BorderSide(
                      color: item.photos.isNotEmpty ? Colors.teal.shade600 : Colors.teal.shade400,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Duplicate button (1/4 width)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _duplicateItem(context, item),
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: const Text(
                    'Dup.',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: Colors.indigo.shade600,
                    side: BorderSide(color: Colors.indigo.shade600, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Large text item
        Expanded(
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: item.isChecked ? Colors.green.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.isChecked ? Colors.green.shade300 : Colors.blue.shade200,
                    width: item.isChecked ? 3 : 2,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate dynamic font size based on text length and available space
                    double baseFontSize = 32;
                    int textLength = item.text.length;
                    
                    // Reduce font size for longer text
                    if (textLength > 100) {
                      baseFontSize = 20;
                    } else if (textLength > 60) {
                      baseFontSize = 24;
                    } else if (textLength > 40) {
                      baseFontSize = 28;
                    }
                    
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Status indicator - only show if checked
                        if (item.isChecked) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'COMPLETED',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          Icon(
                            Icons.check_circle,
                            size: 48,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(height: 24),
                        ],
                        
                        // Add spacing for unchecked items to center the text properly
                        if (!item.isChecked) const SizedBox(height: 48),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Text(
                              item.text,
                              style: TextStyle(
                                fontSize: baseFontSize,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                                decoration: item.isChecked 
                                  ? TextDecoration.lineThrough 
                                  : TextDecoration.none,
                                color: item.isChecked 
                                  ? Colors.green.shade800 
                                  : Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Issue description overlay
              if (item.hasIssue && item.issueDescription != null && item.issueDescription!.isNotEmpty)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => _showIssueDialog(context, item),
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red,
                          width: 3,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.red,
                                size: 32,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ISSUE',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Text(
                                    item.issueDescription!,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.black87,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (item.subcontractor != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.blue.shade300, width: 2),
                                      ),
                                      child: Text(
                                        'Tagged with: ${item.subcontractor}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Photo thumbnails
        if (item.photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: item.photos.length,
              itemBuilder: (context, index) {
                final photoPath = item.photos[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Show full-size photo
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              child: Stack(
                                children: [
                                  Image.file(File(photoPath)),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(photoPath),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            // Delete photo with confirmation
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Photo'),
                                content: const Text('Are you sure you want to delete this photo?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final photoPath = item.photos[index];
                                      setState(() {
                                        item.photos.removeAt(index);
                                      });
                                      debouncedSave();
                                      
                                      // Delete the actual file from storage with safety check
                                      try {
                                        final file = File(photoPath);
                                        final appDirs = [
                                          (await getApplicationDocumentsDirectory()).path,
                                          (await getTemporaryDirectory()).path,
                                          (await getApplicationSupportDirectory()).path,
                                        ];
                                        
                                        // Only delete if file is in app-controlled directory
                                        final isInAppDirectory = appDirs.any((dir) => photoPath.startsWith(dir));
                                        if (isInAppDirectory && await file.exists()) {
                                          await file.delete();
                                        }
                                      } catch (e) {
                                        // Handle deletion error silently
                                      }
                                      
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        
        const SizedBox(height: 24),
        
        if (item.isChecked) ...[
          // Uncheck button
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                final item = items[zoomedItemIndex];
                item.isChecked = false;
                item.timestamp = null; // Remove timestamp when unchecking
              });
              debouncedSave();
            },
            icon: const Icon(Icons.undo, size: 28),
            label: const Text(
              'Uncheck Item',
              style: TextStyle(fontSize: 20),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Next button (if not last item)
          if (zoomedItemIndex < items.length - 1)
            ElevatedButton.icon(
              onPressed: goToNextItem,
              icon: const Icon(Icons.arrow_forward, size: 28),
              label: const Text(
                'Next Item',
                style: TextStyle(fontSize: 20),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ] else ...[
          // Check and Next button
          ElevatedButton.icon(
            onPressed: checkAndNext,
            icon: const Icon(Icons.check_circle, size: 28),
            label: const Text(
              'Check and Next',
              style: TextStyle(fontSize: 20),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
        
        // Header info at bottom
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Item ${zoomedItemIndex + 1} of ${items.length}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Progress: $progress / $total',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            IconButton(
              onPressed: exitZoomMode,
              icon: const Icon(Icons.close),
              tooltip: 'Exit Zoom Mode',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }
}