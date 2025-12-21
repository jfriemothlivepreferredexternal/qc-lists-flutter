class ChecklistItem {
  String text;
  bool isChecked;
  String? timestamp; // Time when item was interacted with (format: M/D/YYYY HH:MM:SS)
  bool hasIssue; // Flag for items that have issues
  String? issueDescription; // Description of the issue
  String? subcontractor; // Subcontractor responsible for the issue
  bool isVerified; // Supervisor verified the issue is fixed
  bool isFlagged; // Supervisor flagged as requiring attention
  String? verificationTimestamp; // When supervisor took action (format: M/D/YYYY HH:MM:SS)
  List<String> photos; // List of photo file paths
  bool isCopied; // Track if this issue has been copied to clipboard
  String? issueCreationTimestamp; // When the issue was first created (format: M/D/YYYY HH:MM:SS)

  ChecklistItem({
    required this.text, 
    this.isChecked = false, 
    this.timestamp,
    bool? hasIssue,
    this.issueDescription,
    this.subcontractor,
    bool? isVerified,
    bool? isFlagged,
    this.verificationTimestamp,
    List<String>? photos,
    bool? isCopied,
    this.issueCreationTimestamp,
  }) : hasIssue = hasIssue ?? false,
       isVerified = isVerified ?? false,
       isFlagged = isFlagged ?? false,
       photos = photos ?? [],
       isCopied = isCopied ?? false;

  Map<String, dynamic> toJson() => {
    'text': text,
    'isChecked': isChecked,
    'timestamp': timestamp,
    'checkedTime': timestamp, // Keep for backward compatibility
    'hasIssue': hasIssue,
    'issueDescription': issueDescription,
    'subcontractor': subcontractor,
    'isVerified': isVerified,
    'isFlagged': isFlagged,
    'verificationTimestamp': verificationTimestamp,
    'photos': photos,
    'isCopied': isCopied,
    'issueCreationTimestamp': issueCreationTimestamp,
  };

  static ChecklistItem fromJson(Map<String, dynamic> json) => ChecklistItem(
    text: json['text'],
    isChecked: json['isChecked'],
    timestamp: json['timestamp'] ?? json['checkedTime'], // Support both old and new
    hasIssue: json['hasIssue'],
    issueDescription: json['issueDescription'],
    subcontractor: json['subcontractor'],
    isVerified: json['isVerified'],
    isFlagged: json['isFlagged'],
    verificationTimestamp: json['verificationTimestamp'],
    photos: json['photos'] != null ? List<String>.from(json['photos']) : [],
    isCopied: json['isCopied'] ?? false,
    issueCreationTimestamp: json['issueCreationTimestamp'],
  );
}

class QCTemplate {
  String id;
  String name;
  List<String> items;

  QCTemplate({
    required this.id,
    required this.name,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items,
  };

  static QCTemplate fromJson(Map<String, dynamic> json) => QCTemplate(
    id: json['id'],
    name: json['name'],
    items: List<String>.from(json['items']),
  );
}

class ChecklistData {
  String templateId;
  String buildingNumber;
  String unitNumber;
  List<ChecklistItem> items;
  bool emailSent;
  String? property; // Nullable so existing checklists stay null

  ChecklistData({
    required this.templateId,
    required this.buildingNumber,
    required this.unitNumber,
    required this.items,
    this.emailSent = false,
    this.property = 'Alamira', // Default for new checklists
  });

  Map<String, dynamic> toJson() => {
    'templateId': templateId,
    'buildingNumber': buildingNumber,
    'unitNumber': unitNumber,
    'items': items.map((item) => item.toJson()).toList(),
    'emailSent': emailSent,
    'property': property,
  };

  static ChecklistData fromJson(Map<String, dynamic> json) => ChecklistData(
    templateId: json['templateId'],
    buildingNumber: json['buildingNumber'],
    unitNumber: json['unitNumber'],
    items: (json['items'] as List).map((item) => ChecklistItem.fromJson(item)).toList(),
    emailSent: json['emailSent'] ?? false,
    property: json['property'], // Keep existing null values as null
  );
}