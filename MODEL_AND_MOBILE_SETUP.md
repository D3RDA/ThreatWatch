# Model és mobil beállítás

## 1. Android SDK / telefon
A projekt Androidon fut jól. A telefonos futtatáshoz legyen működő `adb`, engedélyezett USB hibakeresés és elfogadott Android licencek.

## 2. Arcfelismerő modell
A projekt `assets/models/face_embedding.tflite` útvonalon keres modellt.

Ajánlott kiindulási forrás: MobileFaceNet / FaceNet jellegű TFLite modell egy nyílt, Flutter/Android face-recognition példaprojektből.

A jelenlegi kód alapértelmezett elvárása:
- input: 112x112 RGB
- normalizálás: [-1, 1]
- output: embedding vektor

Ha a választott modell 160x160 bemenetet vár, a `lib/services/face_recognition_service_mobile.dart` fájlban a resize méretét és a bemeneti lista méretét 160-ra kell átírni.

## 3. Helybecslés / Landmark API
A `lib/config/app_secrets.dart` fájlban állítható:
- `visionApiKey`

Kulcs nélkül az EXIF GPS alapú helybecslés működhet, de a landmark-felismerés nem.
