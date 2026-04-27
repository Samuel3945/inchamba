import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/profile.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class RegisterScreen extends HookConsumerWidget {
  final String? role;
  const RegisterScreen({super.key, this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textWhite : AppColors.textDark;
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final emailCtrl = useTextEditingController();
    final passwordCtrl = useTextEditingController();
    final confirmPasswordCtrl = useTextEditingController();

    final selectedCity = useState<String?>(null);
    final isDetectingCity = useState(false);
    final selectedRole = useState<String>(
      role == Profile.roleEmployer ? Profile.roleEmployer : Profile.roleWorker,
    );
    final acceptedTerms = useState(false);
    final isLoading = useState(false);
    final obscurePassword = useState(true);
    final obscureConfirm = useState(true);

    Future<void> detectCity() async {
      isDetectingCity.value = true;
      try {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
        ).timeout(const Duration(seconds: 12));
        final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final matched = AppConstants.matchCity(marks.first.locality) ??
              AppConstants.matchCity(marks.first.subAdministrativeArea) ??
              AppConstants.matchCity(marks.first.administrativeArea);
          if (matched != null) selectedCity.value = matched;
        }
      } catch (_) {
        // location not available — user selects manually
      } finally {
        isDetectingCity.value = false;
      }
    }

    useEffect(() {
      detectCity();
      return null;
    }, const []);

    Future<void> register() async {
      if (!formKey.currentState!.validate()) return;
      if (!acceptedTerms.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes aceptar los términos y condiciones')),
        );
        return;
      }

      isLoading.value = true;
      try {
        await ref.read(authProvider.notifier).signUp(
              email: emailCtrl.text.trim(),
              password: passwordCtrl.text,
              city: selectedCity.value ?? '',
              role: selectedRole.value,
            );

        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.mark_email_read_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text('Verifica tu correo',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ],
              ),
              content: Text(
                'Te enviamos un enlace a ${emailCtrl.text.trim()}.\n\nRevisa tu bandeja de entrada (y spam) y haz clic en el enlace para activar tu cuenta.\n\nDespués podrás agregar tu cédula y foto de perfil desde la app.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/login');
                  },
                  child: const Text('Ir a iniciar sesión'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(ref.read(authProvider).error ?? 'Error al registrarse')),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: LoadingOverlay(
        isLoading: isLoading.value,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Crear cuenta',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Regístrate con tu correo. Agregarás cédula y foto dentro de la app.',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),

                  // ── Info banner ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Para hacer ofertas o postularte a trabajos necesitarás verificar tu cédula y subir una foto de perfil. Puedes hacerlo en cualquier momento desde tu perfil.',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Role toggle ─────────────────────────────────
                  _RoleToggle(
                    selected: selectedRole.value,
                    onChanged: (val) => selectedRole.value = val,
                  ),
                  const SizedBox(height: 24),

                  // ── Email ───────────────────────────────────────
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    decoration: const InputDecoration(
                      labelText: AppStrings.email,
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── City (optional GPS auto-detect) ─────────────
                  _CityField(
                    city: selectedCity.value,
                    isDetecting: isDetectingCity.value,
                    onRetry: detectCity,
                    onCitySelected: (val) => selectedCity.value = val,
                  ),
                  const SizedBox(height: 24),

                  // ── Password ────────────────────────────────────
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword.value,
                    validator: Validators.password,
                    autofillHints: const [],
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: AppStrings.password,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            obscurePassword.value = !obscurePassword.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordCtrl,
                    obscureText: obscureConfirm.value,
                    validator: (val) =>
                        Validators.confirmPassword(val, passwordCtrl.text),
                    autofillHints: const [],
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: AppStrings.confirmPassword,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            obscureConfirm.value = !obscureConfirm.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Terms ───────────────────────────────────────
                  Row(
                    children: [
                      Checkbox(
                        value: acceptedTerms.value,
                        onChanged: (val) =>
                            acceptedTerms.value = val ?? false,
                        activeColor: AppColors.primary,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              acceptedTerms.value = !acceptedTerms.value,
                          child: Text(
                            AppStrings.acceptTerms,
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: AppColors.textLight),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Register button ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading.value ? null : register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        AppStrings.register,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.alreadyHaveAccount,
                        style: GoogleFonts.poppins(
                            color: AppColors.textLight, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(AppStrings.login),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── City field ────────────────────────────────────────────────────────────────
class _CityField extends StatelessWidget {
  final String? city;
  final bool isDetecting;
  final VoidCallback onRetry;
  final ValueChanged<String?> onCitySelected;
  const _CityField({
    required this.city,
    required this.isDetecting,
    required this.onRetry,
    required this.onCitySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: city != null
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.surfaceDim,
        ),
      ),
      child: isDetecting
          ? Row(
              children: [
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('Detectando tu ciudad...',
                    style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)),
              ],
            )
          : city != null
              ? Row(
                  children: [
                    const Icon(Icons.gps_fixed_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ciudad (opcional)',
                              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
                          Text(city!,
                              style: GoogleFonts.poppins(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text('Cambiar',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary)),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_city_outlined, color: AppColors.textMuted, size: 20),
                        const SizedBox(width: 8),
                        Text('Ciudad (opcional)',
                            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.gps_fixed_rounded, size: 14),
                          label: Text('GPS', style: GoogleFonts.poppins(fontSize: 12)),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: null,
                        isExpanded: true,
                        hint: Text('Selecciona tu ciudad',
                            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted)),
                        dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        items: AppConstants.colombianCities
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, style: GoogleFonts.poppins(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: onCitySelected,
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Role toggle ────────────────────────────────────────────────────────────────
class _RoleToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _RoleToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleCard(
            label: 'Trabajador',
            subtitle: 'Busca trabajos',
            icon: Icons.construction_rounded,
            selected: selected == Profile.roleWorker,
            onTap: () => onChanged(Profile.roleWorker),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleCard(
            label: 'Empleador',
            subtitle: 'Publica ofertas',
            icon: Icons.business_rounded,
            selected: selected == Profile.roleEmployer,
            onTap: () => onChanged(Profile.roleEmployer),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkBorder
                    : AppColors.surfaceDim,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textWhite
                        : AppColors.textDark,
              ),
            ),
            Text(subtitle,
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
