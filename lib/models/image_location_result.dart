class ImageLocationSource {
  final String type;
  final String title;
  final String detail;
  final double confidence;

  const ImageLocationSource({
    required this.type,
    required this.title,
    required this.detail,
    required this.confidence,
  });
}

class ImageMetadataItem {
  final String label;
  final String value;

  const ImageMetadataItem({required this.label, required this.value});
}

class ImageLocationResult {
  final bool hasResult;
  final String title;
  final String summary;
  final double confidence;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String accuracyLabel;
  final List<ImageLocationSource> sources;
  final List<String> tips;
  final bool usedExifGps;
  final bool hadExifGpsField;
  final List<ImageMetadataItem> metadataItems;
  final List<ImageMetadataItem> fullMetadataItems;
  final List<ImageMetadataItem> diagnosticItems;

  const ImageLocationResult({
    required this.hasResult,
    required this.title,
    required this.summary,
    required this.confidence,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.accuracyLabel,
    required this.sources,
    required this.tips,
    required this.usedExifGps,
    required this.hadExifGpsField,
    required this.metadataItems,
    required this.fullMetadataItems,
    required this.diagnosticItems,
  });

  const ImageLocationResult.empty({
    required this.summary,
    this.metadataItems = const [],
    this.fullMetadataItems = const [],
    this.diagnosticItems = const [],
  })
      : hasResult = false,
        title = 'Nincs biztos helytalálat',
        confidence = 0,
        latitude = null,
        longitude = null,
        address = null,
        accuracyLabel = 'Nincs megbízható találat',
        sources = const [],
        tips = const [
          'Próbálj saját telefonnal készült, kültéri fotót használni.',
          'Kapcsold be a kamera alkalmazásban a helycímkéket, hogy EXIF GPS is kerüljön a képbe.',
          'A monitorról vagy beltérben készült képekhez ritkán van használható helyadat.',
          'Landmark találathoz Vision API kulcs kell az app_secrets fájlban.',
        ],
        usedExifGps = false,
        hadExifGpsField = false;
}
