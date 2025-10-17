import 'package:shared_preferences/shared_preferences.dart';
import '../models/plant_data.dart';

class PlantSettingsService {
  static const String _selectedPlantIdKey = 'selected_plant_id';
  static const String _selectedPlantNameKey = 'selected_plant_name';
  static const String _selectedPlantPpmMinKey = 'selected_plant_ppm_min';
  static const String _selectedPlantPpmMaxKey = 'selected_plant_ppm_max';
  static const String _customTargetTdsKey = 'custom_target_tds';
  static const String _customTdsThresholdKey = 'custom_tds_threshold';

  // Get selected plant information
  static Future<PlantData?> getSelectedPlant() async {
    final prefs = await SharedPreferences.getInstance();
    final plantId = prefs.getInt(_selectedPlantIdKey);
    
    if (plantId != null) {
      return PlantDatabase.getPlantById(plantId);
    }
    return null;
  }

  // Set selected plant
  static Future<void> setSelectedPlant(PlantData plant) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedPlantIdKey, plant.id);
    await prefs.setString(_selectedPlantNameKey, plant.namaIndonesia);
    await prefs.setInt(_selectedPlantPpmMinKey, plant.ppmMin);
    await prefs.setInt(_selectedPlantPpmMaxKey, plant.ppmMax);
    
    // Calculate and set optimal target TDS based on plant data
    final optimalTds = ((plant.ppmMin + plant.ppmMax) / 2).round();
    await prefs.setInt(_customTargetTdsKey, optimalTds);
    
    // Set threshold as 10% of the range, minimum 50
    final range = plant.ppmMax - plant.ppmMin;
    final threshold = (range * 0.1).round().clamp(50, 200);
    await prefs.setInt(_customTdsThresholdKey, threshold);
  }

  // Get target TDS based on selected plant or custom setting
  static Future<int> getTargetTds() async {
    final prefs = await SharedPreferences.getInstance();
    
    // First check if there's a custom target TDS
    final customTds = prefs.getInt(_customTargetTdsKey);
    if (customTds != null) {
      return customTds;
    }
    
    // If no custom TDS, calculate from selected plant
    final selectedPlant = await getSelectedPlant();
    if (selectedPlant != null) {
      return ((selectedPlant.ppmMin + selectedPlant.ppmMax) / 2).round();
    }
    
    // Default value if no plant selected
    return 1000;
  }

  // Get TDS threshold based on selected plant or custom setting
  static Future<int> getTdsThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    
    // First check if there's a custom threshold
    final customThreshold = prefs.getInt(_customTdsThresholdKey);
    if (customThreshold != null) {
      return customThreshold;
    }
    
    // If no custom threshold, calculate from selected plant
    final selectedPlant = await getSelectedPlant();
    if (selectedPlant != null) {
      final range = selectedPlant.ppmMax - selectedPlant.ppmMin;
      return (range * 0.1).round().clamp(50, 200);
    }
    
    // Default value if no plant selected
    return 100;
  }

  // Set custom target TDS (overrides plant-based calculation)
  static Future<void> setCustomTargetTds(int targetTds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_customTargetTdsKey, targetTds);
  }

  // Set custom TDS threshold
  static Future<void> setCustomTdsThreshold(int threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_customTdsThresholdKey, threshold);
  }

  // Clear selected plant
  static Future<void> clearSelectedPlant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedPlantIdKey);
    await prefs.remove(_selectedPlantNameKey);
    await prefs.remove(_selectedPlantPpmMinKey);
    await prefs.remove(_selectedPlantPpmMaxKey);
  }

  // Get plant-based recommendations
  static Future<Map<String, dynamic>> getPlantRecommendations() async {
    final selectedPlant = await getSelectedPlant();
    final targetTds = await getTargetTds();
    final threshold = await getTdsThreshold();
    
    if (selectedPlant != null) {
      return {
        'plantName': selectedPlant.namaIndonesia,
        'plantNameEn': selectedPlant.namaInggris,
        'category': selectedPlant.kategori,
        'targetTds': targetTds,
        'tdsThreshold': threshold,
        'ppmRange': '${selectedPlant.ppmMin}-${selectedPlant.ppmMax}',
        'ecRange': '${selectedPlant.ecMin}-${selectedPlant.ecMax}',
        'fertilizer': {
          'semai': selectedPlant.pupukSemai,
          'vegetatif': selectedPlant.pupukVegetatif,
          'generatif': selectedPlant.pupukGeneratif,
          'keterangan': selectedPlant.keterangan,
        },
        'harvestTime': selectedPlant.masaPanen,
        'icon': selectedPlant.icon,
        'isCustom': false,
      };
    } else {
      return {
        'plantName': 'Custom Setting',
        'plantNameEn': 'Custom Setting',
        'category': 'Manual',
        'targetTds': targetTds,
        'tdsThreshold': threshold,
        'ppmRange': 'Custom',
        'ecRange': 'Custom',
        'fertilizer': {
          'semai': 'Custom',
          'vegetatif': 'Custom',
          'generatif': 'Custom',
          'keterangan': 'Setting manual pengguna',
        },
        'harvestTime': 'Custom',
        'icon': '⚙️',
        'isCustom': true,
      };
    }
  }

  // Check if current TDS is within plant's optimal range
  static Future<Map<String, dynamic>> analyzeTdsStatus(double currentTds) async {
    final selectedPlant = await getSelectedPlant();
    final targetTds = await getTargetTds();
    final threshold = await getTdsThreshold();
    
    final double lowerBound = (targetTds - threshold).toDouble();
    final double upperBound = (targetTds + threshold).toDouble();
    
    String status;
    String recommendation;
    String color;
    
    if (currentTds < lowerBound) {
      status = 'Rendah';
      recommendation = 'Tambahkan nutrisi';
      color = 'FF5722'; // Orange/Red
    } else if (currentTds > upperBound) {
      status = 'Tinggi';
      recommendation = 'Kurangi nutrisi atau tambah air';
      color = 'FF9800'; // Orange
    } else {
      status = 'Optimal';
      recommendation = 'TDS dalam kondisi baik';
      color = '4CAF50'; // Green
    }
    
    return {
      'status': status,
      'recommendation': recommendation,
      'color': color,
      'currentTds': currentTds,
      'targetTds': targetTds,
      'threshold': threshold,
      'lowerBound': lowerBound,
      'upperBound': upperBound,
      'plantName': selectedPlant?.namaIndonesia ?? 'Custom',
      'isOptimal': currentTds >= lowerBound && currentTds <= upperBound,
    };
  }
}