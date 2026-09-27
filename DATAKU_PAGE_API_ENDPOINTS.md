# Daftar API Endpoints yang Dipanggil di DatakuPage

Dokumen ini berisi daftar lengkap semua URL/endpoint yang dipanggil oleh halaman DatakuPage untuk keperluan pengecekan cache di backend.

## 📋 Ringkasan

DatakuPage melakukan loading data ke beberapa endpoint berikut:

---

## 🔗 Daftar Endpoint

### 1. **GET Biodata Lengkap** (Primary)
- **URL**: `${AppConstants.authApiUrl}/biodata`
- **Method**: `GET`
- **Headers**:
  - `Accept: application/json`
  - `Authorization: Bearer {token}`
  - `X-API-KEY: {apiKey}`
- **Kapan dipanggil**: 
  - Saat pertama kali load data (jika tidak ada cache)
  - Saat manual refresh (pull-to-refresh)
  - Setelah edit data (cache di-invalidate)
- **Response**: 
  ```json
  {
    "status": "SUCCESS",
    "data": {
      "biodata": {...},
      "informasi_usaha": {...},
      "user": {...}
    }
  }
  ```
- **Lokasi kode**: `dataku_page.dart` line 128

---

### 2. **GET Penduduk Detail** (Fallback)
- **URL**: `${AppConstants.apiUrl}/api/citizens/{nik}`
- **Method**: `GET`
- **Headers**:
  - `Content-Type: application/json`
  - `X-API-KEY: {apiKey}`
- **Kapan dipanggil**:
  - Hanya jika endpoint `/biodata` gagal atau tidak mengembalikan data
  - Ambil 1 penduduk berdasarkan NIK (lebih hemat bandwidth untuk jaringan tidak stabil)
- **Response**: object `{ status, data: { ...citizen } }`
- **Lokasi kode**:
  - `dataku_page.dart` line 150 (via `AuthRepository.getPendudukDetail()`)
  - `penduduk_api_service.dart` line 271 (method `getPendudukDetailByNik()`)
  - `document_services_webview_page.dart` (ambil lokasi via `/api/citizens/{nik}`)
  - `berita_desa_page.dart` (ambil village_id via `/api/citizens/{nik}`)

---

### 3. **GET Foto Diri dari Dokumen**
- **URL**: `${AppConstants.authApiUrl}/user/family-member/{nik}/documents`
- **Method**: `GET`
- **Headers**:
  - `Accept: application/json`
  - `Authorization: Bearer {token}`
- **Kapan dipanggil**: 
  - Setelah biodata berhasil di-load
  - Untuk mendapatkan foto diri dari dokumen anggota keluarga
- **Response**:
  ```json
  {
    "success": true,
    "documents": {
      "foto_diri": {
        "preview_url": "..."
      }
    }
  }
  ```
- **Lokasi kode**: 
  - `dataku_page.dart` line 166 (via `FamilyRepository.getFamilyMemberDocuments()`)
  - `penduduk_api_service.dart` line 533 (method `getFamilyMemberDocuments()`)

---

### 4. **GET Provinsi** (Wilayah Service)
- **URL**: `${AppConstants.apiUrl}/provinces`
- **Method**: `GET`
- **Headers**:
  - `Accept: application/json`
  - `Content-Type: application/json`
  - `X-API-Key: {apiKey}`
- **Kapan dipanggil**: 
  - Hanya jika `province_name` kosong tapi `province_id` ada
  - Dipanggil secara parallel dengan endpoint wilayah lainnya
- **Response**: Array of provinces
- **Lokasi kode**: 
  - `dataku_page.dart` line 304 (via `WilayahService.getProvince()`)
  - `wilayah_service.dart` line 55

---

### 5. **GET Kabupaten/Kota** (Wilayah Service)
- **URL**: `${AppConstants.apiUrl}/districts/{provinceCode}`
- **Method**: `GET`
- **Headers**:
  - `Accept: application/json`
  - `Content-Type: application/json`
  - `X-API-Key: {apiKey}`
- **Kapan dipanggil**: 
  - Hanya jika `district_name` kosong tapi `district_id` ada
  - Dipanggil secara parallel dengan endpoint wilayah lainnya
- **Response**: Array of districts
- **Lokasi kode**: 
  - `dataku_page.dart` line 312 (via `WilayahService.getDistrict()`)
  - `wilayah_service.dart` line 76

---

### 6. **GET Kecamatan** (Wilayah Service)
- **URL**: `${AppConstants.apiUrl}/sub-districts/{districtCode}`
- **Method**: `GET`
- **Headers**:
  - `Accept: application/json`
  - `Content-Type: application/json`
  - `X-API-Key: {apiKey}`
- **Kapan dipanggil**: 
  - Hanya jika `sub_district_name` kosong tapi `sub_district_id` ada
  - Dipanggil secara parallel dengan endpoint wilayah lainnya
- **Response**: Array of sub-districts
- **Lokasi kode**: 
  - `dataku_page.dart` line 320 (via `WilayahService.getSubDistrict()`)
  - `wilayah_service.dart` line 115

---

