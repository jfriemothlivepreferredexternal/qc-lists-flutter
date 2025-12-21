import 'package:shared_preferences/shared_preferences.dart';

class PropertyFilter {
  static String? _selectedProperty = 'HIDE_ALL'; // Default to hide all
  
  static String? get selectedProperty => _selectedProperty;
  
  static void setProperty(String? property) {
    _selectedProperty = property;
    _saveProperty(property);
  }
  
  // Save selected property to local storage
  static Future<void> _saveProperty(String? property) async {
    final prefs = await SharedPreferences.getInstance();
    if (property == null || property == 'HIDE_ALL') {
      await prefs.remove('selected_property');
    } else {
      await prefs.setString('selected_property', property);
    }
  }
  
  // Load saved property from local storage
  static Future<void> loadProperty() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedProperty = prefs.getString('selected_property') ?? 'HIDE_ALL';
  }
  
  // Check if we should show the daily property popup
  static Future<bool> shouldShowDailyPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString('last_property_popup');
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    
    return lastShown != today;
  }
  
  // Mark that we've shown the popup today
  static Future<void> markPopupShown() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    await prefs.setString('last_property_popup', today);
  }
  
  static List<String> getAvailableProperties() {
    final properties = [
      'Alamira',
      'Alamira (Annex)',
      'Dorset',
      'Maison',
      'Wilshire (Annex 980)',
      'Wilshire 919',
    ];
    properties.sort(); // Sort alphabetically
    return properties;
  }
  
  static bool matchesFilter(String? checklistProperty) {
    if (_selectedProperty == 'HIDE_ALL') return false; // Hide all when HIDE_ALL selected
    if (_selectedProperty == null) return true; // Show all when no filter
    return checklistProperty == _selectedProperty;
  }
}