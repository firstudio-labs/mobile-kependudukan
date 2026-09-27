# Konfigurasi Play Store untuk LADIMAS

# File ini berisi informasi penting untuk deployment ke Play Store

## Informasi Aplikasi

- Nama Aplikasi: LADIMAS
- Package Name: com.firstudio.ladimas
- Version: 1.0.0 (1)
- Target SDK: 34
- Min SDK: 21

## Signing Information

- Keystore: keystore/ladimas-release-key.jks
- Key Alias: ladimas-key
- Store Password: ladimas123
- Key Password: ladimas123

## Play Store Checklist

- [ ] Upload APK/AAB ke Play Console
- [ ] Isi informasi aplikasi (deskripsi, screenshots, dll)
- [ ] Set pricing dan distribution
- [ ] Review dan publish

## Build Commands

```bash
# Build APK untuk testing
flutter build apk --release

# Build App Bundle untuk Play Store (Recommended)
flutter build appbundle --release
```

## File Output

- APK: build/app/outputs/flutter-apk/app-release.apk
- AAB: build/app/outputs/bundle/release/app-release.aab

## Catatan Penting

- Simpan file keystore dengan aman
- Backup password keystore
- Jangan commit file key.properties ke repository
- Untuk update aplikasi, increment version code di pubspec.yaml
