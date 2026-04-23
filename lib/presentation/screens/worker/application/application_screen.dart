import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';

class ApplicationScreen extends HookConsumerWidget {
  final String jobPostId;

  const ApplicationScreen({super.key, required this.jobPostId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverLetterCtrl = useTextEditingController();
    final attachments = useState<List<XFile>>([]);
    final isSubmitting = useState(false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Audio state ──────────────────────────────────────
    final recorder = useMemoized(() => AudioRecorder());
    final player = useMemoized(() => AudioPlayer());
    final isRecording = useState(false);
    final recordedPath = useState<String?>(null);   // blob URL (web) or file path (native)
    final isPlaying = useState(false);
    final playerPosition = useState(Duration.zero);
    final playerDuration = useState(Duration.zero);

    useEffect(() {
      final posSub = player.onPositionChanged.listen((d) {
        playerPosition.value = d;
      });
      final durSub = player.onDurationChanged.listen((d) {
        playerDuration.value = d;
      });
      player.onPlayerStateChanged.listen((state) {
        isPlaying.value = state == PlayerState.playing;
        if (state == PlayerState.completed) {
          playerPosition.value = Duration.zero;
          isPlaying.value = false;
        }
      });
      return () {
        posSub.cancel();
        durSub.cancel();
        recorder.dispose();
        player.dispose();
      };
    }, []);

    Future<void> toggleRecording() async {
      if (isRecording.value) {
        // Stop recording
        final path = await recorder.stop();
        isRecording.value = false;
        if (path != null && path.isNotEmpty) {
          recordedPath.value = path;
        }
      } else {
        // Check permission
        final hasPermission = await recorder.hasPermission();
        if (!hasPermission) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Necesitas permiso para usar el micrófono')),
            );
          }
          return;
        }
        // Clear previous recording
        recordedPath.value = null;
        playerPosition.value = Duration.zero;
        playerDuration.value = Duration.zero;
        await player.stop();

        // Start recording
        String? path;
        if (!kIsWeb) {
          final tmpDir = '/tmp';
          path = '$tmpDir/audio_app_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        await recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
          path: path ?? '',
        );
        isRecording.value = true;
      }
    }

    Future<void> togglePlayback() async {
      final path = recordedPath.value;
      if (path == null) return;
      if (isPlaying.value) {
        await player.pause();
      } else {
        if (playerPosition.value > Duration.zero) {
          await player.resume();
        } else {
          final source = kIsWeb ? UrlSource(path) : DeviceFileSource(path);
          await player.play(source);
        }
      }
    }

    Future<void> deleteRecording() async {
      await player.stop();
      recordedPath.value = null;
      isPlaying.value = false;
      playerPosition.value = Duration.zero;
      playerDuration.value = Duration.zero;
    }

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
        attachments.value = [...attachments.value, picked];
      }
    }

    Future<void> submit() async {
      if (coverLetterCtrl.text.trim().isEmpty && recordedPath.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe una presentación o graba un mensaje de voz')),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Confirmar postulación', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Text(
            '¿Estás seguro de que deseas enviar tu postulación?',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
          ],
        ),
      );
      if (confirm != true) return;

      isSubmitting.value = true;
      try {
        // Upload audio if present
        String? audioUrl;
        final path = recordedPath.value;
        if (path != null) {
          await player.stop();
          final audioXFile = XFile(path, mimeType: 'audio/aac', name: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
          final ds = ref.read(supabaseDatasourceProvider);
          audioUrl = await ds.uploadXFile(AppConstants.applicationAttachmentsBucket, audioXFile);
        }

        await ref.read(applicationSubmitterProvider).submit(
              jobPostId: jobPostId,
              coverLetter: coverLetterCtrl.text.trim(),
              attachments: attachments.value,
              audioUrl: audioUrl,
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
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    final textPrimary = isDark ? AppColors.textWhite : AppColors.textDark;

    return Scaffold(
      appBar: AppBar(title: Text('Postularme', style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
      body: LoadingOverlay(
        isLoading: isSubmitting.value,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Carta de presentación',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cuéntale al empleador por qué eres la persona ideal para este trabajo.',
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: coverLetterCtrl,
                maxLines: 6,
                minLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Escribe aquí tu carta de presentación...',
                  hintStyle: GoogleFonts.poppins(color: AppColors.textMuted),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),

              // ── Voice message ────────────────────────────────
              Text(
                'Mensaje de voz',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Graba un mensaje de voz para complementar tu postulación.',
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),

              _VoiceRecorder(
                isRecording: isRecording.value,
                recordedPath: recordedPath.value,
                isPlaying: isPlaying.value,
                position: playerPosition.value,
                duration: playerDuration.value,
                onToggleRecord: toggleRecording,
                onTogglePlay: togglePlayback,
                onDelete: deleteRecording,
                isDark: isDark,
                textPrimary: textPrimary,
              ),

              const SizedBox(height: 28),

              // ── Image attachments ────────────────────────────
              Text(
                'Fotos adjuntas',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hasta ${AppConstants.maxApplicationImages} imágenes opcionales',
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
                          child: Image.network(
                            entry.value.path,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color ?? AppColors.surfaceLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.image, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              final newList = List<XFile>.from(attachments.value);
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
                          border: Border.all(color: AppColors.surfaceDim, width: 2),
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
                  label: Text('Enviar postulación', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
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

// ─── Voice recorder widget ────────────────────────────────────────────────────
class _VoiceRecorder extends StatelessWidget {
  final bool isRecording;
  final String? recordedPath;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onToggleRecord;
  final VoidCallback onTogglePlay;
  final VoidCallback onDelete;
  final bool isDark;
  final Color textPrimary;

  const _VoiceRecorder({
    required this.isRecording,
    required this.recordedPath,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onToggleRecord,
    required this.onTogglePlay,
    required this.onDelete,
    required this.isDark,
    required this.textPrimary,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfaceLowest;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.textDark.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          // ── State: idle / recording ──────────────────────
          if (recordedPath == null) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRecording
                    ? AppColors.error
                    : AppColors.primary.withValues(alpha: 0.1),
                boxShadow: isRecording
                    ? [
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: IconButton(
                icon: Icon(
                  isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 36,
                  color: isRecording ? Colors.white : AppColors.primary,
                ),
                onPressed: onToggleRecord,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isRecording ? '● Grabando...' : 'Toca para grabar',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isRecording ? AppColors.error : AppColors.textMuted,
              ),
            ),
            if (isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Toca de nuevo para detener',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
          ],

          // ── State: recorded — show player ────────────────
          if (recordedPath != null) ...[
            Row(
              children: [
                // Play/pause button
                GestureDetector(
                  onTap: onTogglePlay,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Waveform / progress bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mensaje de voz',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            duration > Duration.zero
                                ? '${_formatDuration(position)} / ${_formatDuration(duration)}'
                                : _formatDuration(position),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: duration.inMilliseconds > 0
                              ? position.inMilliseconds / duration.inMilliseconds
                              : 0,
                          backgroundColor: AppColors.surfaceDim,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.mic_rounded, size: 12, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            'Audio listo para enviar',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Delete button
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Re-record option
            GestureDetector(
              onTap: onDelete,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Grabar de nuevo',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
