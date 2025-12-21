import 'package:flutter/material.dart';
import '../models/subcontractor_issue.dart';
import '../utils/tower_utils.dart';

class IssueCard extends StatefulWidget {
  final SubcontractorIssue issue;
  final bool isResolved;
  final VoidCallback onToggle;
  final String Function(String templateId) getTemplateName;
  final VoidCallback? onTap;

  const IssueCard({
    super.key,
    required this.issue,
    required this.isResolved,
    required this.onToggle,
    required this.getTemplateName,
    this.onTap,
  });

  @override
  State<IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<IssueCard> {
  late bool _isChecked;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.issue.originalItem.isChecked;
  }

  void _handleToggle() {
    // Update local state immediately for instant visual feedback
    setState(() {
      _isChecked = !_isChecked;
    });
    
    // Call the parent callback to save the data
    widget.onToggle();
  }

  // Get color for tower based on tower number
  Color _getTowerColor(String unitNumber) {
    final towerNumber = TowerUtils.getTowerNumber(unitNumber);
    switch (towerNumber) {
      case '1':
        return Colors.pink;
      case '2':
        return Colors.brown;
      case '3':
        return Colors.blue;
      default:
        return Colors.blue; // Default fallback
    }
  }

  // Check if issue date is over a week old
  bool _isDateOld(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return false;
    
    try {
      final parts = timestamp.split(' ');
      if (parts.isNotEmpty) {
        final dateParts = parts[0].split('/');
        if (dateParts.length == 3) {
          final issueDate = DateTime(
            int.parse(dateParts[2]), // year
            int.parse(dateParts[0]), // month
            int.parse(dateParts[1]), // day
          );
          final now = DateTime.now();
          final difference = now.difference(issueDate).inDays;
          return difference > 7;
        }
      }
    } catch (e) {
      // If parsing fails, assume not old
    }
    return false;
  }

  String _formatDate(String? timestamp) {
    if (timestamp == null) return '';
    try {
      // Parse timestamp format: M/D/YYYY HH:MM:SS
      final parts = timestamp.split(' ');
      if (parts.isNotEmpty) {
        final datePart = parts[0]; // M/D/YYYY
        final dateComponents = datePart.split('/');
        if (dateComponents.length == 3) {
          final month = dateComponents[0];
          final day = dateComponents[1];
          final year = dateComponents[2];
          // Convert YYYY to YY format
          final shortYear = year.length >= 4 ? year.substring(2) : year;
          return '$month/$day/$shortYear';
        }
        return datePart; // Fallback to original if parsing fails
      }
    } catch (e) {
      // If parsing fails, return empty string
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isResolved ? Colors.purple.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isResolved ? Colors.purple.shade200 : Colors.red.shade200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: _isChecked,
              onChanged: (value) => _handleToggle(),
              activeColor: widget.isResolved ? Colors.purple.shade600 : Colors.green.shade600,
            ),
            if (widget.isResolved || _isChecked) ...[
              _buildResolvedContent(),
            ] else ...[
              _buildUnresolvedContent(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResolvedContent() {
    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getTowerColor(widget.issue.unitNumber).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getTowerColor(widget.issue.unitNumber).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            TowerUtils.formatBuildingTowerUnit(widget.issue.buildingNumber, widget.issue.unitNumber),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getTowerColor(widget.issue.unitNumber).withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        if (widget.issue.originalItem.issueCreationTimestamp != null && 
                            widget.issue.originalItem.issueCreationTimestamp!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _formatDate(widget.issue.originalItem.issueCreationTimestamp),
                              style: TextStyle(
                                fontSize: 9,
                                color: _isDateOld(widget.issue.originalItem.issueCreationTimestamp) 
                                    ? Colors.red.shade700 
                                    : Colors.grey.shade600,
                                fontWeight: _isDateOld(widget.issue.originalItem.issueCreationTimestamp) 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.issue.originalItem.issueDescription?.isNotEmpty == true
                    ? widget.issue.originalItem.issueDescription!
                    : 'Issue: "${widget.issue.originalItem.text}"',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Move subcontractor tag to the right side
          if (widget.issue.originalItem.subcontractor?.isNotEmpty == true)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                widget.issue.originalItem.subcontractor!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          if (widget.issue.copied) ...[
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.content_copy,
                size: 16,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnresolvedContent() {
    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getTowerColor(widget.issue.unitNumber).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getTowerColor(widget.issue.unitNumber).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            TowerUtils.formatBuildingTowerUnit(widget.issue.buildingNumber, widget.issue.unitNumber),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getTowerColor(widget.issue.unitNumber).withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        if (widget.issue.originalItem.issueCreationTimestamp != null && 
                            widget.issue.originalItem.issueCreationTimestamp!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _formatDate(widget.issue.originalItem.issueCreationTimestamp),
                              style: TextStyle(
                                fontSize: 9,
                                color: _isDateOld(widget.issue.originalItem.issueCreationTimestamp) 
                                    ? Colors.red.shade700 
                                    : Colors.grey.shade600,
                                fontWeight: _isDateOld(widget.issue.originalItem.issueCreationTimestamp) 
                                    ? FontWeight.bold 
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.issue.originalItem.issueDescription?.isNotEmpty == true
                    ? widget.issue.originalItem.issueDescription!
                    : 'Issue: "${widget.issue.originalItem.text}"',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Move subcontractor tag to the right side
          if (widget.issue.originalItem.subcontractor?.isNotEmpty == true)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                widget.issue.originalItem.subcontractor!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          if (widget.issue.copied) ...[
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.content_copy,
                size: 16,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}