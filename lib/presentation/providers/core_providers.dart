import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../core/constants/app_constants.dart';
import '../../main.dart' show supabaseReady;

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!supabaseReady) {
    throw StateError(
      'Supabase not initialized. Check --dart-define flags or network.',
    );
  }
  return Supabase.instance.client;
});

final supabaseDatasourceProvider = Provider<SupabaseDatasource>((ref) {
  return SupabaseDatasource(ref.watch(supabaseClientProvider));
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.n8nBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));
  return dio;
});
