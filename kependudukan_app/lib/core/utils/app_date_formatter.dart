class AppDateFormatter {
  static const List<String> _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des'
  ];

  /// Mengonversi input (String atau DateTime) ke DateTime local device
  static DateTime? parseToLocal(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input.toLocal();

    final str = input.toString().trim();
    if (str.isEmpty || str == '-' || str == 'null') return null;

    try {
      return DateTime.parse(str).toLocal();
    } catch (_) {
      try {
        if (str.contains('/')) {
          final parts = str.split('/');
          if (parts.length == 3) {
            final p0 = int.tryParse(parts[0]);
            final p1 = int.tryParse(parts[1]);
            final p2 = int.tryParse(parts[2]);
            if (p0 != null && p1 != null && p2 != null) {
              if (parts[2].length == 4) {
                // dd/MM/yyyy
                return DateTime(p2, p1, p0).toLocal();
              } else if (parts[0].length == 4) {
                // yyyy/MM/dd
                return DateTime(p0, p1, p2).toLocal();
              }
            }
          }
        }
      } catch (_) {}
      return null;
    }
  }

  /// Menentukan zona waktu Indonesia berdasarkan offset local device
  static String getTimezoneSuffix(DateTime dt) {
    final offsetHours = dt.timeZoneOffset.inHours;
    if (offsetHours == 8) return 'WITA';
    if (offsetHours == 9) return 'WIT';
    return 'WIB';
  }

  /// Format lengkap tanggal dan waktu: "29 Oktober 2026, 11:22 WIB"
  static String formatDateTime(dynamic input, {bool showTimezone = true}) {
    final dt = parseToLocal(input);
    if (dt == null) return input?.toString() ?? '-';

    final day = dt.day.toString().padLeft(2, '0');
    final month = _months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final tz = showTimezone ? ' ${getTimezoneSuffix(dt)}' : '';

    return '$day $month $year, $hour:$minute$tz';
  }

  /// Format ringkas tanggal dan waktu: "29 Okt 2026, 11:22 WIB"
  static String formatDateTimeShort(dynamic input, {bool showTimezone = true}) {
    final dt = parseToLocal(input);
    if (dt == null) return input?.toString() ?? '-';

    final day = dt.day.toString().padLeft(2, '0');
    final month = _shortMonths[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final tz = showTimezone ? ' ${getTimezoneSuffix(dt)}' : '';

    return '$day $month $year, $hour:$minute$tz';
  }

  /// Format tanggal saja: "29 Oktober 2026"
  static String formatDate(dynamic input) {
    final dt = parseToLocal(input);
    if (dt == null) return input?.toString() ?? '-';

    final day = dt.day.toString().padLeft(2, '0');
    final month = _months[dt.month - 1];
    final year = dt.year;

    return '$day $month $year';
  }

  /// Format tanggal ringkas saja: "29 Okt 2026"
  static String formatDateShort(dynamic input) {
    final dt = parseToLocal(input);
    if (dt == null) return input?.toString() ?? '-';

    final day = dt.day.toString().padLeft(2, '0');
    final month = _shortMonths[dt.month - 1];
    final year = dt.year;

    return '$day $month $year';
  }

  /// Format jam saja: "11:22 WIB"
  static String formatTime(dynamic input, {bool showTimezone = true}) {
    final dt = parseToLocal(input);
    if (dt == null) return input?.toString() ?? '-';

    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final tz = showTimezone ? ' ${getTimezoneSuffix(dt)}' : '';

    return '$hour:$minute$tz';
  }

  /// Mendapatkan nama bulan (1-12)
  static String getMonthName(int month) {
    if (month >= 1 && month <= 12) {
      return _months[month - 1];
    }
    return '';
  }

  /// Mendapatkan singkatan nama bulan (1-12)
  static String getMonthShort(int month) {
    if (month >= 1 && month <= 12) {
      return _shortMonths[month - 1];
    }
    return '';
  }
}
