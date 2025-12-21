import 'package:flutter/material.dart';
import 'dart:io';
import '../models/checklist_models.dart';
import '../services/storage_service.dart';

class BuildingTemplateIssuesScreen extends StatefulWidget {
  final int buildingNumber;
  final String templateId;
  final VoidCallback onIssuesUpdated;

  const BuildingTemplateIssuesScreen({
    super.key,
    required this.buildingNumber,
    required this.templateId,
    required this.onIssuesUpdated,
  });

  @override
  State<BuildingTemplateIssuesScreen> createState() => _BuildingTemplateIssuesScreenState();
}

class _BuildingTemplateIssuesScreenState extends State<BuildingTemplateIssuesScreen> {
  List<_IssueItem> _issues = [];
  String _templateName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    setState(() => _isLoading = true);

    final templates = await StorageService.loadTemplates();
    _templateName = templates[widget.templateId]?.name ?? widget.templateId;

    final allChecklists = await StorageService.loadAllChecklists();
    
    final buildingStr = widget.buildingNumber.toString();
    final relevantChecklists = allChecklists.where((checklist) =>
      checklist.buildingNumber == buildingStr &&
      checklist.templateId == widget.templateId
    ).toList();

    final List<_IssueItem> issues = [];
    
    for (final checklist in relevantChecklists) {
      for (int i = 0; i < checklist.items.length; i++) {
        final item = checklist.items[i];
        final hasIssueWithDesc = item.hasIssue && 
            item.issueDescription != null && 
            item.issueDescription!.isNotEmpty;
        final hasPhotos = item.photos.isNotEmpty;
        
        if (hasIssueWithDesc || hasPhotos) {
          DateTime? issueDate;
          if (item.timestamp != null) {
            try {
              final parts = item.timestamp!.split(' ');
              if (parts.length >= 2) {
                final dateParts = parts[0].split('/');
                final timeParts = parts[1].split(':');
                if (dateParts.length == 3 && timeParts.length == 3) {
                  issueDate = DateTime(
                    int.parse(dateParts[2]),
                    int.parse(dateParts[0]),
                    int.parse(dateParts[1]),
                    int.parse(timeParts[0]),
                    int.parse(timeParts[1]),
                    int.parse(timeParts[2]),
                  );
                }
              }
            } catch (e) {
              issueDate = DateTime.now();
            }
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

    issues.sort((a, b) => a.issueDate.compareTo(b.issueDate));

    setState(() {
      _issues = issues;
      _isLoading = false;
    });
  }

  Future<void> _verifyIssue(_IssueItem issue) async {
    final now = DateTime.now();
    final timestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    setState(() {
      issue.item.isVerified = true;
      issue.item.isFlagged = false;
      issue.item.verificationTimestamp = timestamp;
    });
    
    await StorageService.saveChecklist(issue.checklist);
    widget.onIssuesUpdated();
  }

  Future<void> _unverifyIssue(_IssueItem issue) async {
    setState(() {
      issue.item.isVerified = false;
      issue.item.verificationTimestamp = null;
    });
    
    await StorageService.saveChecklist(issue.checklist);
    widget.onIssuesUpdated();
  }

  Future<void> _flagIssue(_IssueItem issue) async {
    final now = DateTime.now();
    final timestamp = '${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    setState(() {
      issue.item.isFlagged = true;
      issue.item.isVerified = false;
      issue.item.verificationTimestamp = timestamp;
    });
    
    await StorageService.saveChecklist(issue.checklist);
    widget.onIssuesUpdated();
  }

  Future<void> _unflagIssue(_IssueItem issue) async {
    setState(() {
      issue.item.isFlagged = false;
      issue.item.verificationTimestamp = null;
    });
    
    await StorageService.saveChecklist(issue.checklist);
    widget.onIssuesUpdated();
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    return timestamp;
  }

  Map<String, dynamic> _calculateStats() {
    final total = _issues.length;
    if (total == 0) {
      return {
        'total': 0,
        'verified': 0,
        'flagged': 0,
        'observedCount': 0,
        'observedPercentage': 0.0,
      };
    }
    
    int verifiedCount = 0;
    int flaggedCount = 0;
    int observedCount = 0;
    
    for (final issue in _issues) {
      if (issue.item.isVerified) verifiedCount++;
      if (issue.item.isFlagged) flaggedCount++;
      if (issue.item.isVerified || issue.item.isFlagged) observedCount++;
    }
    
    final observedPercentage = (observedCount / total) * 100;
    
    return {
      'total': total,
      'verified': verifiedCount,
      'flagged': flaggedCount,
      'observedCount': observedCount,
      'observedPercentage': observedPercentage,
    };
  }

  Widget _buildStatsCard() {
    final stats = _calculateStats();
    final percentage = stats['observedPercentage'] as double;
    
    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${percentage.toStringAsFixed(0)}% Observed',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Row(
            children: [
              Icon(Icons.star, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text('${stats['verified']}', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 12),
              Icon(Icons.flag, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
              Text('${stats['flagged']}', style: const TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(_IssueItem issue) {
    final item = issue.item;
    
    final now = DateTime.now();
    final secondsDifference = now.difference(issue.issueDate).inSeconds;
    final isOlderThanWeek = secondsDifference >= 10;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (item.isVerified)
                  const Icon(
                    Icons.star,
                    color: Colors.green,
                    size: 24,
                  )
                else if (item.isFlagged)
                  const Icon(
                    Icons.flag,
                    color: Colors.orange,
                    size: 24,
                  ),
                if (item.isVerified || item.isFlagged) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTimestamp(item.timestamp),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isOlderThanWeek && !item.isVerified && !item.isFlagged)
                        const Text(
                          'older than a week',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  'Unit ${issue.checklist.unitNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Show issue description prominently instead of item name
            if (item.hasIssue && item.issueDescription != null)
              Text(
                item.issueDescription == '(no description)' 
                  ? 'An issue regarding: "${item.text}"'
                  : item.issueDescription!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (item.photos.isNotEmpty && (!item.hasIssue || item.issueDescription == null))
              Text(
                'Photo documentation: "${item.text}"',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            
            // Display subcontractor if assigned
            if (item.subcontractor != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Text(
                  'Tagged with: ${item.subcontractor}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
            
            if (item.photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.photos.length,
                  itemBuilder: (context, photoIndex) {
                    final photoPath = item.photos[photoIndex];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
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
                    );
                  },
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: item.isVerified 
                        ? () => _unverifyIssue(issue)
                        : () => _verifyIssue(issue),
                    icon: Icon(item.isVerified ? Icons.star : Icons.star_outline),
                    label: Text(item.isVerified ? 'Unsolved' : 'Solved'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: item.isFlagged 
                        ? () => _unflagIssue(issue)
                        : () => _flagIssue(issue),
                    icon: Icon(item.isFlagged ? Icons.flag : Icons.flag_outlined),
                    label: Text(item.isFlagged ? 'Unflag' : 'Flag'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Building ${widget.buildingNumber} - $_templateName'),
        backgroundColor: Colors.orange.shade300,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _issues.isEmpty
          ? const Center(child: Text('No issues found'))
          : Column(
              children: [
                _buildStatsCard(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _issues.length,
                    itemBuilder: (context, index) => _buildIssueCard(_issues[index]),
                  ),
                ),
              ],
            ),
    );
  }
}

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
