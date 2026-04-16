import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/job_provider.dart';

class PaymentScreen extends HookConsumerWidget {
  final String jobPostId;

  const PaymentScreen({super.key, required this.jobPostId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobPostId));
    final isPaying = useState(false);
    final paymentConfirmed = useState(false);
    final timeoutReached = useState(false);
    final channelRef = useRef<RealtimeChannel?>(null);
    final pollingTimerRef = useRef<Timer?>(null);
    final timeoutTimerRef = useRef<Timer?>(null);

    void onPaymentConfirmed() {
      paymentConfirmed.value = true;
      channelRef.value?.unsubscribe();
      pollingTimerRef.value?.cancel();
      timeoutTimerRef.value?.cancel();
    }

    Future<void> checkPaymentStatus() async {
      final ds = ref.read(supabaseDatasourceProvider);
      final escrow = await ds.getEscrowByJobPost(jobPostId);
      if (escrow != null && escrow['status'] == 'held') {
        onPaymentConfirmed();
      }
    }

    void startListening() {
      final ds = ref.read(supabaseDatasourceProvider);

      // Realtime subscription
      channelRef.value = ds.subscribeToEscrow(jobPostId, (data) {
        if (data['status'] == 'held') {
          onPaymentConfirmed();
        }
      });

      // Polling fallback
      pollingTimerRef.value = Timer.periodic(
        const Duration(seconds: AppConstants.paymentPollingSeconds),
        (_) => checkPaymentStatus(),
      );

      // Timeout
      timeoutTimerRef.value = Timer(
        const Duration(minutes: AppConstants.paymentTimeoutMinutes),
        () => timeoutReached.value = true,
      );
    }

    Future<void> openBoldPayment(double amount) async {
      final ds = ref.read(supabaseDatasourceProvider);
      final userId = ds.currentUserId!;

      // Create escrow transaction
      await ds.createEscrowTransaction({
        'job_post_id': jobPostId,
        'employer_id': userId,
        'amount': amount,
        'status': 'pending',
        'bold_reference': 'JOB_$jobPostId',
      });

      isPaying.value = true;
      startListening();

      // Open Bold payment link
      final boldUrl = '${AppConstants.boldPaymentUrl}?amount=${amount.toInt()}&reference=JOB_$jobPostId';
      final uri = Uri.parse(boldUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    useEffect(() {
      return () {
        channelRef.value?.unsubscribe();
        pollingTimerRef.value?.cancel();
        timeoutTimerRef.value?.cancel();
      };
    }, []);

    if (paymentConfirmed.value) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, size: 60, color: AppColors.success),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pago confirmado',
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu oferta ha sido publicada exitosamente. El dinero está seguro en escrow.',
                    style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/employer/offers'),
                      child: const Text('Ver mis ofertas'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return jobAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (job) {
        final totalAmount = job.pay * job.workersNeeded;

        if (isPaying.value) {
          return Scaffold(
            appBar: AppBar(title: const Text('Procesando pago')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.waitingPayment,
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No cierres esta pantalla',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                    ),
                    if (timeoutReached.value) ...[
                      const SizedBox(height: 24),
                      Text(
                        'El pago está tardando más de lo esperado.',
                        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.warning),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          timeoutReached.value = false;
                          timeoutTimerRef.value = Timer(
                            const Duration(minutes: AppConstants.paymentTimeoutMinutes),
                            () => timeoutReached.value = true,
                          );
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: checkPaymentStatus,
                      child: const Text(AppStrings.alreadyPaid),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Pago y escrow')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen de pago',
                  style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                // Summary card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _PayRow(label: 'Oferta', value: job.title),
                      const Divider(height: 24),
                      _PayRow(label: 'Paga por trabajador', value: Formatters.currency(job.pay)),
                      _PayRow(label: 'Trabajadores necesarios', value: '${job.workersNeeded}'),
                      const Divider(height: 24),
                      _PayRow(
                        label: 'Total a depositar',
                        value: Formatters.currency(totalAmount),
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Escrow explanation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.escrow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.escrow.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline, color: AppColors.escrow, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppStrings.escrowExplanation,
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.escrow, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => openBoldPayment(totalAmount),
                    icon: const Icon(Icons.payment_rounded),
                    label: Text(
                      '${AppStrings.payWithBold} ${Formatters.currency(totalAmount)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _PayRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isBold ? 16 : 14,
              color: isBold ? null : AppColors.textMuted,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
