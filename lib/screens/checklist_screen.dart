import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
// import '../main.dart';
import '../models/checklist_models.dart';
import '../services/storage_service.dart';
import '../services/property_filter.dart';

// import '../services/encryption_service.dart';
import '../widgets/zoom_mode_view.dart';
import '../widgets/signature_dialog.dart';
import '../widgets/app_menu.dart';
import 'saved_checklists_screen.dart';
import 'building_selection_screen.dart';
import 'template_filter_selection_screen.dart';

class ChecklistScreen extends StatefulWidget {
  final ChecklistData checklistData;
  final int? initialItemIndex;
  final String? previousScreen; // Track where we came from
  final Map<String, dynamic>? previousScreenData; // Data needed to recreate previous screen

  const ChecklistScreen({
    super.key, 
    required this.checklistData,
    this.initialItemIndex,
    this.previousScreen,
    this.previousScreenData,
  });

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  late ChecklistData _checklistData;
  QCTemplate? _template;
  bool _isZoomMode = false;
  int _zoomedItemIndex = 0;
  int? _highlightedItemIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checklistData = widget.checklistData;
    _zoomedItemIndex = widget.initialItemIndex ?? 0;
    
    // Debug - this should show in console
    print('DEBUG: ChecklistScreen - property = ${_checklistData.property}');
    print('DEBUG: ChecklistScreen - PropertyFilter.selectedProperty = ${PropertyFilter.selectedProperty}');
    
    _loadTemplate();
    _saveChecklist(); // Save initially when checklist is created
    