### 7. **GET Desa/Kelurahan** (Wilayah Service)
- **URL**: `${AppConstants.apiUrl}/villages/{subDistrictCode}`
- **Method**: `GET`
- **Headers**:
  - `Accept: application/json`
  - `Content-Type: application/json`
  - `X-API-Key: {apiKey}`
- **Kapan dipanggil**: 
  - Hanya jika `village_name` kosong tapi `village_id` ada
  - Dipanggil secara parallel dengan endpoint wilayah lainnya
- **Response**: Array of villages
- **Lokasi kode**: 
  - `dataku_page.dart` line 329 (via `WilayahService.getVillage()`)
  - `wilayah_service.dart` line 172

---

## 📊 Urutan Pemanggilan

### Skenario 1: Pertama Kali Load (Tidak Ada Cache)
1. ✅ **GET** `${authApiUrl}/biodata` (Primary)
2. ❌ Jika gagal: **GET** `${apiUrl}/all-citizens` (Fallback)
3. ✅ **GET** `${authApiUrl}/user/family-member/{nik}/documents` (Foto diri)
4. ⚠️ Jika nama wilayah kosong:
   - **GET** `${apiUrl}/provinces` (Parallel)
   - **GET** `${apiUrl}/districts/{code}` (Parallel)
   - **GET** `${apiUrl}/sub-districts/{code}` (Parallel)
   - **GET** `${apiUrl}/villages/{code}` (Parallel)

### Skenario 2: Load dari Cache (Sudah Ada Cache)
- ✅ Tidak ada API call sama sekali
- Data langsung ditampilkan dari cache lokal

### Skenario 3: Manual Refresh (Pull-to-Refresh)
- Sama seperti Skenario 1 (cache di-invalidate terlebih dahulu)

### Skenario 4: Setelah Edit Data
- Cache di-invalidate
- Sama seperti Skenario 1

---

## 🎯 Rekomendasi untuk Backend Cache

### Prioritas Tinggi (Sering Dipanggil)
1. **`${authApiUrl}/biodata`** ⭐⭐⭐⭐⭐
   - Endpoint utama yang selalu dipanggil
   - Response besar (biodata + informasi usaha + user)
   - **Rekomendasi**: Cache dengan TTL 1-2 jam atau berdasarkan perubahan data

2. **`${apiUrl}/api/citizens/{nik}`** ⭐⭐⭐⭐
   - Fallback endpoint
   - Response kecil (1 warga)
   - **Rekomendasi**: gunakan cache lokal + retry/backoff

### Prioritas Sedang (Conditional)
3. **`${authApiUrl}/user/family-member/{nik}/documents`** ⭐⭐⭐
   - Hanya dipanggil untuk foto diri
   - **Rekomendasi**: Cache dengan TTL 1-2 jam

### Prioritas Rendah (Wilayah - Jarang Berubah)
4. **`${apiUrl}/provinces`** ⭐⭐
5. **`${apiUrl}/districts/{code}`** ⭐⭐
6. **`${apiUrl}/sub-districts/{code}`** ⭐⭐
7. **`${apiUrl}/villages/{code}`** ⭐⭐
   - Data wilayah sangat jarang berubah
   - **Rekomendasi**: Cache dengan TTL sangat lama (24 jam - 7 hari) atau permanent cache dengan invalidation manual

---

## 🔍 Catatan Penting

1. **Client-side sudah ada cache**:
   - DatakuPage sudah menggunakan `PersistentCacheService` untuk cache lokal
   - Cache TTL: 30 hari
   - Cache di-invalidate saat ada perubahan data

2. **Wilayah Service sudah ada cache**:
   - `WilayahService` sudah punya cache sendiri (TTL 6 jam)
   - Menggunakan `CacheService` (in-memory) dan `PersistentCacheService` (persistent)

3. **Foto Diri sudah ada cache**:
   - `PendudukApiService.getFamilyMemberDocuments()` sudah punya cache
   - Cache TTL: sesuai `_cacheDuration` di service

4. **Optimasi yang sudah dilakukan**:
   - Parallel calls untuk wilayah (tidak sequential)
   - Cache check sebelum API call
   - Background refresh dihapus (tidak ada auto-refresh)

---

## 📝 Environment Variables

Pastikan environment variables berikut sudah di-set:
- `AUTH_API_URL`: Base URL untuk auth API
- `API_URL`: Base URL untuk main API
- `API_KEY`: API key untuk authentication

---

## ✅ Checklist untuk Backend

- [ ] Endpoint `/biodata` sudah ada cache
- [ ] Endpoint `/all-citizens` sudah ada cache
- [ ] Endpoint `/user/family-member/{nik}/documents` sudah ada cache
- [ ] Endpoint `/provinces` sudah ada cache
- [ ] Endpoint `/districts/{code}` sudah ada cache
- [ ] Endpoint `/sub-districts/{code}` sudah ada cache
- [ ] Endpoint `/villages/{code}` sudah ada cache
- [ ] Cache invalidation mechanism sudah ada (untuk update data)
- [ ] Cache headers (ETag, Last-Modified) sudah di-set (opsional)

---

**Dibuat**: $(date)
**File**: `kependudukan_app/lib/presentation/pages/dataku/dataku_page.dart`







