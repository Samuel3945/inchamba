import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/wallet_provider.dart';

String _wompiIntegrityHash(String reference, int amountCents, String integrityKey) {
  final raw = '$reference${amountCents}COP$integrityKey';
  return sha256.convert(utf8.encode(raw)).toString();
}

// $50 platform fee per each $50,000 recharged (0.1%)
double _platformFee(double amount) => ((amount / 50000).ceil() * 50).toDouble();

class WalletScreen extends HookConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final txAsync = ref.watch(walletTransactionsProvider);
    final liveBalance = useState<double?>(null);
    final channelRef = useRef<RealtimeChannel?>(null);

    useEffect(() {
      final ds = ref.read(supabaseDatasourceProvider);
      final userId = ds.currentUserId;
      if (userId == null) return null;
      channelRef.value = ds.subscribeToWalletBalance(userId, (balance) {
        liveBalance.value = balance;
        ref.invalidate(walletBalanceProvider);
      });
      return () => channelRef.value?.unsubscribe();
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Text('Mi Saldo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletBalanceProvider);
          ref.invalidate(walletTransactionsProvider);
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de saldo
              balanceAsync.when(
                loading: () => _BalanceCard(balance: liveBalance.value ?? 0, loading: true),
                error: (_, _) => _BalanceCard(balance: 0),
                data: (balance) => _BalanceCard(balance: liveBalance.value ?? balance),
              ),
              const SizedBox(height: 16),
              // Botón recargar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTopUpSheet(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'Recargar saldo',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Movimientos',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              txAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Text('Error: $e'),
                data: (txs) {
                  if (txs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Aún no hay movimientos',
                          style: GoogleFonts.poppins(color: AppColors.textMuted),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: txs.map((tx) => _TxTile(tx: tx)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTopUpSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _TopUpSheet(onConfirm: (amount) async {
        Navigator.pop(ctx);
        await _launchTopUp(context, ref, amount);
      }),
    );
  }

  Future<void> _launchTopUp(BuildContext context, WidgetRef ref, double amount) async {
    final ds = ref.read(supabaseDatasourceProvider);
    final fee = _platformFee(amount);
    final totalCharge = amount + fee;
    final totalCents = (totalCharge * 100).round();

    final tx = await ds.createWalletTopup(
      reference: 'TOPUP_${ds.currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
    );

    final reference = tx['reference'] as String;
    final hash = _wompiIntegrityHash(reference, totalCents, AppConstants.wompiIntegrityKey);
    final uri = Uri.parse(AppConstants.wompiCheckoutUrl).replace(queryParameters: {
      'public-key': AppConstants.wompiPublicKey,
      'currency': 'COP',
      'amount-in-cents': '$totalCents',
      'reference': reference,
      'signature:integrity': hash,
    });

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    ref.invalidate(walletTransactionsProvider);
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final bool loading;
  const _BalanceCard({required this.balance, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saldo disponible',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          loading
              ? const SizedBox(
                  height: 40,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  Formatters.currency(balance),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            'El saldo se descuenta al publicar ofertas',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final type = tx['type'] as String;
    final amount = (tx['amount'] as num).toDouble();
    final status = tx['status'] as String;
    final description = tx['description'] as String? ?? type;
    final createdAt = DateTime.parse(tx['created_at'] as String);

    final isCredit = type == 'topup' || type == 'refund';
    final isPending = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.success : AppColors.primary).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? AppColors.success : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  Formatters.timeAgo(createdAt),
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'}${Formatters.currency(amount)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isCredit ? AppColors.success : AppColors.primary,
                ),
              ),
              if (isPending)
                Text(
                  'Pendiente',
                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.warning),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopUpSheet extends StatefulWidget {
  final void Function(double amount) onConfirm;
  const _TopUpSheet({required this.onConfirm});

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  double? _selected;
  final _ctrl = TextEditingController();
  final _presets = [50000.0, 100000.0, 200000.0, 500000.0];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double? get _amount {
    if (_selected != null) return _selected;
    final v = double.tryParse(_ctrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    return (v != null && v > 0) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '¿Cuánto quieres recargar?',
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presets.map((p) {
              final selected = _selected == p;
              return GestureDetector(
                onTap: () => setState(() {
                  _selected = selected ? null : p;
                  _ctrl.clear();
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    Formatters.currency(p),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Otro monto',
              prefixText: '\$ ',
            ),
            onChanged: (_) => setState(() => _selected = null),
          ),
          if (_amount != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _FeeRow(label: 'Acreditado a tu saldo', value: Formatters.currency(_amount!)),
                  const SizedBox(height: 6),
                  _FeeRow(label: 'Tarifa Inchamba', value: '+ ${Formatters.currency(_platformFee(_amount!))}', muted: true),
                  const Divider(height: 16),
                  _FeeRow(
                    label: 'Total a pagar',
                    value: Formatters.currency(_amount! + _platformFee(_amount!)),
                    bold: true,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _amount != null ? () => widget.onConfirm(_amount!) : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(
                _amount != null
                    ? 'Pagar ${Formatters.currency(_amount! + _platformFee(_amount!))}'
                    : 'Selecciona un monto',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  final bool bold;

  const _FeeRow({required this.label, required this.value, this.muted = false, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: muted ? AppColors.textMuted : null,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: muted ? AppColors.textMuted : (bold ? AppColors.primary : null),
          ),
        ),
      ],
    );
  }
}
