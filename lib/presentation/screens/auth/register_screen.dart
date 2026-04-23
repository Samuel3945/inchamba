import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common_widgets.dart';

class RegisterScreen extends HookConsumerWidget {
  final String? role;
  const RegisterScreen({super.key, this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // Cédula OCR state
    final cedulaPreview = useState<Uint8List?>(null);
    final isOcrRunning = useState(false);
    final ocrData = useState<Map<String, dynamic>?>(null);
    final ocrError = useState<String?>(null);

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

    final cedulaScanned = ocrData.value != null &&
        (ocrData.value!['cedulaNumber'] as String?)?.isNotEmpty == true;

    Future<void> scanCedula(ImageSource source) async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      cedulaPreview.value = bytes;
      ocrData.value = null;
      ocrError.value = null;
      isOcrRunning.value = true;

      try {
        final ds = ref.read(supabaseDatasourceProvider);
        final result = await ds.ocrCedula(picked);
        if ((result['cedulaNumber'] as String?)?.isEmpty ?? true) {
          ocrError.value =
              'No se pudo leer el número de cédula. Intenta con una foto más clara.';
        } else {
          ocrData.value = result;
        }
      } catch (_) {
        ocrError.value =
            'No se pudo procesar la imagen. Asegúrate de tener buena iluminación y que la cédula esté completa.';
      } finally {
        isOcrRunning.value = false;
      }
    }

    void showSourceSheet() {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tomar foto con cámara'),
                onTap: () {
                  Navigator.pop(context);
                  scanCedula(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de la galería'),
                onTap: () {
                  Navigator.pop(context);
                  scanCedula(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    Future<void> register() async {
      if (!formKey.currentState!.validate()) return;
      if (!cedulaScanned) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes fotografiar tu cédula para continuar'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (!acceptedTerms.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes aceptar los términos y condiciones')),
        );
        return;
      }
      if (selectedCity.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona tu ciudad para continuar'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      isLoading.value = true;
      try {
        final ocr = ocrData.value!;

        // Parsear fecha DD/MM/YYYY → YYYY-MM-DD para Postgres
        String? isoDate;
        final dob = ocr['dateOfBirth'] as String?;
        if (dob != null && dob.isNotEmpty) {
          final parts = dob.split('/');
          if (parts.length == 3) isoDate = '${parts[2]}-${parts[1]}-${parts[0]}';
        }

        // Altura: solo dígitos
        final rawHeight = ocr['height'] as String?;
        final heightCm = rawHeight != null ? int.tryParse(rawHeight.replaceAll(RegExp(r'\D'), '')) : null;

        await ref.read(authProvider.notifier).signUp(
              email: emailCtrl.text.trim(),
              password: passwordCtrl.text,
              fullName: ocr['fullName'] as String? ?? '',
              city: selectedCity.value!,
              role: selectedRole.value,
              cedula: ocr['cedulaNumber'] as String,
              cedulaExtra: {
                'cedula_full_name': ocr['fullName'],
                'cedula_date_birth': isoDate,
                'cedula_place_birth': ocr['placeOfBirth'],
                'cedula_blood_type': ocr['bloodType'],
                'cedula_sex': ocr['sex'],
                'cedula_height_cm': heightCm,
              },
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
                'Te enviamos un enlace a ${emailCtrl.text.trim()}.\n\nRevisa tu bandeja de entrada (y spam) y haz clic en el enlace para activar tu cuenta.',
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
                        color: AppColors.textWhite),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu información se extrae automáticamente de tu cédula.',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 20),

                  // Role toggle
                  _RoleToggle(
                    selected: selectedRole.value,
                    onChanged: (val) => selectedRole.value = val,
                  ),
                  const SizedBox(height: 24),

                  // ── CÉDULA SECTION ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _SectionLabel(
                          icon: Icons.badge_outlined,
                          label: 'Cédula de Ciudadanía',
                          subtitle: 'Tu nombre y número se extraen automáticamente',
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/cedula-advisor'),
                        icon: const Icon(Icons.help_outline_rounded, size: 14),
                        label: Text(
                          'No tengo cédula',
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CedulaCard(
                    preview: cedulaPreview.value,
                    isScanning: isOcrRunning.value,
                    ocrData: ocrData.value,
                    error: ocrError.value,
                    onTap: showSourceSheet,
                  ),
                  const SizedBox(height: 24),

                  // ── CONTACT INFO ────────────────────────────────
                  _SectionLabel(
                    icon: Icons.person_outlined,
                    label: 'Datos de contacto',
                  ),
                  const SizedBox(height: 12),
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
                  _CityField(
                    city: selectedCity.value,
                    isDetecting: isDetectingCity.value,
                    onRetry: detectCity,
                    onCitySelected: (val) => selectedCity.value = val,
                  ),
                  const SizedBox(height: 24),

                  // ── PASSWORD ────────────────────────────────────
                  _SectionLabel(
                    icon: Icons.lock_outlined,
                    label: 'Contraseña',
                  ),
                  const SizedBox(height: 12),
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
                    obscureText: true,
                    validator: (val) =>
                        Validators.confirmPassword(val, passwordCtrl.text),
                    autofillHints: const [],
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: AppStrings.confirmPassword,
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Terms
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

                  // Register button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (cedulaScanned && !isLoading.value)
                          ? register
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.4),
                      ),
                      child: Text(
                        cedulaScanned
                            ? AppStrings.register
                            : 'Escanea tu cédula para continuar',
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

// ── City field (GPS-only, read-only) ──────────────────────────────────────────

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
                          Text('Ciudad',
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
                        Text('Ciudad',
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

// ── Cédula card ────────────────────────────────────────────────────────────────

class _CedulaCard extends StatelessWidget {
  final Uint8List? preview;
  final bool isScanning;
  final Map<String, dynamic>? ocrData;
  final String? error;
  final VoidCallback onTap;

  const _CedulaCard({
    required this.preview,
    required this.isScanning,
    required this.ocrData,
    required this.error,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isScanning) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: _cardDeco(context),
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Leyendo tu cédula...',
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (ocrData != null) {
      return Container(
        decoration: _cardDeco(context, success: true),
        child: Column(
          children: [
            // Preview thumbnail
            if (preview != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.memory(
                  preview!,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Cédula leída correctamente',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _OcrField(
                    icon: Icons.person_outlined,
                    label: 'Nombre',
                    value: ocrData!['fullName'] as String? ?? '—',
                  ),
                  const SizedBox(height: 8),
                  _OcrField(
                    icon: Icons.badge_outlined,
                    label: 'Cédula',
                    value: ocrData!['cedulaNumber'] as String? ?? '—',
                    mono: true,
                  ),
                  if ((ocrData!['dateOfBirth'] as String?) != null) ...[
                    const SizedBox(height: 8),
                    _OcrField(
                      icon: Icons.cake_outlined,
                      label: 'Nacimiento',
                      value: ocrData!['dateOfBirth'] as String,
                    ),
                  ],
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: onTap,
                    child: Text(
                      'Re-escanear cédula',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Empty state / error
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: _cardDeco(context, hasError: error != null),
        child: Column(
          children: [
            if (preview != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(preview!, height: 100, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
            ],
            Icon(
              error != null ? Icons.error_outline : Icons.badge_outlined,
              size: 44,
              color: error != null ? AppColors.error : AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              error ?? 'Toca para fotografiar el\nfrente de tu cédula',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: error != null ? AppColors.error : AppColors.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Intentar de nuevo'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDeco(BuildContext context,
      {bool success = false, bool hasError = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = success
        ? AppColors.success.withValues(alpha: 0.5)
        : hasError
            ? AppColors.error.withValues(alpha: 0.4)
            : AppColors.surfaceDim;
    return BoxDecoration(
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor, width: 1.5),
    );
  }
}

class _OcrField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  const _OcrField(
      {required this.icon,
      required this.label,
      required this.value,
      this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text('$label: ',
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted)),
        Expanded(
          child: Text(
            value,
            style: mono
                ? GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()])
                : GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  const _SectionLabel(
      {required this.icon, required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            if (subtitle != null)
              Text(subtitle!,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ],
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
  const _RoleCard(
      {required this.label,
      required this.subtitle,
      required this.icon,
      required this.selected,
      required this.onTap});

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
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textMuted),
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
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
