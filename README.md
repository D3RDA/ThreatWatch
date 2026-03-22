# ThreatWatch AI

A ThreatWatch AI egy Flutter alapú kiberbiztonsági mobilalkalmazás, amely a sebezhetőségek figyelésére, a biztonságtudatosság fejlesztésére és különböző hasznos elemző funkciók bemutatására készült.

A projekt oktatási és bemutató célból készült, és több modult egyesít egyetlen alkalmazásban.

## Fő funkciók

### Aktuális sebezhetőségek
- CVE lista megjelenítése
- kategória szerinti szűrés
- keresés gyártó, termék vagy CVE azonosító alapján
- rendezés veszélyesség szerint
- watchlist kezelés
- mentett CVE-k
- megjegyzés, státusz és prioritás megadása CVE-khez

### Biztonsági segédfunkciók
- QR / URL ellenőrzés
- alap phishing ellenőrzés
- gyors biztonsági ellenőrzések
- watchlist alapú találatok kiemelése

### Képelemzés
- kép metaadatainak kiolvasása
- EXIF adatok megjelenítése
- GPS koordináta olvasási kísérlet
- képes helybecslés
- képdiagnosztika

### Arcfelismerő modul
- arc-regiszter
- profil alapú helyi felismerés
- egyszeri kamera scan
- live felismerési mód
- több arc kezelése
- zoom lehetőség a live módban

### AI és intelligens logika
- AI coach támogatás
- biztonsági magyarázatok
- kockázati prioritás alapú rendezés

## A projekt célja

Az alkalmazás célja egy olyan hasznos, modern és látványos mobilalkalmazás elkészítése, amely:
- segít a felhasználónak az aktuális sebezhetőségek figyelésében
- biztonsági ellenőrző és elemző funkciókat kínál
- bemutatja a Flutter alapú mobilfejlesztés lehetőségeit
- oktatási célra is alkalmas

## Technológiák

- Flutter
- Dart
- Android
- Google ML Kit
- Camera plugin
- EXIF metaadat olvasás
- Geocoding
- opcionális API integrációk

## Futtatás

```bash
flutter clean
flutter pub get
flutter run
