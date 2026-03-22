import 'dart:convert';
import 'dart:typed_data';

import 'package:exif/exif.dart' as dart_exif;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:native_exif/native_exif.dart' as native_exif;

import '../config/app_secrets.dart';
import '../models/image_location_result.dart';

class ImageLocationService {
  Future<ImageLocationResult> analyzeImageBytes(Uint8List bytes, {String? filePath}) async {
    final sources = <ImageLocationSource>[];
    final metadataItems = <ImageMetadataItem>[];
    final fullMetadataItems = <ImageMetadataItem>[];
    final diagnosticItems = <ImageMetadataItem>[];
    double? latitude;
    double? longitude;
    String? address;
    var invalidExifPlaceholder = false;
    var usedExif = false;
    var usedLandmark = false;
    var hadExifGpsField = false;

    void addDiagnostic(String label, String value) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        diagnosticItems.add(ImageMetadataItem(label: label, value: normalized));
      }
    }

    // 1) Prefer native EXIF from the original file path on Android/iOS.
    if (filePath != null && filePath.trim().isNotEmpty) {
      try {
        final exif = await native_exif.Exif.fromPath(filePath);
        final latLong = await exif.getLatLong();
        final originalDate = await exif.getOriginalDate();
        final rawAttributes = await exif.getAttributes();
        final attributes = <String, Object?>{...?rawAttributes};

        _appendNativeExifMetadata(
          attributes,
          metadataItems,
          filePath: filePath,
          originalDate: originalDate,
        );
        _appendAllNativeExifMetadata(
          attributes,
          fullMetadataItems,
          filePath: filePath,
          originalDate: originalDate,
        );

        hadExifGpsField = attributes.containsKey('GPSLatitude') ||
            attributes.containsKey('GPSLongitude') ||
            latLong != null;

        addDiagnostic('Natív EXIF olvasás', 'Sikeres');
        addDiagnostic('Natív getLatLong()', latLong?.toString() ?? 'null');
        if (latLong != null) {
          final exifLat = _nativeLat(latLong);
          final exifLng = _nativeLng(latLong);
          addDiagnostic('Natív szélesség', exifLat?.toString() ?? 'null');
          addDiagnostic('Natív hosszúság', exifLng?.toString() ?? 'null');
          if (exifLat != null && exifLng != null && _isUsableCoordinate(exifLat, exifLng)) {
            latitude = exifLat;
            longitude = exifLng;
            usedExif = true;
            sources.add(
              ImageLocationSource(
                type: 'exif',
                title: 'EXIF GPS koordináta',
                detail: '${exifLat.toStringAsFixed(6)}, ${exifLng.toStringAsFixed(6)}',
                confidence: 0.99,
              ),
            );
          } else {
            invalidExifPlaceholder = true;
          }
        }

        await exif.close();
      } catch (error) {
        addDiagnostic('Natív EXIF olvasás', 'Hiba: $error');
        // Fall back to byte-level EXIF parsing below.
      }
    }

    // 2) Fallback metadata read from bytes if native EXIF wasn't enough.
    if (metadataItems.isEmpty || !usedExif) {
      try {
        final exifData = await dart_exif.readExifFromBytes(bytes);
        _appendByteExifMetadata(exifData, metadataItems, filePath: filePath);
        _appendAllByteExifMetadata(exifData, fullMetadataItems, filePath: filePath);
        addDiagnostic('Byte EXIF olvasás', 'Sikeres (${exifData.length} mező)');

        final exifLat = _readGpsCoordinate(
          exifData,
          latitudeTag: 'GPS GPSLatitude',
          latitudeRefTag: 'GPS GPSLatitudeRef',
        );
        final exifLng = _readGpsCoordinate(
          exifData,
          latitudeTag: 'GPS GPSLongitude',
          latitudeRefTag: 'GPS GPSLongitudeRef',
        );
        hadExifGpsField = hadExifGpsField ||
            exifData.containsKey('GPS GPSLatitude') ||
            exifData.containsKey('GPS GPSLongitude');
        addDiagnostic('Byte GPS szélesség', exifLat?.toString() ?? 'null');
        addDiagnostic('Byte GPS hosszúság', exifLng?.toString() ?? 'null');
        addDiagnostic('Volt GPS mező', hadExifGpsField ? 'Igen' : 'Nem');

        if (!usedExif && exifLat != null && exifLng != null) {
          if (_isUsableCoordinate(exifLat, exifLng)) {
            latitude = exifLat;
            longitude = exifLng;
            usedExif = true;
            sources.add(
              ImageLocationSource(
                type: 'exif',
                title: 'EXIF GPS koordináta',
                detail: '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                confidence: 0.97,
              ),
            );
          } else {
            invalidExifPlaceholder = true;
          }
        }
      } catch (error) {
        addDiagnostic('Byte EXIF olvasás', 'Hiba: $error');
        // Ignore and continue to other sources.
      }
    }

    // 3) Reverse geocoding from exact coordinates.
    if (latitude != null && longitude != null) {
      address = await _reverseGeocode(latitude!, longitude!);
      if (address != null && address!.isNotEmpty) {
        sources.add(
          ImageLocationSource(
            type: 'reverse_geocode',
            title: 'Cím visszafejtése koordinátából',
            detail: address!,
            confidence: usedExif ? 0.96 : 0.88,
          ),
        );
      }
    }

    // 4) Landmark fallback only when exact GPS wasn't available.
    if (!usedExif) {
      final landmark = await _detectLandmark(bytes);
      if (landmark != null) {
        usedLandmark = true;
        sources.add(landmark);
        final maybeLat = _extractLat(landmark.detail);
        final maybeLng = _extractLng(landmark.detail);
        if ((latitude == null || longitude == null) &&
            maybeLat != null &&
            maybeLng != null &&
            _isUsableCoordinate(maybeLat, maybeLng)) {
          latitude = maybeLat;
          longitude = maybeLng;
          address = await _reverseGeocode(latitude!, longitude!);
          if (address != null && address!.isNotEmpty) {
            sources.add(
              ImageLocationSource(
                type: 'reverse_geocode',
                title: 'Landmark alapján becsült cím',
                detail: address!,
                confidence: 0.82,
              ),
            );
          }
        }
      }
    }

    if (sources.isEmpty) {
      final lowerPath = (filePath ?? '').toLowerCase();
      final looksScaledCopy = lowerPath.contains('scaled_') || lowerPath.contains('/cache/') || lowerPath.contains('cache/');
      final summary = invalidExifPlaceholder
          ? 'A kép EXIF mezőjében 0.00000, 0.00000 szerepelt, ami tipikus placeholder. Nem találtam használható GPS vagy nevezetesség alapú helyadatot.'
          : hadExifGpsField
              ? 'A képben volt GPS mező, de az nem tartalmazott használható koordinátát. Pontos helyet csak valódi EXIF GPS-ből tudok adni.'
              : 'A kép metaadataiban nincs használható EXIF GPS koordináta. Pontos helyet ilyenkor nem lehet megadni, csak becslést.';
      final extra = looksScaledCopy
          ? ' A kiválasztott fájl egy átméretezett vagy gyorsítótárazott másolatnak tűnik (${filePath ?? 'ismeretlen fájl'}), ezért a helyadat elveszhetett. Válaszd ki az eredeti DCIM/Camera képet vagy készíts új fotót tömörítés nélkül.'
          : '';
      return ImageLocationResult.empty(
        summary: '$summary$extra',
        metadataItems: metadataItems,
        fullMetadataItems: fullMetadataItems,
        diagnosticItems: diagnosticItems,
      );
    }

    sources.sort((a, b) => b.confidence.compareTo(a.confidence));
    final primary = sources.first;
    final title = address ?? primary.title;
    final accuracyLabel = usedExif
        ? 'Pontos EXIF GPS találat'
        : usedLandmark
            ? 'Landmark alapú becslés'
            : 'Becsült helytalálat';
    final summary = usedExif
        ? address != null
            ? 'A helyet a kép beágyazott EXIF GPS adatából határoztam meg, majd a koordinátát címmé alakítottam.'
            : 'A helyet a kép beágyazott EXIF GPS adata alapján határoztam meg.'
        : usedLandmark
            ? address != null
                ? 'A képből felismerhető nevezetesség alapján becsültem helyet, majd címmé alakítottam.'
                : 'A helyet egy felismerhető nevezetességből becsültem.'
            : 'A kép alapján csak részleges helybecslés áll rendelkezésre.';

    return ImageLocationResult(
      hasResult: true,
      title: title,
      summary: invalidExifPlaceholder && !usedExif
          ? '$summary Az EXIF-ben talált 0.00000, 0.00000 értéket nem vettem figyelembe, mert az nem valódi helyadat.'
          : summary,
      confidence: primary.confidence,
      latitude: latitude,
      longitude: longitude,
      address: address,
      accuracyLabel: accuracyLabel,
      sources: sources,
      tips: const [
        'A telefonnal, bekapcsolt helycímkékkel készült kültéri fotók adják a legjobb találatot.',
        'Galériából választásnál ne használj átméretezett vagy tömörített (scaled/cache) másolatot, mert abból elveszhet a GPS.',
        'Pontos helyet csak valódi EXIF GPS koordinátából lehet adni.',
        'A monitorról, screenshotból vagy beltérben készült képekhez ritkán van használható GPS.',
        'Ha nincs GPS, a rendszer ismert nevezetesség alapján próbál becslést adni.',
        'A cím-visszafejtés internetkapcsolatot igényel.',
      ],
      usedExifGps: usedExif,
      hadExifGpsField: hadExifGpsField,
      metadataItems: metadataItems,
      fullMetadataItems: fullMetadataItems,
      diagnosticItems: diagnosticItems,
    );
  }

  void _appendNativeExifMetadata(
    Map<String, Object?> attributes,
    List<ImageMetadataItem> items, {
    String? filePath,
    DateTime? originalDate,
  }) {
    final seen = <String>{};

    void addItem(String label, String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) return;
      final key = '$label::$normalized';
      if (seen.add(key)) {
        items.add(ImageMetadataItem(label: label, value: normalized));
      }
    }

    if (filePath != null && filePath.trim().isNotEmpty) {
      final normalizedPath = filePath.replaceAll('\\', '/');
      addItem('Forrásfájl', normalizedPath.split('/').last);
    }
    if (originalDate != null) {
      addItem('Készítés ideje', originalDate.toIso8601String());
    }
    addItem('Kamera', attributes['Model']?.toString());
    addItem('Gyártó', attributes['Make']?.toString());
    addItem('GPS szélesség', attributes['GPSLatitude']?.toString());
    addItem('GPS hosszúság', attributes['GPSLongitude']?.toString());
    addItem('GPS szélesség irány', attributes['GPSLatitudeRef']?.toString());
    addItem('GPS hosszúság irány', attributes['GPSLongitudeRef']?.toString());
  }

  void _appendByteExifMetadata(
    Map<String, dart_exif.IfdTag> exifData,
    List<ImageMetadataItem> items, {
    String? filePath,
  }) {
    final seen = items.map((e) => '${e.label}::${e.value}').toSet();

    void addIfPresent(String label, List<String> keys) {
      for (final key in keys) {
        final tag = exifData[key];
        if (tag != null) {
          final value = tag.printable.trim();
          if (value.isNotEmpty) {
            final unique = '$label::$value';
            if (seen.add(unique)) {
              items.add(ImageMetadataItem(label: label, value: value));
            }
            return;
          }
        }
      }
    }

    if (filePath != null && filePath.trim().isNotEmpty) {
      final normalizedPath = filePath.replaceAll('\\', '/');
      final value = normalizedPath.split('/').last;
      final unique = 'Forrásfájl::$value';
      if (seen.add(unique)) {
        items.add(ImageMetadataItem(label: 'Forrásfájl', value: value));
      }
    }
    addIfPresent('Készítés ideje', ['EXIF DateTimeOriginal', 'Image DateTime']);
    addIfPresent('Kamera', ['Image Model']);
    addIfPresent('Gyártó', ['Image Make']);
    addIfPresent('GPS szélesség', ['GPS GPSLatitude']);
    addIfPresent('GPS hosszúság', ['GPS GPSLongitude']);
    addIfPresent('GPS szélesség irány', ['GPS GPSLatitudeRef']);
    addIfPresent('GPS hosszúság irány', ['GPS GPSLongitudeRef']);
  }

  void _appendAllNativeExifMetadata(
    Map<String, Object?> attributes,
    List<ImageMetadataItem> items, {
    String? filePath,
    DateTime? originalDate,
  }) {
    final seen = items.map((e) => '${e.label}::${e.value}').toSet();

    void addItem(String label, String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) return;
      final key = '$label::$normalized';
      if (seen.add(key)) {
        items.add(ImageMetadataItem(label: label, value: normalized));
      }
    }

    if (filePath != null && filePath.trim().isNotEmpty) {
      final normalizedPath = filePath.replaceAll('\\', '/');
      addItem('Forrásfájl', normalizedPath.split('/').last);
    }
    if (originalDate != null) {
      addItem('Készítés ideje', originalDate.toIso8601String());
    }
    final keys = attributes.keys.toList()..sort();
    for (final key in keys) {
      addItem(key, attributes[key]?.toString());
    }
  }

  void _appendAllByteExifMetadata(
    Map<String, dart_exif.IfdTag> exifData,
    List<ImageMetadataItem> items, {
    String? filePath,
  }) {
    final seen = items.map((e) => '${e.label}::${e.value}').toSet();

    void addItem(String label, String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) return;
      final key = '$label::$normalized';
      if (seen.add(key)) {
        items.add(ImageMetadataItem(label: label, value: normalized));
      }
    }

    if (filePath != null && filePath.trim().isNotEmpty) {
      final normalizedPath = filePath.replaceAll('\\', '/');
      addItem('Forrásfájl', normalizedPath.split('/').last);
    }
    final keys = exifData.keys.toList()..sort();
    for (final key in keys) {
      addItem(key, exifData[key]?.printable);
    }
  }


  Future<ImageLocationSource?> _detectLandmark(Uint8List bytes) async {
    if (AppSecrets.visionApiKey.isEmpty) {
      return null;
    }

    final uri = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=${AppSecrets.visionApiKey}');
    final payload = {
      'requests': [
        {
          'image': {'content': base64Encode(bytes)},
          'features': [
            {'type': 'LANDMARK_DETECTION', 'maxResults': 3},
          ],
        },
      ],
    };

    try {
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final responses = decoded['responses'] as List<dynamic>? ?? const [];
      if (responses.isEmpty) {
        return null;
      }
      final annotations = (responses.first as Map<String, dynamic>)['landmarkAnnotations'] as List<dynamic>? ?? const [];
      if (annotations.isEmpty) {
        return null;
      }
      final first = annotations.first as Map<String, dynamic>;
      final description = (first['description'] ?? 'Ismeretlen landmark').toString();
      final score = double.tryParse((first['score'] ?? '0.65').toString()) ?? 0.65;
      final locations = first['locations'] as List<dynamic>? ?? const [];
      String detail = 'Vizualis találat';
      if (locations.isNotEmpty) {
        final latLng = (locations.first as Map<String, dynamic>)['latLng'] as Map<String, dynamic>? ?? {};
        final lat = double.tryParse((latLng['latitude'] ?? '').toString());
        final lng = double.tryParse((latLng['longitude'] ?? '').toString());
        if (lat != null && lng != null) {
          detail = 'lat:$lat lng:$lng';
        }
      }
      return ImageLocationSource(
        type: 'landmark',
        title: description,
        detail: detail,
        confidence: score.clamp(0, 1).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.country,
        ]
            .where((item) => item != null && item!.trim().isNotEmpty)
            .map((item) => item!.trim())
            .toList();
        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
    } catch (_) {
      // Fall through to HTTP fallback.
    }

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=17&addressdetails=1',
    );
    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'ThreatWatchAI/1.0 (local reverse geocode)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = (decoded['display_name'] ?? '').toString().trim();
      if (displayName.isNotEmpty) {
        return displayName;
      }
      final address = decoded['address'] as Map<String, dynamic>?;
      if (address == null) {
        return null;
      }
      final road = (address['road'] ?? address['pedestrian'] ?? '').toString().trim();
      final city = (address['city'] ?? address['town'] ?? address['village'] ?? '').toString().trim();
      final state = (address['state'] ?? '').toString().trim();
      final country = (address['country'] ?? '').toString().trim();
      final parts = [road, city, state, country].where((item) => item.isNotEmpty).toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  double? _readGpsCoordinate(
    Map<String, dart_exif.IfdTag> exifData, {
    required String latitudeTag,
    required String latitudeRefTag,
  }) {
    final tag = exifData[latitudeTag];
    final ref = exifData[latitudeRefTag]?.printable;
    if (tag == null) {
      return null;
    }
    final values = _parseExifCoordinate(tag.values.toString());
    if (values.length != 3) {
      return null;
    }
    final decimal = values[0] + (values[1] / 60) + (values[2] / 3600);
    if ((ref ?? '').toUpperCase().contains('S') || (ref ?? '').toUpperCase().contains('W')) {
      return -decimal;
    }
    return decimal;
  }

  bool _isUsableCoordinate(double lat, double lng) {
    if (lat.abs() < 0.00001 && lng.abs() < 0.00001) {
      return false;
    }
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  List<double> _parseExifCoordinate(String raw) {
    final cleaned = raw.replaceAll('[', '').replaceAll(']', '');
    final parts = cleaned
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return parts.map<double>((part) {
      if (part.contains('/')) {
        final split = part.split('/');
        final numerator = double.tryParse(split.first.trim()) ?? 0.0;
        final denominator = double.tryParse(split.last.trim()) ?? 1.0;
        return denominator == 0 ? 0.0 : numerator / denominator;
      }
      return double.tryParse(part) ?? 0.0;
    }).toList();
  }



  double? _nativeLat(Object latLong) {
    try {
      final dynamic value = latLong;
      final candidate = value.latitude ?? value.lat;
      if (candidate is num) return candidate.toDouble();
      return double.tryParse(candidate.toString());
    } catch (_) {
      final text = latLong.toString();
      final match = RegExp(r'latitude[:= ]+(-?[0-9.]+)', caseSensitive: false).firstMatch(text);
      return match == null ? null : double.tryParse(match.group(1)!);
    }
  }

  double? _nativeLng(Object latLong) {
    try {
      final dynamic value = latLong;
      final candidate = value.longitude ?? value.lng ?? value.lon;
      if (candidate is num) return candidate.toDouble();
      return double.tryParse(candidate.toString());
    } catch (_) {
      final text = latLong.toString();
      final match = RegExp(r'(longitude|lng|lon)[:= ]+(-?[0-9.]+)', caseSensitive: false).firstMatch(text);
      return match == null ? null : double.tryParse(match.group(2)!);
    }
  }

  double? _extractLat(String value) {
    final match = RegExp(r'lat:([-0-9.]+)').firstMatch(value);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  double? _extractLng(String value) {
    final match = RegExp(r'lng:([-0-9.]+)').firstMatch(value);
    return match == null ? null : double.tryParse(match.group(1)!);
  }
}
