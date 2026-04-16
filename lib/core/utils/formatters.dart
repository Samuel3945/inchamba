import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../constants/app_constants.dart';

class Formatters {
  Formatters._();

  static String currency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String timeAgo(DateTime date) {
    return timeago.format(date, locale: 'es');
  }

  static String date(DateTime date) {
    return DateFormat('dd MMM yyyy', 'es').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a', 'es').format(date);
  }

  static String time(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String payType(String type) {
    return AppConstants.payTypes[type] ?? type;
  }

  static String categoryLabel(String? nameOrKey) {
    if (nameOrKey == null || nameOrKey.isEmpty) return 'Otro';
    return AppConstants.jobCategories[nameOrKey] ?? nameOrKey;
  }

  static String categoryEmoji(String? iconOrKey) {
    if (iconOrKey == null || iconOrKey.isEmpty) return '📋';
    // If the value is already an emoji/icon from DB, return it as-is.
    if (!AppConstants.jobCategories.containsKey(iconOrKey)) return iconOrKey;
    final label = AppConstants.jobCategories[iconOrKey] ?? '📋';
    return label.split(' ').first;
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String rating(double value) {
    return value.toStringAsFixed(1);
  }
}
