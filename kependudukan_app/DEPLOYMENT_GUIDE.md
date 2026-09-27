# LADIMAS - Aplikasi Kependudukan Digital

Aplikasi LADIMAS telah dikonfigurasi untuk deployment ke Google Play Store dengan package name `com.firstudio.ladimas`.

## 🚀 Status Deployment

✅ **Siap untuk Play Store!**

- Package name: `com.firstudio.ladimas`
- App name: `LADIMAS`
- Version: `1.0.0 (3)`
- Target SDK: `35` (API Level 35)
- Signing key: Sudah dikonfigurasi
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

## 📱 File Output Build

Setelah build berhasil, file yang siap diupload ke Play Store:

```
build/app/outputs/bundle/release/app-release.aab
```

## 🔧 Konfigurasi yang Sudah Dilakukan

### 1. Package Name & App Name

- ✅ Package name diubah dari `com.example.kependudukan_app` ke `com.firstudio.ladimas`
- ✅ App name diubah dari `flutter_kependudukan` ke `ladimas`
- ✅ Display name di AndroidManifest: `LADIMAS`

### 2. Signing Configuration

- ✅ Keystore dibuat: `android/app/keystore/ladimas-release-key.jks`
- ✅ Key properties: `android/key.properties`
- ✅ Build configuration sudah dikonfigurasi untuk release

### 3. Build Configuration

- ✅ Kotlin version diupdate ke 1.9.0
- ✅ Release build type dikonfigurasi dengan signing
- ✅ Semua import statement sudah diupdate

## 🛠️ Cara Build untuk Play Store

### Menggunakan Script Build

```bash
# Build App Bundle untuk Play Store
./build.sh bundle

# Build APK release untuk testing
./build.sh release

# Build APK debug untuk development
./build.sh debug
```

### Menggunakan Flutter Command

```bash
# Build App Bundle (Recommended untuk Play Store)
flutter build appbundle --release

# Build APK untuk testing
flutter build apk --release
```

## 📋 Langkah Upload ke Play Store

1. **Buka Google Play Console**

   - Login ke [Google Play Console](https://play.google.com/console)

2. **Buat Aplikasi Baru**

   - Klik "Create app"
   - Isi nama aplikasi: `LADIMAS`
   - Pilih bahasa default
   - Pilih jenis aplikasi: App atau Game

3. **Upload App Bundle**

   - Pergi ke "Production" → "Releases"
   - Klik "Create new release"
   - Upload file: `build/app/outputs/bundle/release/app-release.aab`

4. **Isi Informasi Aplikasi**

   - Deskripsi aplikasi
   - Screenshots
   - Icon aplikasi
   - Kategori aplikasi

5. **Review dan Publish**
   - Review semua informasi
   - Submit untuk review

## 🔄 Update Aplikasi di Masa Depan

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

## 💻 Development Setup

Untuk melanjutkan development:

### 1. Environment Development

```bash
# Jalankan aplikasi dalam mode debug
flutter run --debug

# Jalankan aplikasi dalam mode release (untuk testing)
flutter run --release
```

### 2. Hot Reload dan Hot Restart

- Gunakan `r` untuk hot reload
- Gunakan `R` untuk hot restart
- Gunakan `q` untuk quit

### 3. Development Tips

- Selalu test di device fisik sebelum release
- Gunakan `flutter doctor` untuk cek environment
- Backup keystore file dengan aman
- Jangan lupa update changelog di Play Store

## 🔐 Keamanan

### File Sensitif (JANGAN COMMIT)

- `android/key.properties` - Konfigurasi signing
- `android/app/keystore/` - Folder keystore
- `*.jks` - File keystore

### Backup Penting

- Simpan file keystore dengan aman
- Backup password keystore
- Simpan informasi signing untuk update masa depan

## 🐛 Troubleshooting

### Build Error

- Jika ada error signing, cek file `key.properties`
- Jika build gagal, coba `flutter clean` lalu `flutter pub get`
- Untuk masalah keystore, regenerate dengan command yang sama

### Import Error

- Pastikan semua import menggunakan `package:ladimas`
- Jika ada error import, jalankan:
  ```bash
  find lib -name "*.dart" -exec sed -i '' 's/package:flutter_kependudukan/package:ladimas/g' {} \;
  ```

## 📞 Support

Jika ada masalah dengan deployment atau development, silakan konsultasi dengan tim development.

---

**Selamat! Aplikasi LADIMAS sudah siap untuk Play Store! 🎉**
