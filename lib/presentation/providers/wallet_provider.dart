import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'core_providers.dart';

final walletBalanceProvider = FutureProvider<double>((ref) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return 0;
  return await ds.getWalletBalance(userId);
});

final walletTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final ds = ref.watch(supabaseDatasourceProvider);
  final userId = ds.currentUserId;
  if (userId == null) return [];
  return await ds.getWalletTransactions(userId);
});
