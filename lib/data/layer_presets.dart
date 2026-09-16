import 'dart:convert';

/// One saved map-layer configuration, as picked from the dropdown at the top
/// of the Map Layers dialog.
///
/// Opacities are keyed by layer NAME rather than by position in the layer
/// list. The underlying settings keys are versioned upstream
/// (`key-layers-v52`, `key-weather-products-v2`) and the layer set grows over
/// time; a preset stored as a bare index-parallel list would silently map to
/// the wrong layers the first time upstream inserts one.
class LayerPreset {

  /// Name shown in the dropdown. Unique within the stored list.
  final String name;

  /// Layer name -> opacity (0..1). A layer absent from the map is off.
  final Map<String, double> layers;

  /// Weather product name -> opacity (0..1). Absent means off.
  final Map<String, double> products;

  /// Traffic puck size, one of "S" / "M" / "L".
  final String puck;

  const LayerPreset({
    required this.name,
    required this.layers,
    required this.products,
    required this.puck,
  });

  /// Snapshot the live dialog state into a preset.
  factory LayerPreset.capture({
    required String name,
    required List<String> layerNames,
    required List<double> layerOpacity,
    required List<String> productNames,
    required List<double> productOpacity,
    required String puck,
  }) {
    final Map<String, double> l = {};
    for(int i = 0; i < layerNames.length && i < layerOpacity.length; i++) {
      l[layerNames[i]] = layerOpacity[i];
    }
    final Map<String, double> p = {};
    for(int i = 0; i < productNames.length && i < productOpacity.length; i++) {
      p[productNames[i]] = productOpacity[i];
    }
    return LayerPreset(name: name, layers: l, products: p, puck: puck);
  }

  /// Project this preset back onto the current layer list.
  ///
  /// A preset describes a complete configuration, so any layer it does not
  /// mention — one added by a later app version, say — comes back off rather
  /// than keeping whatever happened to be set. That keeps preset selection
  /// deterministic instead of depending on what was on beforehand.
  List<double> opacityFor(List<String> layerNames) {
    return layerNames.map((String n) => layers[n] ?? 0.0).toList();
  }

  List<double> productOpacityFor(List<String> productNames) {
    return productNames.map((String n) => products[n] ?? 0.0).toList();
  }

  Map<String, dynamic> toJson() => {
    "name": name,
    "layers": layers,
    "products": products,
    "puck": puck,
  };

  factory LayerPreset.fromJson(Map<String, dynamic> json) {
    Map<String, double> toDoubleMap(dynamic raw) {
      if(raw is! Map) {
        return {};
      }
      final Map<String, double> out = {};
      raw.forEach((key, value) {
        final double? d = value is num ? value.toDouble() : double.tryParse("$value");
        if(d != null) {
          out["$key"] = d;
        }
      });
      return out;
    }

    return LayerPreset(
      name: "${json["name"] ?? "default"}",
      layers: toDoubleMap(json["layers"]),
      products: toDoubleMap(json["products"]),
      puck: "${json["puck"] ?? "M"}",
    );
  }

  LayerPreset renamed(String newName) =>
      LayerPreset(name: newName, layers: layers, products: products, puck: puck);

  /// Encode / decode the whole stored list. Anything malformed decodes to an
  /// empty list so a bad write can never wedge the layer dialog shut.
  static String encode(List<LayerPreset> presets) =>
      jsonEncode(presets.map((LayerPreset e) => e.toJson()).toList());

  static List<LayerPreset> decode(String raw) {
    if(raw.isEmpty) {
      return [];
    }
    try {
      final dynamic parsed = jsonDecode(raw);
      if(parsed is! List) {
        return [];
      }
      return parsed
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> e) => LayerPreset.fromJson(e))
          .toList();
    }
    catch(e) {
      return [];
    }
  }

  /// Name used for the always-present first entry in the dropdown.
  static const String defaultName = "default";

  /// Make [name] unique against [existing] by appending " (2)", " (3)", ...
  static String uniqueName(String name, List<LayerPreset> existing) {
    final Set<String> taken = existing.map((LayerPreset e) => e.name).toSet();
    if(!taken.contains(name)) {
      return name;
    }
    for(int i = 2; i < 1000; i++) {
      final String candidate = "$name ($i)";
      if(!taken.contains(candidate)) {
        return candidate;
      }
    }
    return name;
  }
}
