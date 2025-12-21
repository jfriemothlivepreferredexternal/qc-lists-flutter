import 'package:flutter/material.dart';
import '../models/subcontractor_issue.dart';
import '../models/checklist_models.dart';
import '../utils/tower_utils.dart';
import '../services/storage_service.dart';
import 'checklist_screen.dart';

class IssueDetailScreen extends StatefulWidget {
  final SubcontractorIssue issue;
  final String Function(String templateId) getTemplateName;

  const IssueDetailScreen({
    super.key,
    required this.issue,
    required this.getTemplateName,
  });

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  late ChecklistItem item;
  late TextEditingController _issueDescriptionController;
  bool _isEditing = true;  // Start in editing mode since edit button is now inline
  bool _isSaving = false;
  String? _originalDescription;

  @override
  void initState() {
    super.initState();
    item = widget.issue.originalItem;
    _originalDescription = item.issueDescription;
    _issueDescriptionController = TextEditingController(
      text: item.issueDescription ?? '',
    );
  }

  @override
  void dispose() {
    _issueDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final newDescription = _issueDescriptionController.text.trim();
    bool hasChanges = newDescription != (_originalDescription ?? '');
    
    if (!hasChanges) {
      // No changes made, just show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes to save'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show creation date info popup if changes exist and timestamp exists
    // This will handle the save confirmation
    bool shouldSave = true;
    if (hasChanges && (item.issueCreationTimestamp != null || newDescription.isNotEmpty)) {
      shouldSave = await _showCreationDateInfoConfirmation();
    }

    if (!shouldSave) {
      // User cancelled the save, revert changes
      setState(() {
        _issueDescriptionController.text = _originalDescription ?? '';
      });
      return; // User cancelled the save
    }

    await _performSave(newDescription);
  }

  Future<bool> _showCreationDateInfoConfirmation() async {
    final confirmed = await showDialog<bool>(
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
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '• Editing the description does not change the original creation date',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '• This helps track how long issues have been outstanding',
                style: TextStyle(fontSize: 14),
              ),
              if (item.issueCreationTimestamp != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This issue was created:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(item.issueCreationTimestamp!),
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Got it - Save Changes'),
            ),
          ],
        );
      },
    );
    
    return confirmed ?? false;
  }

  Future<void> _performSave(String newDescription) async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Update the item description (keep existing subcontractor)
      if (newDescription.isEmpty) {
        // Remove issue if description is empty
        item.hasIssue = false;
        item.issueDescription = null;
        // Keep subcontractor assignment if it exists
      } else {
        // Update issue description
        item.hasIssue = true;
        item.issueDescription = newDescription;
        
        // Set creation timestamp if this is a new issue
        if (item.issueCreationTimestamp == null) {
          final now = DateTime.now();
          item.issueCreationTimestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        }
      }

      // Save the entire checklist
      await StorageService.saveChecklist(widget.issue.parentChecklist);
      
      // Update original description for future comparisons
      _originalDescription = item.issueDescription;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue description updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      DateTime date;
      
      // Try to parse as ISO format first (from DateTime.now().toString())
      try {
        date = DateTime.parse(timestamp);
      } catch (e) {
        // If ISO parsing fails, try custom format: M/D/YYYY HH:MM:SS
        final parts = timestamp.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split('/');
          final timeParts = parts[1].split(':');
          
          if (dateParts.length == 3 && timeParts.length == 3) {
            final month = int.parse(dateParts[0]);
            final day = int.parse(dateParts[1]);
            final year = int.parse(dateParts[2]);
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            final second = int.parse(timeParts[2]);
            
            date = DateTime(year, month, day, hour, minute, second);
          } else {
            throw FormatException('Invalid custom date format');
          }
        } else {
          throw FormatException('Invalid date format');
        }
      }
      
      // Format as "Nov 14, 2025 at 2:30 PM"
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      
      final month = months[date.month - 1];
      final day = date.day;
      final year = date.year;
      
      final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      
      return '$month $day, $year at $hour:$minute $amPm';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _undoChanges() {
    setState(() {
      _issueDescriptionController.text = _originalDescription ?? '';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Changes reverted to original'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _cancelEditing() {
    setState(() {
      _issueDescriptionController.text = item.issueDescription ?? '';
      _isEditing = false;
    });
  }

  bool _hasUnsavedChanges() {
    final currentText = _issueDescriptionController.text.trim();
    return currentText != (_originalDescription ?? '');
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges()) {
      return true; // No changes, allow back navigation
    }

    // Show confirmation dialog for unsaved changes
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('You have unsaved changes. What would you like to do?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave Without Saving'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(false); // Close dialog
                await _saveChanges(); // This will show the creation date confirmation
                // Don't automatically leave after save - let user navigate manually
              },
              child: const Text('Save First'),
            ),
          ],
        );
      },
    );

    return shouldLeave ?? false;
  }

  void _navigateToChecklist() {
    // Find the index of this item in the checklist for scrolling
    final itemIndex = widget.issue.parentChecklist.items.indexWhere(
      (checklistItem) => checklistItem.text == item.text,
    );
    
    // Navigate to the checklist screen where this item belongs
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ChecklistScreen(
          checklistData: widget.issue.parentChecklist,
          initialItemIndex: itemIndex >= 0 ? itemIndex : 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Issue Detail'),
          backgroundColor: Colors.blue.shade100,
          foregroundColor: Colors.blue.shade800,
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location info - tappable button
            OutlinedButton(
              onPressed: _navigateToChecklist,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to view in checklist',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade600,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.launch,
                        size: 14,
                        color: Colors.blue.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          TowerUtils.formatBuildingTowerUnit(widget.issue.buildingNumber, widget.issue.unitNumber),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.getTemplateName(widget.issue.templateId),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Checklist item
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checklist Item',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.text,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Issue description - editable
            Card(
              color: _isEditing ? Colors.amber.shade50 : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Issue Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'EDITING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isEditing) ...[
                      TextField(
                        controller: _issueDescriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Describe the issue...',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: false,
                      ),
                    ] else ...[
                      Text(
                        item.issueDescription?.isNotEmpty == true 
                          ? item.issueDescription!
                          : 'No issue description',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: item.issueDescription?.isNotEmpty == true 
                            ? FontStyle.normal 
                            : FontStyle.italic,
                          color: item.issueDescription?.isNotEmpty == true 
                            ? Colors.black87
                            : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action buttons - only show when editing
            if (_isEditing) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelEditing,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _undoChanges,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade600,
                        side: BorderSide(color: Colors.orange.shade600),
                      ),
                      child: const Text('Undo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      child: _isSaving 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Subcontractor assignment - read only
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Assigned Subcontractor',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Read Only',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: item.subcontractor != null 
                          ? Colors.blue.shade50
                          : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: item.subcontractor != null 
                            ? Colors.blue.shade200
                            : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        item.subcontractor ?? 'No subcontractor assigned',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: item.subcontractor != null 
                            ? FontWeight.w500
                            : FontWeight.normal,
                          color: item.subcontractor != null 
                            ? Colors.blue.shade700
                            : Colors.grey.shade600,
                          fontStyle: item.subcontractor != null 
                            ? FontStyle.normal 
                            : FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ), // Close PopScope child (Scaffold)
    ); // Close PopScope
  }
}
