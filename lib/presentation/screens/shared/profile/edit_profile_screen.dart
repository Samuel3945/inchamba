import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
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

    // Only contact/preference fields are editable
    final originalPhone = profile.phone;
    final phoneCtrl = useTextEditingController(text: profile.phone);
    final bioCtrl = useTextEditingController(text: profile.bio ?? '');
    final initialCity = profile.city.trim();
    final selectedCity = useState<String?>(
      AppConstants.colombianCities.contains(initialCity) ? initialCity : null,
    );
    final isDetectingCity = useState(false);
    final selectedCategories = useState<List<String>>(List.from(profile.categories));
    final avatarFile = useState<XFile?>(null);
    final avatarBytes = useState<Uint8List?>(null);
    final isLoading = useState(false);

    Future<void> pickAvatar() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
      if (picked != null) {
        avatarFile.value = picked;
        avatarBytes.value = await picked.readAsBytes();
      }
    }

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
      final newPhone = phoneCtrl.text.trim();
      final phoneChanged = newPhone.isNotEmpty && newPhone != originalPhone;
      try {
        String? avatarUrl = profile.avatarUrl;
        if (avatarFile.value != null) {
          final ds = ref.read(supabaseDatasourceProvider);
          avatarUrl = await ds.uploadXFile(AppConstants.avatarsBucket, avatarFile.value!);
        }

        await ref.read(authProvider.notifier).updateProfile({
          'phone': newPhone,
          'city': selectedCity.value ?? profile.city,
          'bio': bioCtrl.text.trim().isEmpty ? null : bioCtrl.text.trim(),
          'avatar_url': avatarUrl,
          'skill_categories': selectedCategories.value,
          if (phoneChanged) 'phone_verified': false,
        });

        if (context.mounted) {
          if (phoneChanged) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil actualizado. Verifica tu nuevo número.'),
                backgroundColor: AppColors.warning,
              ),
            );
            context.pushReplacement('/verify-phone');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Perfil actualizado'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop();
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
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
              // ── Avatar ─────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: isLoading.value ? null : pickAvatar,
                  child: Stack(
                    children: [
                      avatarBytes.value != null
                          ? CircleAvatar(
                              radius: 50,
                              backgroundImage: MemoryImage(avatarBytes.value!),
                            )
                          : InchambaAvatar(
                              imageUrl: profile.avatarUrl,
                              fallbackInitials: profile.fullName.isNotEmpty
                                  ? profile.fullName[0].toUpperCase()
                                  : '?',
                              radius: 50,
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                          child:
                              const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

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

              // ── Datos de contacto (editables) ──────────────────
              Text('Datos de contacto',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: AppStrings.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: profile.phoneVerified
                      ? const Tooltip(
                          message: 'Teléfono verificado',
                          child: Icon(Icons.verified_rounded, color: AppColors.success),
                        )
                      : null,
                ),
              ),
              if (!profile.phoneVerified)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.push('/verify-phone'),
                    icon: const Icon(Icons.verified_outlined, size: 15),
                    label: Text('Verificar teléfono',
                        style: GoogleFonts.poppins(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ),
              const SizedBox(height: 8),
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
