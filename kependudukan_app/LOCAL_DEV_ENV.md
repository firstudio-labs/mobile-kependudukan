# Konfigurasi `.env` untuk Local Development (Flutter)

Project Flutter ini memakai `flutter_dotenv` dan membaca file `.env` lewat `lib/main.dart`.

## Variabel yang dipakai

- `AUTH_API_URL`: Base URL Laravel (untuk login + endpoint `user/*`).
- `API_URL`: Base URL Go API (untuk endpoint scalable `/api/v2/*`).
- `API_KEY`: API key untuk Go API (dan beberapa endpoint Laravel yang proxy).
- `STORAGE_URL`: (opsional) base URL storage untuk gambar/file.

## Contoh `.env` (Android Emulator)

Android emulator **tidak bisa** akses laptop via `localhost`. Gunakan `10.0.2.2`.

```env
AUTH_API_URL=http://10.0.2.2:8000/api
API_URL=http://10.0.2.2:8080
API_KEY=ISI_API_KEY_KAMU
STORAGE_URL=http://10.0.2.2:8000/storage
```

## Contoh `.env` (iOS Simulator)

iOS simulator bisa pakai `localhost`.

```env
AUTH_API_URL=http://localhost:8000/api
API_URL=http://localhost:8080
API_KEY=ISI_API_KEY_KAMU
STORAGE_URL=http://localhost:8000/storage
```

## Contoh `.env` (Device fisik)

Pakai IP LAN laptop kamu (mis: `192.168.1.10`).

```env
AUTH_API_URL=http://192.168.1.10:8000/api
API_URL=http://192.168.1.10:8080
API_KEY=ISI_API_KEY_KAMU
STORAGE_URL=http://192.168.1.10:8000/storage
```

## Catatan port

- Laravel biasanya jalan di `:8000` (`php artisan serve`)
- Go API sesuaikan dengan yang kamu jalankan (misal `:8080` atau port lain yang ada di `.env` Go)


