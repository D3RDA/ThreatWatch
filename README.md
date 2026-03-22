# ThreatWatch AI

Flutterben készült kiberbiztonsági dashboard és elemző alkalmazás.

## Fő funkciók

- **Dashboard**
  - CISA KEV feed összegzés
  - watchlist találatok
  - legutóbbi ellenőrzések
- **Aktuális sebezhetőségek**
  - CISA Known Exploited Vulnerabilities feed
  - keresés CVE / gyártó / termék szerint
  - saját watchlist
  - részletes nézet NVD CVE adatokkal
  - mentés, megjegyzés, státusz és prioritás a CVE-khez
- **Mentett CVE-k**
  - külön tracker nézet
  - státusz szerinti szűrés
  - saját jegyzetek és prioritás
- **QR / URL scanner**
  - kézi URL elemzés
  - QR-kód beolvasás `mobile_scanner` segítségével
  - helyi heurisztikák
  - opcionális Google Safe Browsing ellenőrzés
- **Gyors ellenőrzések**
  - jelszóerősség mérő
  - phishing szöveg / email elemző
  - cyber hygiene checklist
- **AI coach**
  - offline szabályalapú tanács kulcs nélkül
  - opcionális Gemini API integráció
- **Előzmények és statisztika**
  - mentett URL és üzenet elemzések
  - kördiagram és oszlopdiagram
  - helyi tárolás `shared_preferences` segítségével

## Fontos megjegyzés

Ez a zip **Flutter projektforrás**. Mivel a futtatókörnyezetben nem volt telepítve Flutter CLI, a platformfüggő generált mappák (`android/`, `ios/`, `web/` stb.) nincsenek benne.

### Így indítsd el

1. Csomagold ki a zipet.
2. Nyiss terminált a projekt mappájában.
3. Futtasd:

```bash
flutter create .
flutter pub get
flutter run
```

A `flutter create .` létrehozza a hiányzó natív és webes projektfájlokat úgy, hogy a meglévő `lib/` és `pubspec.yaml` megmaradjon.

## API kulcsok

A kulcsokat itt tudod megadni:

`lib/config/app_secrets.dart`

```dart
class AppSecrets {
  static const String geminiApiKey = '';
  static const String safeBrowsingApiKey = '';
}
```

### Kulcs nélkül is működik

- a KEV feed
- az NVD részletező nézet
- a watchlist
- a phishing és jelszó ellenőrzés
- a checklist
- az előzmények / statisztika
- az AI coach offline fallback módban

### Kulccsal pluszban működik

- **Google Safe Browsing** URL egyeztetés
- **Gemini AI coach** generatív válaszok

## Platformbeállítások

### Android

Az internethez add hozzá ezt a sort az `android/app/src/main/AndroidManifest.xml` fájlhoz:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS

QR scannerhez tedd bele az `ios/Runner/Info.plist` fájlba:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes.</string>
```

## Javasolt demó flow a bemutatóra

1. Dashboard megnyitása
2. Watchlist hozzáadása: `windows`, `chrome`, `wordpress`
3. Sebezhetőségek képernyőn egy CVE megnyitása
4. QR / URL scannerrel egy link ellenőrzése
5. Gyors ellenőrzéseknél phishing szöveg elemzése
6. AI coach használata
7. Előzmények és diagramok bemutatása

## GitHub leadás

```bash
git init
git add .
git commit -m "Initial ThreatWatch AI project"
git remote add origin <SAJAT_GITHUB_REPO_URL>
git branch -M main
git push -u origin main
```

## Fő csomagok

- `http`
- `shared_preferences`
- `mobile_scanner`
- `fl_chart`

## Megjegyzés az AI és a scanner részhez

Az app **védelmi / oktatási** célú. Nem tartalmaz támadó funkciókat, brute force eszközt vagy hálózati támadó szkennert. A scanner URL / QR és fenyegetéspriorizáló jellegű.


## V3 újdonságok
- valódi watchlist-only szűrő
- gyors filterek: új, ransomware, csak watchlist, csak mentettek
- mentett CVE-k könyvjelzővel
- dashboard riasztás a watchlist találatokra
- mentett CVE-k szekció a dashboardon
- top gyártók összesítés
- részletesebb "Mit tegyek most?" blokk a CVE nézetben


## V4 újdonságok
- CVE-khez saját megjegyzés írható
- státusz állítható: új, ellenőrizendő, érint minket, javítás alatt, megoldva, nem releváns
- prioritás állítható: alacsony, közepes, magas, kritikus
- külön "Mentett CVE-k" oldal került a menübe
- a dashboard most már megjeleníti a mentett CVE-k státuszát és jegyzeteit


## Arc-regiszter modul

- Új képernyő: **Arc-regiszter**
- Több mintás helyi arcprofilok névvel, szerepkörrel és megjegyzéssel
- Kamera- vagy galériaképből történő regisztráció Androidon/iOS-en
- Helyi, offline felismerés a mentett mintákhoz viszonyítva
- Felismerési napló és dashboard összegzés

Megjegyzés: a modul a `google_mlkit_face_detection` csomagra épül, ami csak Androidot és iOS-t támogat. Weben és desktopon a fő app továbbra is megnyitható, de ez a funkció nem fog működni.


## Új modulok

### Kép helyének becslése
- EXIF GPS koordináta kiolvasás
- opcionális Google Cloud Vision landmark felismerés (`visionApiKey`)
- bizalmi szint és forráslista

### TFLite arcfelismerés
- ha elhelyezel egy `assets/models/face_embedding.tflite` modellt, az app TFLite embeddinget használ
- modell nélkül automatikusan landmark-alapú helyi fallback matcher fut

