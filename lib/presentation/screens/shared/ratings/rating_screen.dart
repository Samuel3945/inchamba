import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';

class RatingScreen extends HookConsumerWidget {
  final String jobPostId;
  final String applicationId;
  final String ratedId;

  const RatingScreen({
    super.key,
    required this.jobPostId,
    required this.applicationId,
    required this.ratedId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stars = useState(0);
    final commentCtrl = useTextEditingController();
    final isSubmitting = useState(false);

    Future<void> submit() async {
      if (stars.value == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos una estrella')),
        );
        return;
      }
      isSubmitting.value = true;
      try {
        final ds = ref.read(supabaseDatasourceProvider);
        final userId = ds.currentUserId!;

        final alreadyRated = await ds.hasRated(jobPostId, userId, ratedId);
        if (alreadyRated) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ya calificaste a este usuario para este trabajo')),
            );
          }
          return;
        }

        await ds.createRating({
          'job_post_id': jobPostId,
          'application_id': applicationId,
          'rater_id': userId,
          'rated_id': ratedId,
          'score': stars.value,
          'comment': commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Calificación enviada'), backgroundColor: AppColors.success),
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
      appBar: AppBar(title: const Text('Calificar')),
      body: LoadingOverlay(
        isLoading: isSubmitting.value,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Text(
                '¿Cómo fue tu experiencia?',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              StarRating(
                rating: 0,
                interactive: true,
                currentValue: stars.value,
                size: 48,
                onChanged: (val) => stars.value = val,
              ),
              const SizedBox(height: 8),
              Text(
                _starLabel(stars.value),
                style: GoogleFonts.poppins(fontSize: 16, color: AppColors.star, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: commentCtrl,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: AppStrings.commentOptional,
                  hintText: 'Cuéntanos más sobre tu experiencia...',
                  alignLabelWithHint: true,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submit,
                  child: Text(AppStrings.submitRating, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _starLabel(int stars) {
    switch (stars) {
      case 1: return 'Malo';
      case 2: return 'Regular';
      case 3: return 'Bueno';
      case 4: return 'Muy bueno';
      case 5: return 'Excelente';
      default: return '';
    }
  }
}
