// OWNER: A6.
import 'package:intl/intl.dart';

/// Formats a backup timestamp in the reader's language and digits.
///
/// `AppFormatters` covers money, quantities and percentages but not dates
/// (a change request in the A6 report asks for it); until then the digit
/// choice is applied here so a date doesn't show Arabic-Indic digits on a
/// screen where every other number is Latin.
String formatBackupTimestamp(
  DateTime timestamp, {
  required String languageCode,
  required bool latinDigits,
}) {
  final local = timestamp.toLocal();
  String text;
  try {
    text = DateFormat.yMMMd(languageCode).add_jm().format(local);
  } on Object {
    // Date symbols for the locale aren't loaded (a bare test harness).
    text = DateFormat.yMMMd().add_jm().format(local);
  }
  return latinDigits ? toLatinDigits(text) : text;
}

/// Whole days between [from] and [to], used by the backup reminder.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime(from.toLocal().year, from.toLocal().month, from.toLocal().day);
  final b = DateTime(to.toLocal().year, to.toLocal().month, to.toLocal().day);
  return b.difference(a).inDays;
}

/// ٠١٢ → 012. Arabic locale data formats dates with Arabic-Indic digits;
/// many shops set the app to Latin digits (TECHNICAL_STRUCTURE §9).
String toLatinDigits(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + rune - 0x06F0);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
