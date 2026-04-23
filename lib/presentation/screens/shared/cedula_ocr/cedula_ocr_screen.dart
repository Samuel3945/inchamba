import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/auth_provider.dart' show currentProfileProvider;
import '../../../widgets/common_widgets.dart';

class CedulaOCRScreen extends HookConsumerWidget {
  const CedulaOCRScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageFile = useState<XFile?>(null);
    final previewBytes = useState<Uint8List?>(null);
    final isScanning = useState(false);
    final result = useState<Map<String, dynamic>?>(null);
    final error = useState<String?>(null);

    final cedulaCtrl = useTextEditingController();
    final nameCtrl = useTextEditingController();
    final dobCtrl = useTextEditingController();
    final pobCtrl = useTextEditingController();
    final bloodCtrl = useTextEditingController();
    final sexCtrl = useTextEditingController();
    final heightCtrl = useTextEditingController();
    // Trigger rebuild when dob changes so the age suffix updates
    useListenable(dobCtrl);

    Future<void> pickImage(ImageSource source) async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      imageFile.value = picked;
      previewBytes.value = Uint8List.fromList(bytes);
      result.value = null;
      error.value = null;
    }

    Future<void> scan() async {
      if (imageFile.value == null) return;
      isScanning.value = true;
      error.value = null;
      result.value = null;
      try {
        final ds = ref.read(supabaseDatasourceProvider);
        final data = await ds.ocrCedula(imageFile.value!);
        result.value = data;
        cedulaCtrl.text = data['cedulaNumber'] as String? ?? '';
        nameCtrl.text = data['fullName'] as String? ?? '';
        dobCtrl.text = data['dateOfBirth'] as String? ?? '';
        pobCtrl.text = data['placeOfBirth'] as String? ?? '';
        bloodCtrl.text = data['bloodType'] as String? ?? '';
        sexCtrl.text = data['sex'] as String? ?? '';
        heightCtrl.text = data['height'] as String? ?? '';
      } catch (e) {
        error.value =
            'No se pudo leer la cédula. Asegúrate de que la foto sea clara y bien iluminada.';
      } finally {
        isScanning.value = false;
      }
    }

    Future<void> confirm() async {
      final cedula = cedulaCtrl.text.trim();
      if (cedula.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El número de cédula no puede estar vacío')),
        );
        return;
      }
      if (cedula.length < 6 || cedula.length > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Número de cédula inválido')),
        );
        return;
      }
      try {
        final ds = ref.read(supabaseDatasourceProvider);

        // Parsear fecha DD/MM/YYYY → YYYY-MM-DD para Postgres
        String? isoDate;
        final dob = dobCtrl.text.trim();
        if (dob.isNotEmpty) {
          final parts = dob.split('/');
          if (parts.length == 3) {
            isoDate = '${parts[2]}-${parts[1]}-${parts[0]}';
          }
        }

        final updates = <String, dynamic>{
          'cedula': cedula,
          if (nameCtrl.text.trim().isNotEmpty) 'cedula_full_name': nameCtrl.text.trim(),
          'cedula_date_birth': isoDate,
          if (pobCtrl.text.trim().isNotEmpty) 'cedula_place_birth': pobCtrl.text.trim(),
          if (bloodCtrl.text.trim().isNotEmpty) 'cedula_blood_type': bloodCtrl.text.trim(),
          if (sexCtrl.text.trim().isNotEmpty) 'cedula_sex': sexCtrl.text.trim(),
          'cedula_height_cm': heightCtrl.text.trim().isNotEmpty
              ? int.tryParse(heightCtrl.text.trim())
              : null,
        };

        await ds.updateProfile(ds.currentUserId!, updates);
        ref.invalidate(currentProfileProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cédula guardada exitosamente'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Escanear Cédula', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: LoadingOverlay(
        isLoading: isScanning.value,
        loadingText: 'Analizando cédula...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fotografía tu cédula',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Asegúrate de que el documento esté bien iluminado, sin reflejos y completamente visible.',
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
              ),
              const SizedBox(height: 24),

              // Image preview
              GestureDetector(
                onTap: () => _showSourceSheet(context, pickImage),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: previewBytes.value != null
                          ? AppColors.primary
                          : AppColors.surfaceDim,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: previewBytes.value != null
                      ? Image.memory(previewBytes.value!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge_outlined, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              'Toca para tomar foto o seleccionar de galería',
                              style: GoogleFonts.poppins(
                                  fontSize: 13, color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Cámara'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Galería'),
                    ),
                  ),
                ],
              ),

              if (imageFile.value != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isScanning.value ? null : scan,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: Text(
                      'Escanear cédula',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],

              if (error.value != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          error.value!,
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // OCR Result
              if (result.value != null) ...[
                const SizedBox(height: 24),
                _ConfidenceBadge(confidence: result.value!['confidence'] as String? ?? 'low'),
                const SizedBox(height: 16),
                Text(
                  'Datos detectados',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revisa y corrige si es necesario antes de guardar.',
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),

                // Número de cédula (editable, obligatorio)
                TextFormField(
                  controller: cedulaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de cédula *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // Nombre completo (editable)
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                // Fecha de nacimiento y lugar — fila
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: dobCtrl,
                        decoration: InputDecoration(
                          labelText: 'Fecha nacimiento',
                          prefixIcon: const Icon(Icons.cake_outlined),
                          hintText: 'DD/MM/YYYY',
                          suffixText: _calcAge(dobCtrl.text),
                          suffixStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: pobCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Lugar nacimiento',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tipo de sangre, sexo y altura — fila
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: bloodCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de sangre',
                          prefixIcon: Icon(Icons.bloodtype_outlined),
                          hintText: 'O+',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: sexCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Sexo',
                          prefixIcon: Icon(Icons.wc_outlined),
                          hintText: 'M o F',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: heightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Altura (cm)',
                          prefixIcon: Icon(Icons.height_outlined),
                          hintText: '170',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: confirm,
                    icon: const Icon(Icons.verified_outlined),
                    label: Text(
                      'Confirmar y guardar',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              _TipsCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String? _calcAge(String dob) {
    if (dob.isEmpty) return null;
    final parts = dob.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final birth = DateTime(year, month, day);
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
    if (age < 0 || age > 120) return null;
    return '$age años';
  }

  void _showSourceSheet(
    BuildContext context,
    Future<void> Function(ImageSource) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                onSelect(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Seleccionar de galería'),
              onTap: () {
                Navigator.pop(context);
                onSelect(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (confidence) {
      'high' => ('Alta confianza - datos bien leídos', AppColors.success, Icons.check_circle_outline),
      'medium' => ('Confianza media - revisa los datos', AppColors.warning, Icons.warning_amber_outlined),
      _ => ('Baja confianza - imagen poco clara', AppColors.error, Icons.error_outline),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Text(
                'Consejos para mejor resultado',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...[
            '📸 Ubica la cédula sobre una superficie plana',
            '💡 Asegúrate de tener buena iluminación',
            '🔲 Incluye todos los bordes de la cédula en la foto',
            '🚫 Evita reflejos o sombras sobre el documento',
            '📐 Mantén la cámara paralela al documento',
          ].map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                tip,
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textLight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
