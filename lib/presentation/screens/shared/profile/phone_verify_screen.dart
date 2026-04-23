import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';

class PhoneVerifyScreen extends HookConsumerWidget {
  const PhoneVerifyScreen({super.key});

  static String _toE164(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('57') && digits.length == 12) return '+$digits';
    if (digits.length == 10) return '+57$digits';
    return '+$digits';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final rawPhone = profile?.phone ?? '';
    final phoneCtrl = useTextEditingController(
      text: rawPhone.replaceFirst(RegExp(r'^\+57'), ''),
    );
    final otpCtrl = useTextEditingController();
    final codeSent = useState(false);
    final isLoading = useState(false);
    final countdown = useState(0);

    useEffect(() {
      if (countdown.value <= 0) return null;
      final timer = Stream.periodic(const Duration(seconds: 1));
      final sub = timer.listen((_) {
        if (countdown.value > 0) countdown.value--;
      });
      return sub.cancel;
    }, [countdown.value > 0]);

    Future<void> sendCode() async {
      final phone = phoneCtrl.text.trim();
      if (phone.isEmpty) return;
      isLoading.value = true;
      try {
        final ds = ref.read(supabaseDatasourceProvider);
        await ds.sendPhoneOtp(_toE164(phone));
        codeSent.value = true;
        countdown.value = 60;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Código enviado a +57 $phone'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al enviar código: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> verify() async {
      final phone = phoneCtrl.text.trim();
      final token = otpCtrl.text.trim();
      if (phone.isEmpty || token.length < 6) return;
      isLoading.value = true;
      try {
        final ds = ref.read(supabaseDatasourceProvider);
        await ds.verifyPhoneOtp(_toE164(phone), token);
        await ref.read(authProvider.notifier).refreshProfile();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Teléfono verificado exitosamente!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Código incorrecto o expirado. Intenta de nuevo.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Verificar teléfono',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: LoadingOverlay(
        isLoading: isLoading.value,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Verifica tu número para que empleadores y trabajadores puedan contactarte con confianza.',
                        style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('Número de teléfono',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.surfaceDim),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('+57',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      enabled: !codeSent.value,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: '300 123 4567',
                        counterText: '',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (isLoading.value || countdown.value > 0)
                      ? null
                      : sendCode,
                  child: Text(
                    codeSent.value
                        ? (countdown.value > 0
                            ? 'Reenviar en ${countdown.value}s'
                            : 'Reenviar código')
                        : 'Enviar código SMS',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (codeSent.value) ...[
                const SizedBox(height: 32),
                Text('Código de verificación',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Ingresa el código de 6 dígitos que recibiste por SMS',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                TextField(
                  controller: otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 10,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '------',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLoading.value ? null : verify,
                    icon: const Icon(Icons.verified_rounded),
                    label: Text('Verificar teléfono',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
