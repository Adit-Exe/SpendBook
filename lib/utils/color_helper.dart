import 'package:flutter/material.dart';

class ColorHelper {
  /// Generates a map of Category -> Color based on total spending amount.
  /// The category with the highest amount gets the darkest shade, and the category
  /// with the lowest amount gets the lightest shade.
  static Map<String, Color> getCategoryColorMap(Color primaryColor, Map<String, double> categoryAmounts) {
    if (categoryAmounts.isEmpty) return {};

    // Sort categories by amount descending (highest spend first)
    final sortedEntries = categoryAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final Map<String, Color> colorMap = {};
    final hsl = HSLColor.fromColor(primaryColor);
    final int count = sortedEntries.length;

    // Define lightness ranges for shades.
    // 0.25 (darker) to 0.75 (lighter) to ensure text readability and chart contrast.
    const double minLightness = 0.25;
    const double maxLightness = 0.75;

    for (int i = 0; i < count; i++) {
      final category = sortedEntries[i].key;
      double lightness;
      if (count == 1) {
        // Fallback for single category
        lightness = 0.45;
      } else {
        // Interpolate lightness. i = 0 (highest amount) gets minLightness (darkest).
        // i = count - 1 (lowest amount) gets maxLightness (lightest).
        lightness = minLightness + (maxLightness - minLightness) * (i / (count - 1));
      }
      colorMap[category] = hsl.withLightness(lightness).toColor();
    }

    return colorMap;
  }
}
