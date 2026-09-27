# Konfigurasi Development untuk LADIMAS

# File ini berisi informasi untuk development dan testing

## Development Setup

Untuk melanjutkan development setelah deploy ke Play Store:

### 1. Environment Development

```bash
# Jalankan aplikasi dalam mode debug
flutter run --debug

# Jalankan aplikasi dalam mode release (untuk testing)
flutter run --release
```

### 2. Build untuk Testing

```bash
# Build APK debug untuk testing internal
flutter build apk --debug

# Build APK release untuk testing sebelum upload
flutter build apk --release
```

### 3. Hot Reload dan Hot Restart

- Gunakan `r` untuk hot reload
- Gunakan `R` untuk hot restart
- Gunakan `q` untuk quit

### 4. Update Aplikasi di Play Store

Ketika ingin update aplikasi:

1. **Increment Version**

   ```yaml
   # Di pubspec.yaml
   version: 1.0.1+2 # +2 adalah version code yang harus lebih besar
   ```

2. **Build App Bundle**

   ```bash
   flutter build appbundle --release
   ```

3. **Upload ke Play Console**
   - File: `build/app/outputs/bundle/release/app-release.aab`

### 5. Development Tips

- Selalu test di device fisik sebelum release
- Gunakan `flutter doctor` untuk cek environment
- Backup keystore file dengan aman
- Jangan lupa update changelog di Play Store

### 6. Troubleshooting

- Jika ada error signing, cek file `key.properties`
- Jika build gagal, coba `flutter clean` lalu `flutter pub get`
- Untuk masalah keystore, regenerate dengan command yang sama

## File Penting untuk Development

- `android/key.properties` - Konfigurasi signing (JANGAN COMMIT)
- `android/app/keystore/` - Folder keystore (JANGAN COMMIT)
- `pubspec.yaml` - Konfigurasi aplikasi
- `android/app/build.gradle` - Konfigurasi build Android
