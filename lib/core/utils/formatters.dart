import 'package:flutter/material.dart';
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
    final entry = AppConstants.jobCategories[nameOrKey];
    if (entry != null) {
      // Strip emoji prefix if present (e.g. "🏗️ Construcción" → "Construcción")
      final parts = entry.split(' ');
      return parts.length > 1 ? parts.sublist(1).join(' ') : entry;
    }
    return nameOrKey;
  }

  static String categoryEmoji(String? iconOrKey) {
    if (iconOrKey == null || iconOrKey.isEmpty) return '📋';
    if (!AppConstants.jobCategories.containsKey(iconOrKey)) return iconOrKey;
    final label = AppConstants.jobCategories[iconOrKey] ?? '📋';
    return label.split(' ').first;
  }

  static IconData categoryIconData(String? key) {
    switch (key) {
      case 'construccion': return Icons.construction_rounded;
      case 'limpieza': return Icons.cleaning_services_rounded;
      case 'jardineria': return Icons.yard_rounded;
      case 'mudanzas': return Icons.local_shipping_rounded;
      case 'pintura': return Icons.format_paint_rounded;
      case 'plomeria': return Icons.plumbing_rounded;
      case 'electricidad': return Icons.electric_bolt_rounded;
      case 'cocina': return Icons.restaurant_rounded;
      case 'mesero': return Icons.room_service_rounded;
      case 'cuidado_personas': return Icons.child_care_rounded;
      case 'conduccion': return Icons.directions_car_rounded;
      case 'reparaciones': return Icons.handyman_rounded;
      case 'tecnologia': return Icons.computer_rounded;
      case 'diseno': return Icons.palette_rounded;
      case 'ensenanza': return Icons.school_rounded;
      case 'ventas': return Icons.store_rounded;
      case 'eventos': return Icons.celebration_rounded;
      case 'seguridad': return Icons.security_rounded;
      case 'agricultura': return Icons.grass_rounded;
      default: return Icons.work_outline_rounded;
    }
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String rating(double value) {
    return value.toStringAsFixed(1);
  }
}
