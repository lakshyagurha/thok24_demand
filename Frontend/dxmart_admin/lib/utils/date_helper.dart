import 'package:intl/intl.dart';

class DateHelper {
  /// Parses an order datetime string into a DateTime object.
  /// Handles:
  /// - Standard ISO 8601 (yyyy-MM-dd HH:mm:ss or yyyy-MM-ddTHH:mm:ss)
  /// - Custom app format (dd-MM-yyyy hh:mm a)
  /// - Null or invalid inputs (returns DateTime.now() as a safe fallback)
  static DateTime parseOrderDate(dynamic dateVal) {
    if (dateVal == null) {
      return DateTime.now();
    }
    String dateStr = dateVal.toString().trim();
    if (dateStr.isEmpty || dateStr.toLowerCase() == "null") {
      return DateTime.now();
    }

    // 1. Try standard DateTime parsing (ISO-8601 / yyyy-MM-dd HH:mm:ss)
    DateTime? parsed = DateTime.tryParse(dateStr);
    if (parsed != null) {
      return parsed;
    }

    // 2. Try parsing dd-MM-yyyy hh:mm a
    try {
      return DateFormat("dd-MM-yyyy hh:mm a").parse(dateStr);
    } catch (_) {}

    // 3. Fallback: Split string manually for dd-MM-yyyy formatting variations
    try {
      final parts = dateStr.split(' ');
      if (parts.isNotEmpty) {
        final datePart = parts[0];
        final dateParts = datePart.split('-');
        if (dateParts.length == 3) {
          // Check if year is first (yyyy) or last (dd)
          if (dateParts[0].length == 4) {
            return DateTime(
              int.parse(dateParts[0]),
              int.parse(dateParts[1]),
              int.parse(dateParts[2]),
            );
          } else {
            return DateTime(
              int.parse(dateParts[2]),
              int.parse(dateParts[1]),
              int.parse(dateParts[0]),
            );
          }
        }
      }
    } catch (_) {}

    // 4. Return DateTime.now() if all else fails to prevent crashes
    return DateTime.now();
  }

  /// Formats a raw order datetime string into 'dd MMM yyyy' format safely.
  static String formatOrderDate(dynamic dateVal) {
    try {
      DateTime date = parseOrderDate(dateVal);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateVal?.toString() ?? '';
    }
  }
}
