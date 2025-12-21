import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/checklist_models.dart';

class StorageService {
  // Default QC templates
  static const Map<String, List<String>> _defaultTemplates = {
    'QC1': ['Item One', 'Item Two', 'Item Three'],
    'QC2': ['Item One', 'Item Two', 'Item Three'],
    'QC3.A': ['Item One', 'Item Two', 'Item Three'],
    'QC3.B': ['Item One', 'Item Two', 'Item Three'],
    'QC3.C': ['Item One', 'Item Two', 'Item Three'],
    'QC4.A': ['Item One', 'Item Two', 'Item Three'],
    'QC4.B': ['Item One', 'Item Two', 'Item Three'],
    'QC5.A': ['Item One', 'Item Two', 'Item Three'],
    'QC6': ['Item One', 'Item Two', 'Item Three'],
    'QC6.ALT': ['Item One', 'Item Two', 'Item Three'],
  };

  // Template names mapping
  static const Map<String, String> _templateNames = {
    'QC1': 'QC1 Foundation',
    'QC2': 'QC2 Framing',
    'QC3.A': 'QC3.A Rough Plumbing and Fire Suppression',
    'QC3.B': 'QC3.B Rough HVAC',
    'QC3.C': 'QC3.C Rough electric, low voltage, and fire alarm',
    'QC4.A': 'QC4.A Insulation',
    'QC4.B': 'QC4.B Drywall',
    'QC5.A': 'QC5.A Pre-finish trim and mechanicals',
    'QC6': 'QC6 Final checklist',
    'QC6.ALT': 'QC6 Alternative Final',
  };

  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Template operations
  static Future<Map<String, QCTemplate>> loadTemplates() async {
    try {
      final savedTemplates = await _getSavedTemplates();
      if (savedTemplates.isNotEmpty) {
        final savedTemplateMap = {for (var template in savedTemplates) template.id: template};
        
        // Check if any default templates are missing and add them
        bool updated = false;
        for (var entry in _defaultTemplates.entries) {
          if (!savedTemplateMap.containsKey(entry.key)) {
            savedTemplateMap[entry.key] = QCTemplate(
              id: entry.key,
              name: _templateNames[entry.key]!,
              items: List.from(entry.value),
            );
            updated = true;
          }
        }
        
        // Save if we added any new templates
        if (updated) {
          await saveTemplates(savedTemplateMap);
        }
        
        return savedTemplateMap;
      } else {
        // Initialize with default templates
        final defaultTemplateMap = {
          for (var entry in _defaultTemplates.entries)
            entry.key: QCTemplate(
              id: entry.key,
              name: _templateNames[entry.key]!,
              items: List.from(entry.value),
            )
        };
        await saveTemplates(defaultTemplateMap);
        return defaultTemplateMap;
      }
    } catch (e) {
      // Return default templates if loading fails
      return {
        for (var entry in _defaultTemplates.entries)
          entry.key: QCTemplate(
            id: entry.key,
            name: _templateNames[entry.key]!,
            items: List.from(entry.value),
          )
      };
    }
  }

  static Future<List<QCTemplate>> _getSavedTemplates() async {
    try {
      final path = await _localPath;
      final file = File('$path/templates.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList.map((json) => QCTemplate.fromJson(json)).toList();
      }
    } catch (e) {
      // Return empty list if error occurs
    }
    return [];
  }

  static Future<void> saveTemplates(Map<String, QCTemplate> templates) async {
    final path = await _localPath;
    final file = File('$path/templates.json');
    final templatesJson = templates.values.map((t) => t.toJson()).toList();
    await file.writeAsString(jsonEncode(templatesJson));
  }

  // Checklist operations
  static Future<void> saveChecklist(ChecklistData checklist) async {
    final path = await _localPath;
    final filename = '${checklist.buildingNumber}_${checklist.unitNumber}.json';
    final file = File('$path/$filename');
    await file.writeAsString(jsonEncode(checklist.toJson()));
  }

  static Future<List<ChecklistData>> getSavedChecklists() async {
    final path = await _localPath;
    final directory = Directory(path);
    
    if (!await directory.exists()) return [];
    
    final files = await directory.list()
        .where((entity) => entity is File && entity.path.endsWith('.json') && !entity.path.contains('templates.json'))
        .cast<File>()
        .toList();
    
    List<ChecklistData> checklists = [];
    
    for (File file in files) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        checklists.add(ChecklistData.fromJson(json));
      } catch (e) {
        // Skip corrupted files
        continue;
      }
    }
    
    return checklists;
  }

  static Future<void> deleteChecklist(ChecklistData checklist) async {
    final path = await _localPath;
    final filename = '${checklist.buildingNumber}_${checklist.unitNumber}.json';
    final file = File('$path/$filename');
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<bool> checklistExists({
    required String templateId,
    required String buildingNumber,
    required String unitNumber,
  }) async {
    final savedChecklists = await getSavedChecklists();
    
    return savedChecklists.any((checklist) => 
      checklist.templateId == templateId &&
      checklist.buildingNumber == buildingNumber &&
      checklist.unitNumber == unitNumber
    );
  }

  // Alias for getSavedChecklists for clarity in issues dashboard
  static Future<List<ChecklistData>> loadAllChecklists() async {
    return getSavedChecklists();
  }

  // Recent subcontractor selections
  static Future<List<String>> getRecentSubcontractors() async {
    try {
      final path = await _localPath;
      final file = File('$path/recent_subcontractors.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        return jsonList.cast<String>();
      }
    } catch (e) {
      print('Error loading recent subcontractors: $e');
    }
    return [];
  }

  static Future<void> addRecentSubcontractor(String subcontractor) async {
    try {
      final recentSubs = await getRecentSubcontractors();
      
      // Remove if already exists to avoid duplicates
      recentSubs.remove(subcontractor);
      
      // Add to front
      recentSubs.insert(0, subcontractor);
      
      // Keep only 5 most recent
      if (recentSubs.length > 5) {
        recentSubs.removeRange(5, recentSubs.length);
      }
      
      final path = await _localPath;
      final file = File('$path/recent_subcontractors.json');
      await file.writeAsString(json.encode(recentSubs));
    } catch (e) {
      print('Error saving recent subcontractor: $e');
    }
  }
}