    // If we have an initial item index, scroll to it after the frame is built
    if (widget.initialItemIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToItem(_zoomedItemIndex);
      });
    }
  }

  Future<void> _loadTemplate() async {
    final templates = await StorageService.loadTemplates();
    final template = templates[_checklistData.templateId];
    
    if (template == null) {
      // Template not found - this checklist uses an old/invalid template ID
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${_checklistData.templateId}" no longer exists. This checklist cannot be opened.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    setState(() {
      _template = template;
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _scrollController.dispose();
    _highlightedItemIndex = null; // Clear highlight when leaving screen
    super.dispose();
  }

  void _toggleChecklistItem(int index) async {
    final item = _checklistData.items[index];
    
    // If trying to check an item that has an issue, ask if issue is fixed
    if (!item.isChecked && item.hasIssue) {
      final isFixed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Issue Found'),
            content: Text('This item has an issue${item.subcontractor != null ? ' (Tagged with: ${item.subcontractor})' : ''}.\n\nIs the issue fixed?'),
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
      
      if (isFixed != true) {
        // Show red toast if issue is not fixed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item cannot be checked off until issue is resolved'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return; // Don't check the item
      }
    }
    
    setState(() {
      item.isChecked = !item.isChecked;
      
      // Add timestamp when checking, remove when unchecking
      if (item.isChecked) {
        final now = DateTime.now();
        item.timestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      } else {
        item.timestamp = null;
      }
    });
    // Debounce saves to improve performance
    _debouncedSave();
  }

  Timer? _saveTimer;
  void _debouncedSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveChecklist();
    });
  }

  Future<void> _saveChecklist() async {
    await StorageService.saveChecklist(_checklistData);
  }

  Future<void> _duplicateLastItemAndZoom() async {
    if (_checklistData.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items to duplicate'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    final lastIndex = _checklistData.items.length - 1;
    final lastItem = _checklistData.items[lastIndex];
    
    // Count existing duplicates to determine the next number
    int duplicateCount = 0;
    final baseText = lastItem.text.replaceAll(RegExp(r' \(duplicate #\d+\)$'), '');
    
    for (final existingItem in _checklistData.items) {
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
          title: const Text('Duplicate Last Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to duplicate the last item?'),
              const SizedBox(height: 8),
              Text(
                'Last item: "$baseText"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'New item will be: "$baseText (duplicate #${duplicateCount + 1})"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
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
      // Add duplicate to the end of the list
      _checklistData.items.add(duplicateItem);
    });
    
    _debouncedSave();
    
    // Enter zoom mode on the new duplicate item
    final newItemIndex = _checklistData.items.length - 1;
    _enterZoomMode(newItemIndex);
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item duplicated as "${duplicateItem.text}" and zoomed in'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _emailReport() async {
    // Show signature screen in landscape fullscreen
    final signatureBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => const SignatureDialog(),
        fullscreenDialog: true,
      ),
    );
    
    // If user cancelled signature, don't proceed
    if (signatureBytes == null) {
      return;
    }
    
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    // Calculate progress
    final completedCount = _checklistData.items.where((item) => item.isChecked).length;
    final totalCount = _checklistData.items.length;
    final progressPercent = ((completedCount / totalCount) * 100).round();
    
    // Collect items with issues or photos for separate section
    final issueItems = _checklistData.items.asMap().entries.where((entry) {
      final item = entry.value;
      return (item.hasIssue && item.issueDescription != null && item.issueDescription!.isNotEmpty) || 
             item.photos.isNotEmpty;
    }).map((entry) {
      final item = entry.value;
      final description = item.hasIssue && item.issueDescription != null && item.issueDescription!.isNotEmpty
          ? (item.issueDescription == '(no description)' 
              ? 'An issue regarding: "${item.text}"' 
              : item.issueDescription!)
          : 'An issue regarding: "${item.text}"';
      final photoCount = item.photos.isNotEmpty ? ' [${item.photos.length} photo${item.photos.length > 1 ? 's' : ''}]' : '';
      final subcontractorInfo = item.subcontractor != null ? ' (Tagged: ${item.subcontractor})' : '';
      return 'B${_checklistData.buildingNumber} ${_checklistData.unitNumber} - $description$photoCount$subcontractorInfo';
    }).toList();
    
    final issuesSection = issueItems.isNotEmpty 
        ? '\nISSUES FOUND:\n\n${issueItems.join('\n')}\n\n' 
        : '';
    
    // Create checklist data for encryption
    final checklistText = '''Template: ${_template!.name}
Building: ${_checklistData.buildingNumber}
Unit: ${_checklistData.unitNumber}
Date: $dateStr
Progress: $completedCount/$totalCount items completed ($progressPercent%)
$issuesSection
Items Status:
${_checklistData.items.asMap().entries.map((entry) {
  final item = entry.value;
  final itemNum = entry.key + 1;
  final status = item.isChecked ? "✓" : "○";
  final timeStamp = item.isChecked && item.timestamp != null ? " [${item.timestamp}]" : "";
  final issueDesc = item.hasIssue && item.issueDescription != null && item.issueDescription!.isNotEmpty 
      ? "\n   ⚠️ Issue: ${item.issueDescription}" : "";
  final photoCount = item.photos.isNotEmpty ? "\n   📷 ${item.photos.length} photo${item.photos.length > 1 ? 's' : ''}" : "";
  final subcontractorInfo = item.subcontractor != null ? "\n   👷 Tagged with: ${item.subcontractor}" : "";
  return '$itemNum. $status ${item.text}$timeStamp$issueDesc$photoCount$subcontractorInfo';
}).join('\n')}''';
    
    try {
      // Encrypt the checklist data using configured password
      // final encryptedData = await Emn178Encryption.encrypt(checklistText, AppConfig.encryptionPassword);
      
      // Create email subject with template, progress, and property
      final emailSubject = 'QC ${_template!.id} - ${progressPercent}% Complete - B${_checklistData.buildingNumber}U${_checklistData.unitNumber} - ${_checklistData.property ?? 'Unknown'}';
      
      // Use raw checklist data in email body (encryption disabled)
      final emailBody = '''$checklistText

Generated by QC Lists App - ${DateTime.now()}
''';

      // ENCRYPTION DISABLED - Previously encrypted email body:
      /*
      final emailBody = '''QC Checklist Report (Encrypted)

To decrypt this report:
1. Contact your administrator for the decryption passphrase
2. Go to https://emn178.github.io/online-tools/aes/decrypt
3. Enter the passphrase under "Passphrase"
4. Copy the encrypted data below and paste it into "Input" on the website
5. Click the toggle switch next to "Custom Iteration"
6. Change the iterations value from 1 to 1000
 
-The decrypted text should already be under "Output". If not, hit "Decrypt" button.
-If there are any errors, ensure the following defaults are selected: text, hex, utf-8, 256 bits, cbc, pkcs7, pbkdf2, and sha256.

Encrypted Data:
$encryptedData

Generated by QC Lists App - ${DateTime.now()}
''';
      */

      // Save signature as temporary file
      final tempDir = await getTemporaryDirectory();
      final signatureFile = File('${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
      await signatureFile.writeAsBytes(signatureBytes);

      // Collect all photo paths from items with issues or photos
      final List<String> attachmentPaths = [signatureFile.path];
      for (final item in _checklistData.items) {
        if ((item.hasIssue && item.issueDescription != null && item.issueDescription!.isNotEmpty) || 
            item.photos.isNotEmpty) {
          for (final photoPath in item.photos) {
            attachmentPaths.add(photoPath);
          }
        }
      }

      // Use flutter_email_sender with pre-filled recipient and attachments
      final Email email = Email(
        body: emailBody,
        subject: emailSubject,
        recipients: ['jfriemothlivepreferredexternal@gmail.com'],
        attachmentPaths: attachmentPaths,
        isHTML: false,
      );
      
      try {
        await FlutterEmailSender.send(email);
      } catch (error) {
        // Fallback to share with attachments if email sender fails
        final List<XFile> xFileAttachments = attachmentPaths.map((path) => XFile(path)).toList();
        await Share.shareXFiles(
          xFileAttachments,
          text: 'Please send to: jfriemothlivepreferredexternal@gmail.com\n\n$emailBody',
          subject: emailSubject,
        );
      }
      
      // Ask user if email was sent successfully
      if (mounted) {
        final emailSent = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Email Status'),
            content: const Text('Was the email sent successfully?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        
        if (emailSent == true) {
          setState(() {
            _checklistData.emailSent = true;
          });
          _saveChecklist(); // Save the updated email status
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email marked as sent successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing report: $e')),
        );
      }
    }
  }

  void _enterZoomMode(int index) {
    setState(() {
      _isZoomMode = true;
      _zoomedItemIndex = index;
    });
  }

  void _exitZoomMode() {
    setState(() {
      _isZoomMode = false;
    });
    
    // Scroll to the item that was being viewed in zoom mode
    _scrollToItem(_zoomedItemIndex);
  }

  void _scrollToItem(int itemIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Calculate approximate position of the item
        // Assuming each Card item is approximately 72 pixels tall (standard ListTile height + margin)
        final double itemHeight = 80.0;
        final double targetPosition = itemIndex * itemHeight;
        
        // Clamp the position to valid scroll range
        final double maxScroll = _scrollController.position.maxScrollExtent;
        final double clampedPosition = targetPosition.clamp(0.0, maxScroll);
        
        _scrollController.animateTo(
          clampedPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ).then((_) {
          // Trigger highlight animation after scroll completes
          _highlightItem(itemIndex);
        });
      }
    });
  }

  void _highlightItem(int itemIndex) {
    if (mounted) {
      // Highlight the item and keep it highlighted until screen exit
      setState(() {
        _highlightedItemIndex = itemIndex;
      });
    }
  }

  void _checkAndNext() async {
    final item = _checklistData.items[_zoomedItemIndex];
    
    // If item has an issue, ask if it's fixed
    if (item.hasIssue) {
      final isFixed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Issue Found'),
            content: Text('This item has an issue${item.subcontractor != null ? ' (Tagged with: ${item.subcontractor})' : ''}.\n\nIs the issue fixed?'),
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
      
      if (isFixed != true) {
        // Show red toast if issue is not fixed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Item cannot be checked off until issue is resolved'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return; // Don't check the item
      }
    }
    
    // Check the current item and add timestamp
    setState(() {
      item.isChecked = true;
      final now = DateTime.now();
      item.timestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    });
    
    // Force immediate save before moving to next item
    await _saveChecklist();

    // Find next unchecked item (search forward only)
    int nextIndex = -1;
    
    // Search from current position + 1 to end
    for (int i = _zoomedItemIndex + 1; i < _checklistData.items.length; i++) {
      if (!_checklistData.items[i].isChecked) {
        nextIndex = i;
        break;
      }
    }

    if (nextIndex != -1) {
      // Move to next unchecked item
      setState(() {
        _zoomedItemIndex = nextIndex;
      });
    } else {
      // No more unchecked items ahead, exit zoom mode
      _exitZoomMode();
      // Show completion message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No more items ahead - returning to list view'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _goToNextItem() {
    // Move to next item (regardless of checked status)
    if (_zoomedItemIndex < _checklistData.items.length - 1) {
      setState(() {
        _zoomedItemIndex++;
      });
    } else {
      // On last item, exit zoom mode
      _exitZoomMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reached end of list - returning to list view'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _goToPreviousItem() {
    // Move to previous item
    if (_zoomedItemIndex > 0) {
      setState(() {
        _zoomedItemIndex--;
      });
    }
  }

  Future<void> _deleteChecklist() async {
    final TextEditingController passwordController = TextEditingController();
    
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Checklist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter password to delete the checklist:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value == 'delete') {
                  Navigator.of(context).pop(true);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (passwordController.text == 'delete') {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect password')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    passwordController.dispose();

    if (shouldDelete == true) {
      await StorageService.deleteChecklist(_checklistData);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildZoomModeView() {
    return ZoomModeView(
      items: _checklistData.items,
      zoomedItemIndex: _zoomedItemIndex,
      exitZoomMode: _exitZoomMode,
      debouncedSave: _debouncedSave,
      checkAndNext: _checkAndNext,
      goToNextItem: _goToNextItem,
      goToPreviousItem: _goToPreviousItem,
      setState: setState,
      buildingNumber: _checklistData.buildingNumber,
      unitNumber: _checklistData.unitNumber,
      templateName: _template?.name ?? '',
    );
  }

  Widget _buildNormalView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action buttons row
        Row(
          children: [
            // View Saved Checklists button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Load and sort checklists (same as home screen)
                  final allChecklists = await StorageService.getSavedChecklists();
                  final templates = await StorageService.loadTemplates();
                  
                  // Filter checklists to only include those with valid templates
                  final validChecklists = allChecklists.where((checklist) => 
                    templates.containsKey(checklist.templateId)
                  ).toList();
                  
                  // Sort by most recent activity (same logic as home screen)
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChecklistScreen(checklistData: checklist),
                      ),
                    );
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

                  // Open SavedChecklistsScreen with filters
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SavedChecklistsScreen(
                        initialBuildingFilter: selectedBuilding,
                        initialQCFilter: selectedTemplate,
                        highlightChecklistId: '${_checklistData.templateId}_${_checklistData.buildingNumber}_${_checklistData.unitNumber}',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: const Text('Saved Lists'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Email Report button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _emailReport,
                icon: const Icon(Icons.email),
                label: const Text('Email Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // New Item Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _duplicateLastItemAndZoom,
                icon: const Icon(Icons.add),
                label: const Text('New Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade100,
                  foregroundColor: Colors.purple.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        Text(
          _template?.name ?? 'Loading...',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Building: ${_checklistData.buildingNumber}, Unit: ${_checklistData.unitNumber}',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        const Text(
          'Checklist:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _checklistData.items.isEmpty
              ? const Center(child: Text('No items in checklist'))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _checklistData.items.length,
                  cacheExtent: 200.0, // Cache more items for smoother scrolling
                  itemBuilder: (context, index) {
                    final item = _checklistData.items[index];
                    final isHighlighted = _highlightedItemIndex == index;
                    
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
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
                          leading: Checkbox(
                            value: item.isChecked,
                            onChanged: (_) => _toggleChecklistItem(index),
                          ),
                          title: Text(
                            item.text,
                            style: TextStyle(
                              decoration: item.isChecked
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          subtitle: item.isChecked && item.timestamp != null
                              ? Text(
                                  'Checked at ${item.timestamp}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.photos.isNotEmpty)
                                const Icon(
                                  Icons.camera_alt,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              if (item.photos.isNotEmpty) const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _enterZoomMode(index),
                                icon: Icon(
                                  Icons.zoom_in,
                                  size: 20,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: item.hasIssue ? Colors.red.shade100 : Colors.grey.shade300,
                                  foregroundColor: item.hasIssue ? Colors.red.shade700 : Colors.grey.shade800,
                                ),
                                tooltip: 'Zoom Mode',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        // Handle zoom mode first
        if (_isZoomMode) {
          _exitZoomMode();
          return;
        }
        
        // Navigate back to the appropriate screen based on context
        if (widget.previousScreen == 'saved_checklists') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SavedChecklistsScreen(
                initialBuildingFilter: widget.previousScreenData?['buildingFilter'],
                initialQCFilter: widget.previousScreenData?['qcFilter'],
                highlightChecklistId: widget.previousScreenData?['highlightId'],
              ),
            ),
          );
        } else if (widget.previousScreen == 'building_selection') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BuildingSelectionScreen(
                onBuildingSelected: (buildingNumber) async {
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
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChecklistScreen(
                        checklistData: selectedChecklist,
                        previousScreen: 'building_selection',
                        previousScreenData: {
                          'recentChecklists': widget.previousScreenData?['recentChecklists'] ?? [],
                          'highlightId': '${selectedChecklist.templateId}_${selectedChecklist.buildingNumber}_${selectedChecklist.unitNumber}',
                        },
                      ),
                    ),
                  );
                },
                recentChecklists: widget.previousScreenData?['recentChecklists'] ?? [],
                highlightChecklistId: widget.previousScreenData?['highlightId'],
              ),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(_isZoomMode ? 'Zoom Mode' : 'QC Lists'),
          actions: [
            if (!_isZoomMode)
              IconButton(
                onPressed: _deleteChecklist,
                icon: const Icon(Icons.delete),
                tooltip: 'Delete Checklist',
              ),
            IconButton(
              onPressed: () => AppMenu.show(
                context,
                onTemplateEdited: () {
                  // Reload template if edited
                  StorageService.loadTemplates().then((templates) {
                    final updatedTemplate = templates[_checklistData.templateId];
                    if (updatedTemplate != null) {
                      setState(() {
                        _template = updatedTemplate;
                      });
                    }
                  });
                },
              ),
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Property display
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                color: Colors.blue.shade100,
                child: Text(
                  '${_checklistData.property ?? 'Unknown'}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: _isZoomMode ? _buildZoomModeView() : _buildNormalView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}