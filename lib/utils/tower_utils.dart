class TowerUtils {
  /// Extract tower from unit number based on the last two digits
  /// Tower 1: 01-04 (101-104, 201-204, 301-304)
  /// Tower 2: 05-08 (105-108, 205-208, 305-308)  
  /// Tower 3: 09-12 (109-112, 209-212, 309-312)
  static String getTowerNumber(String unitNumber) {
    if (unitNumber.length >= 3) {
      final lastTwoDigits = unitNumber.substring(unitNumber.length - 2);
      final unitNum = int.tryParse(lastTwoDigits) ?? 1;
      
      if (unitNum >= 1 && unitNum <= 4) {
        return '1';
      } else if (unitNum >= 5 && unitNum <= 8) {
        return '2';
      } else if (unitNum >= 9 && unitNum <= 12) {
        return '3';
      }
    }
    return '1'; // Default to tower 1
  }

  /// Format building, tower, and unit into B#T#-unit pattern
  static String formatBuildingTowerUnit(String buildingNumber, String unitNumber) {
    final towerNumber = getTowerNumber(unitNumber);
    return 'B${buildingNumber}T$towerNumber-$unitNumber';
  }
}