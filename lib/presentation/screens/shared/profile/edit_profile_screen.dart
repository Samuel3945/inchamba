import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';

class EditProfileScreen extends HookConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bioCtrl = useTextEditingController(text: profile.bio ?? '');
    final initialCity = profile.city.trim();
    final selectedCity = useState<String?>(
      AppConstants.colombianCities.contains(initialCity) ? initialCity : null,
    );
    final isDetectingCity = useState(false);
    final selectedCategories = useState<List<String>>(List.from(profile.categories));
    final isLoading = useState(false);

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
        // location not available
      } finally {
        isDetectingCity.value = false;
      }
    }

    Future<void> save() async {
      isLoading.value = true;
      try {
        await ref.read(authProvider.notifier).updateProfile({
          'city': selectedCity.value ?? profile.city,
          'bio': bioCtrl.text.trim().isEmpty ? null : bioCtrl.text.trim(),
          'skill_categories': selectedCategories.value,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil actualizado'), backgroundColor: AppColors.success),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> requestCorrection() async {
      final name = Uri.encodeComponent(profile.fullName);
      final cedula = Uri.encodeComponent(profile.cedula ?? 'No registrada');
      final body = Uri.encodeComponent(
        'Hola equipo Inchamba,\n\n'
        'Solicito la corrección de mis datos personales.\n\n'
        'Nombre actual: ${profile.fullName}\n'
        'Cédula actual: ${profile.cedula ?? "No registrada"}\n\n'
        'Datos a corregir:\n'
        '[Describe aquí qué dato está incorrecto y cuál es el valor correcto]\n\n'
        'Adjunto documento de soporte si es necesario.\n\n'
        'Gracias.',
      );
      final uri = Uri.parse(
        'mailto:soporte@inchamba.co'
        '?subject=Corrección de datos - $name ($cedula)'
        '&body=$body',
      );
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // ignora si no hay cliente de correo — el usuario verá soporte@inchamba.co
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.editProfile,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: isLoading.value ? null : save,
            child: isLoading.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text(AppStrings.save),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: isLoading.value,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Datos de identidad (solo lectura) ──────────────
              _ReadOnlySection(
                title: 'Datos de identidad',
                subtitle: 'Extraídos de tu cédula. Para corregirlos envía una solicitud.',
                children: [
                  _LockedField(
                    icon: Icons.person_outlined,
                    label: 'Nombre completo',
                    value: profile.fullName,
                  ),
                  const SizedBox(height: 12),
                  _LockedField(
                    icon: Icons.badge_outlined,
                    label: 'Cédula de Ciudadanía',
                    value: profile.cedula ?? 'No registrada',
                    verified: profile.hasCedula,
                  ),
                  if (profile.cedulaSex != null) ...[
                    const SizedBox(height: 12),
                    _LockedField(
                      icon: Icons.wc_outlined,
                      label: 'Sexo',
                      value: profile.cedulaSex == 'M' ? 'Masculino' : 'Femenino',
                    ),
                  ],
                  if (profile.cedulaDateBirth != null) ...[
                    const SizedBox(height: 12),
                    _LockedField(
                      icon: Icons.cake_outlined,
                      label: 'Fecha de nacimiento',
                      value: '${profile.cedulaDateBirth!.day.toString().padLeft(2,'0')}/${profile.cedulaDateBirth!.month.toString().padLeft(2,'0')}/${profile.cedulaDateBirth!.year}',
                    ),
                  ],
                  if (profile.cedulaPlaceBirth != null) ...[
                    const SizedBox(height: 12),
                    _LockedField(
                      icon: Icons.location_city_outlined,
                      label: 'Lugar de nacimiento',
                      value: profile.cedulaPlaceBirth!,
                    ),
                  ],
                  if (profile.cedulaBloodType != null) ...[
                    const SizedBox(height: 12),
                    _LockedField(
                      icon: Icons.bloodtype_outlined,
                      label: 'Tipo de sangre',
                      value: profile.cedulaBloodType!,
                    ),
                  ],
                  if (profile.cedulaHeightCm != null) ...[
                    const SizedBox(height: 12),
                    _LockedField(
                      icon: Icons.height_outlined,
                      label: 'Estatura',
                      value: '${profile.cedulaHeightCm} cm',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: requestCorrection,
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: Text(
                    'Solicitar corrección de datos',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Teléfono (solo lectura — se gestiona con botones) ──
              Text('Teléfono',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _PhoneReadOnlyCard(
                phone: profile.phone,
                isVerified: profile.phoneVerified,
                onAddOrChange: () => context.push('/verify-phone'),
                onRevoke: () => _confirmRevokePhone(context, ref),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.surfaceDim),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDetectingCity.value
                          ? Icons.gps_not_fixed_rounded
                          : Icons.gps_fixed_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isDetectingCity.value
                          ? Row(
                              children: [
                                const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 10),
                                Text('Detectando ciudad...',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13, color: AppColors.textMuted)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ciudad',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11, color: AppColors.textMuted)),
                                Text(
                                  selectedCity.value ?? profile.city,
                                  style: GoogleFonts.poppins(
                                      fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                    ),
                    TextButton.icon(
                      onPressed: isDetectingCity.value ? null : detectCity,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text('Actualizar',
                          style: GoogleFonts.poppins(fontSize: 12)),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioCtrl,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Biografía (opcional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              // ── Categorías ──────────────────────────────────────
              Text('Categorías de trabajo',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.jobCategories.entries.map((e) {
                  final isSelected = selectedCategories.value.contains(e.key);
                  return FilterChip(
                    selected: isSelected,
                    label: Text(e.value),
                    onSelected: (selected) {
                      final list = List<String>.from(selectedCategories.value);
                      if (selected) {
                        list.add(e.key);
                      } else {
                        list.remove(e.key);
                      }
                      selectedCategories.value = list;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Phone read-only card ──────────────────────────────────────────────────────
class _PhoneReadOnlyCard extends StatelessWidget {
  final String phone;
  final bool isVerified;
  final VoidCallback onAddOrChange;
  final VoidCallback onRevoke;

  const _PhoneReadOnlyCard({
    required this.phone,
    required this.isVerified,
    required this.onAddOrChange,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhone = phone.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVerified
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.surfaceDim,
        ),
      ),
      child: Column(
        children: [
          // Estado actual
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isVerified
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isVerified ? Icons.phone_enabled_rounded : Icons.phone_outlined,
                  color: isVerified ? AppColors.success : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          hasPhone ? phone : 'Sin número registrado',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: hasPhone
                                ? (isDark ? AppColors.textWhite : AppColors.textDark)
                                : AppColors.textMuted,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, size: 15, color: AppColors.success),
                        ],
                      ],
                    ),
                    Text(
                      isVerified
                          ? 'Verificado'
                          : hasPhone
                              ? 'Sin verificar'
                              : 'Necesario para aplicar a trabajos',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: isVerified ? AppColors.success : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Botón principal
              if (!isVerified)
                GestureDetector(
                  onTap: onAddOrChange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasPhone ? 'Verificar' : 'Agregar',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),

          // Acciones secundarias
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isVerified) ...[
                GestureDetector(
                  onTap: onAddOrChange,
                  child: Text(
                    'Cambiar número',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: onRevoke,
                  child: Text(
                    'Ya no tengo este número',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.error,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ] else if (hasPhone) ...[
                GestureDetector(
                  onTap: onRevoke,
                  child: Text(
                    'Ya no tengo este número',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.error,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmRevokePhone(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Ya no tienes acceso a este número?'),
      content: const Text(
        'Si tu teléfono fue robado o ya no tienes acceso a ese número, '
        'quitaremos la verificación para que puedas registrar uno nuevo.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Quitar verificación'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    try {
      final ds = ref.read(supabaseDatasourceProvider);
      await ds.revokePhoneVerification();
      // Forzar refresh del perfil desde la BD (no desde Auth) para reflejar el revoke
      await ref.read(authProvider.notifier).refreshProfile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Número eliminado. Agrega y verifica tu nuevo número.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}


// ── Read-only identity section ────────────────────────────────────────────────

class _ReadOnlySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _ReadOnlySection(
      {required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceLow.withValues(alpha: 0.06)
            : AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _LockedField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool verified;
  const _LockedField(
      {required this.icon,
      required this.label,
      required this.value,
      this.verified = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted)),
            Text(value,
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        if (verified) ...[
          const Spacer(),
          const Icon(Icons.verified_rounded, size: 18, color: AppColors.success),
        ],
      ],
    );
  }
}
