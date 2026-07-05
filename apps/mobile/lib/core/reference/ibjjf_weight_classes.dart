class WeightClassRow {
  final String division;
  final String label;
  final double? maxKg; // null => open class
  final double? maxLb;
  const WeightClassRow(this.division, this.label, this.maxKg, this.maxLb);
}

const Map<String, Map<String, List<WeightClassRow>>> ibjjfWeightClasses = {
  'male': {
    'gi': [
      WeightClassRow('rooster', 'Rooster', 57.5, 126.8),
      WeightClassRow('light_feather', 'Light Feather', 64, 141.1),
      WeightClassRow('feather', 'Feather', 70, 154.3),
      WeightClassRow('light', 'Light', 76, 167.6),
      WeightClassRow('middle', 'Middle', 82.3, 181.4),
      WeightClassRow('medium_heavy', 'Medium Heavy', 88.3, 194.7),
      WeightClassRow('heavy', 'Heavy', 94.3, 207.9),
      WeightClassRow('super_heavy', 'Super Heavy', 100.5, 221.6),
      WeightClassRow('ultra_heavy', 'Ultra Heavy', null, null),
    ],
    'nogi': [
      WeightClassRow('rooster', 'Rooster', 55.5, 122.4),
      WeightClassRow('light_feather', 'Light Feather', 61.5, 135.6),
      WeightClassRow('feather', 'Feather', 67.5, 148.8),
      WeightClassRow('light', 'Light', 73.5, 162.0),
      WeightClassRow('middle', 'Middle', 79.5, 175.3),
      WeightClassRow('medium_heavy', 'Medium Heavy', 85.5, 188.5),
      WeightClassRow('heavy', 'Heavy', 91.5, 201.7),
      WeightClassRow('super_heavy', 'Super Heavy', 97.5, 215.0),
      WeightClassRow('ultra_heavy', 'Ultra Heavy', null, null),
    ],
  },
  'female': {
    'gi': [
      WeightClassRow('rooster', 'Rooster', 48.5, 106.9),
      WeightClassRow('light_feather', 'Light Feather', 53.5, 117.9),
      WeightClassRow('feather', 'Feather', 58.5, 129.0),
      WeightClassRow('light', 'Light', 64, 141.1),
      WeightClassRow('middle', 'Middle', 69, 152.1),
      WeightClassRow('medium_heavy', 'Medium Heavy', 74, 163.1),
      WeightClassRow('super_heavy', 'Super Heavy', null, null),
    ],
    'nogi': [
      WeightClassRow('rooster', 'Rooster', 46.5, 102.5),
      WeightClassRow('light_feather', 'Light Feather', 51.5, 113.5),
      WeightClassRow('feather', 'Feather', 56.5, 124.6),
      WeightClassRow('light', 'Light', 61.5, 135.6),
      WeightClassRow('middle', 'Middle', 66.5, 146.6),
      WeightClassRow('medium_heavy', 'Medium Heavy', 71.5, 157.6),
      WeightClassRow('super_heavy', 'Super Heavy', null, null),
    ],
  },
};

List<WeightClassRow> divisionsFor(String gender, String context) {
  return ibjjfWeightClasses[gender]?[context] ?? const [];
}
