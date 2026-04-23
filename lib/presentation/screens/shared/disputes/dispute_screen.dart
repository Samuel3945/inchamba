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
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';

class DisputeScreen extends HookConsumerWidget {
  final String jobPostId;

  const DisputeScreen({super.key, required this.jobPostId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedReason = useState<String?>(null);
    final descriptionCtrl = useTextEditingController();
    final evidenceFiles = useState<List<File>>([]);
    final isSubmitting = useState(false);

    Future<void> pickImage() async {
      if (evidenceFiles.value.length >= 5) return;
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
      if (picked != null) {
        evidenceFiles.value = [...evidenceFiles.value, File(picked.path)];
      }
    }

    Future<void> submit() async {
      if (selectedReason.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una razón')),
        );
        return;
      }
      if (descriptionCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Describe el problema')),
        );
        return;
      }
      isSubmitting.value = true;
      try {
        final ds = ref.read(supabaseDatasourceProvider);
        final userId = ds.currentUserId!;

        final evidenceUrls = <String>[];
        for (final file in evidenceFiles.value) {
          final url = await ds.uploadFile(AppConstants.workEvidenceBucket, file.path, file);
          evidenceUrls.add(url);
        }

        String? reportedAgainst;
        try {
          final job = await ds.getJobPost(jobPostId);
          final employerId = job['employer_id'] as String?;
          if (employerId != null && employerId != userId) {
            reportedAgainst = employerId;
          } else {
            final apps = await ds.getJobApplications(jobPostId);
            final accepted = apps.firstWhere(
              (a) => a['status'] == 'accepted',
              orElse: () => <String, dynamic>{},
            );
            reportedAgainst = accepted['worker_id'] as String?;
          }
        } catch (_) {}

        await ds.createDispute({
          'job_post_id': jobPostId,
          'reported_by': userId,
          'reported_against': reportedAgainst,
          'reason': selectedReason.value,
          'description': descriptionCtrl.text.trim(),
          'evidence_urls': evidenceUrls,
          'status': 'open',
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Disputa enviada. Revisaremos tu caso.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.reportDispute)),
      body: LoadingOverlay(
        isLoading: isSubmitting.value,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.disputeReason,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedReason.value,
                decoration: const InputDecoration(hintText: 'Selecciona una razón'),
                items: AppConstants.disputeReasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => selectedReason.value = val,
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.disputeDescription,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionCtrl,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Describe detalladamente el problema...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              Text('Evidencias (opcional)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...evidenceFiles.value.asMap().entries.map((entry) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(entry.value, width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              final list = List<File>.from(evidenceFiles.value);
                              list.removeAt(entry.key);
                              evidenceFiles.value = list;
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  if (evidenceFiles.value.length < 5)
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.surfaceDim),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textMuted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: AppColors.warning, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppStrings.disputeNotice,
                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: submit,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(AppStrings.submitDispute, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
