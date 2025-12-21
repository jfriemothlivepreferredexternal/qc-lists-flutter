import 'checklist_models.dart';

class SubcontractorIssue {
  final String itemText;
  final String buildingNumber;
  final String unitNumber;
  final String? issueDescription;
  final String templateId;
  final bool isResolved;
  final ChecklistItem originalItem;
  final ChecklistData parentChecklist;

  SubcontractorIssue({
    required this.itemText,
    required this.buildingNumber,
    required this.unitNumber,
    this.issueDescription,
    required this.templateId,
    required this.isResolved,
    required this.originalItem,
    required this.parentChecklist,
  });

  // Convenience getter for copied state
  bool get copied => originalItem.isCopied;
  set copied(bool value) => originalItem.isCopied = value;
}