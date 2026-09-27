## Smoke Testing - mobile-kependudukan

File `test_api_endpoints.dart` adalah skrip **pure Dart** untuk mengetes endpoint yang dipakai aplikasi (tanpa menarik `/all-citizens`).

### Menjalankan

Set env di terminal:

```bash
export AUTH_API_URL="https://<laravel-auth-host>"
export API_URL="https://<go-api-host>"
export API_KEY="<api-key>"
```

Jalankan:

```bash
cd mobile-kependudukan
dart run test_api_endpoints.dart
```

Catatan:

- Script ini tidak memakai `flutter_dotenv`/`package:http` supaya bisa dijalankan di mana saja.


