import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../providers/application_provider.dart';
import '../../../widgets/common_widgets.dart';

class ApplicationScreen extends HookConsumerWidget {
  final String jobPostId;

  const ApplicationScreen({super.key, required this.jobPostId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverLetterCtrl = useTextEditingController();
    final attachments = useState<List<File>>([]);
    final isSubmitting = useState(false);

    Future<void> pickImage() async {
      if (attachments.value.length >= AppConstants.maxApplicationImages) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máximo ${AppConstants.maxApplicationImages} imágenes')),
        );
        return;
      }
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (picked != null) {
        attachments.value = [...attachments.value, File(picked.path)];
      }
    }

    Future<void> submit() async {
      if (coverLetterCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe tu carta de presentación')),
        );
        return;
      }
      isSubmitting.value = true;
      try {
        await ref.read(applicationSubmitterProvider).submit(
              jobPostId: jobPostId,
              coverLetter: coverLetterCtrl.text.trim(),
              attachments: attachments.value,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Postulación enviada exitosamente'),
              backgroundColor: AppColors.success,
            ),
          );
          ref.invalidate(myApplicationForJobProvider(jobPostId));
          ref.invalidate(workerApplicationsProvider);
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
      appBar: AppBar(title: const Text('Postularme')),
      body: LoadingOverlay(
        isLoading: isSubmitting.value,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.coverLetter,
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.coverLetterHint,
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: coverLetterCtrl,
                maxLines: 10,
                minLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Escribe aquí tu carta de presentación...',
                  hintStyle: GoogleFonts.poppins(color: AppColors.textMuted),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              // Attachments
              Text(
                AppStrings.attachImages,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Máximo ${AppConstants.maxApplicationImages} imágenes',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...attachments.value.asMap().entries.map((entry) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            entry.value,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              final newList = List<File>.from(attachments.value);
                              newList.removeAt(entry.key);
                              attachments.value = newList;
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (attachments.value.length < AppConstants.maxApplicationImages)
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
                            Icon(Icons.add_photo_alternate_outlined, color: AppColors.textMuted),
                            SizedBox(height: 4),
                            Text('Agregar', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: submit,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(AppStrings.sendApplication, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
