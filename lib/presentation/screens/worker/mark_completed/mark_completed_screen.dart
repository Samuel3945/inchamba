import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';

class MarkCompletedScreen extends HookConsumerWidget {
  final String jobPostId;
  final String applicationId;

  const MarkCompletedScreen({
    super.key,
    required this.jobPostId,
    required this.applicationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final descriptionCtrl = useTextEditingController();
    final evidenceFiles = useState<List<File>>([]);
    final isSubmitting = useState(false);

    Future<void> pickImage() async {
      if (evidenceFiles.value.length >= AppConstants.maxEvidenceImages) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo ${AppConstants.maxEvidenceImages} fotos de evidencia')),
        );
        return;
      }
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (picked != null) {
        evidenceFiles.value = [...evidenceFiles.value, File(picked.path)];
      }
    }

    Future<void> submit() async {
      if (descriptionCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Describe qué trabajo realizaste')),
        );
        return;
      }
      isSubmitting.value = true;
      try {
        final ds = ref.read(supabaseDatasourceProvider);
        final userId = ds.currentUserId!;

        // Upload evidence images
        final evidenceUrls = <String>[];
        for (final file in evidenceFiles.value) {
          final url = await ds.uploadFile(AppConstants.workEvidenceBucket, file.path, file);
          evidenceUrls.add(url);
        }

        await ds.createWorkCompletion({
          'job_post_id': jobPostId,
          'worker_id': userId,
          'application_id': applicationId,
          'completion_note': descriptionCtrl.text.trim(),
          'evidence_urls': evidenceUrls,
          'status': 'pending_confirmation',
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Solicitud enviada. El empleador debe confirmar para liberar el pago.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Marcar trabajo completado')),
      body: LoadingOverlay(
        isLoading: isSubmitting.value,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Qué trabajo realizaste?',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Describe el trabajo completado. El empleador revisará esta información antes de liberar el pago.',
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: descriptionCtrl,
                maxLines: 6,
                minLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Describe el trabajo que realizaste...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Fotos de evidencia',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Sube hasta ${AppConstants.maxEvidenceImages} fotos como evidencia del trabajo',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...evidenceFiles.value.asMap().entries.map((entry) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(entry.value, width: 100, height: 100, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              final newList = List<File>.from(evidenceFiles.value);
                              newList.removeAt(entry.key);
                              evidenceFiles.value = newList;
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (evidenceFiles.value.length < AppConstants.maxEvidenceImages)
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.darkBorder, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, color: AppColors.textMuted),
                            SizedBox(height: 4),
                            Text('Agregar', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El empleador debe confirmar que el trabajo fue completado para que se libere el pago.',
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push('/dispute/$jobPostId'),
                      child: const Text('Reportar disputa'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: submit,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Enviar solicitud'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
