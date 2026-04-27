import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textWhite : AppColors.textDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.surfaceLowest;
    final bgColor = isDark ? AppColors.darkBg : AppColors.surfaceLow;

    // Simple XP calculation based on completed jobs
    final completedJobs = profile?.jobsCompleted ?? 0;
    final xp = completedJobs * 50;
    final level = (xp / 200).floor() + 1;
    final xpInLevel = xp % 200;
    final xpProgress = xpInLevel / 200;

    // Determine streak (placeholder — would come from backend)
    const streakDays = 0;

    // Lesson categories based on profile
    final categories = profile?.categories ?? [];
    final lessons = _buildLessons(categories, completedJobs);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────
            SliverAppBar(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceLowest,
              floating: true,
              snap: true,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 20,
              title: Text(
                'Mi progreso',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Level & XP card ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _levelEmoji(level),
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nivel $level — ${_levelTitle(level)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '$xp XP totales · $completedJobs trabajos completados',
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Progreso al nivel ${level + 1}',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: xpProgress,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$xpInLevel / 200 XP para el siguiente nivel',
                          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Stats row ────────────────────────────────
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.local_fire_department_rounded,
                        value: '$streakDays',
                        label: 'Días seguidos',
                        color: AppColors.warning,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.star_rounded,
                        value: '$xp',
                        label: 'XP ganados',
                        color: AppColors.primary,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.check_circle_rounded,
                        value: '$completedJobs',
                        label: 'Trabajos',
                        color: AppColors.success,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Daily lessons ────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.school_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Lecciones de hoy',
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (lessons.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('🎉', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 10),
                          Text(
                            '¡Lecciones completadas!',
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                          Text(
                            'Vuelve mañana para más contenido',
                            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  else
                    ...lessons.map((lesson) => _LessonCard(lesson: lesson, isDark: isDark, textPrimary: textPrimary, cardBg: cardBg)),

                  const SizedBox(height: 24),

                  // ── Skills progress ──────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Mis habilidades',
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: _buildSkills(completedJobs, textPrimary),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _levelEmoji(int level) {
    if (level <= 2) return '🌱';
    if (level <= 4) return '⚡';
    if (level <= 6) return '🔥';
    if (level <= 9) return '💎';
    return '👑';
  }

  String _levelTitle(int level) {
    if (level <= 1) return 'Principiante';
    if (level <= 2) return 'Aprendiz';
    if (level <= 3) return 'Hábil';
    if (level <= 5) return 'Experto';
    if (level <= 7) return 'Maestro';
    return 'Leyenda';
  }

  List<_Lesson> _buildLessons(List<String> categories, int completedJobs) {
    final base = [
      _Lesson(
        emoji: '🪪',
        title: 'Cómo luce un buen perfil',
        description: 'Aprende qué valoran los empleadores en tu perfil de Inchamba.',
        xp: 20,
        completed: completedJobs > 0,
      ),
      _Lesson(
        emoji: '💬',
        title: 'Cómo redactar una carta de presentación',
        description: 'Tips para que tu postulación destaque sobre los demás.',
        xp: 25,
        completed: completedJobs > 1,
      ),
      _Lesson(
        emoji: '💰',
        title: 'Negocia tu precio como un pro',
        description: 'Cuándo y cómo proponer un precio diferente al publicado.',
        xp: 30,
        completed: false,
      ),
      _Lesson(
        emoji: '⭐',
        title: 'Construye tu reputación',
        description: 'Por qué las calificaciones son clave para conseguir más trabajo.',
        xp: 20,
        completed: completedJobs > 2,
      ),
      _Lesson(
        emoji: '🛡️',
        title: 'Tus derechos como trabajador informal',
        description: 'Conoce qué te protege cuando trabajas por cuenta propia en Colombia.',
        xp: 35,
        completed: false,
      ),
    ];

    // Only show non-completed lessons (max 3 at a time)
    return base.where((l) => !l.completed).take(3).toList();
  }

  List<Widget> _buildSkills(int completed, Color textPrimary) {
    final skills = [
      ('Puntualidad', 0.85, AppColors.success),
      ('Presentación', 0.70, AppColors.primary),
      ('Comunicación', 0.60, AppColors.warning),
      ('Trabajo en equipo', 0.45, AppColors.info),
    ];
    return skills.map((s) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.$1, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
              Text('${(s.$2 * 100).toInt()}%', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: s.$2,
              backgroundColor: AppColors.surfaceDim,
              valueColor: AlwaysStoppedAnimation<Color>(s.$3),
              minHeight: 8,
            ),
          ),
        ],
      ),
    )).toList();
  }
}

class _Lesson {
  final String emoji;
  final String title;
  final String description;
  final int xp;
  final bool completed;
  _Lesson({
    required this.emoji,
    required this.title,
    required this.description,
    required this.xp,
    required this.completed,
  });
}

class _LessonCard extends StatelessWidget {
  final _Lesson lesson;
  final bool isDark;
  final Color textPrimary;
  final Color cardBg;

  const _LessonCard({required this.lesson, required this.isDark, required this.textPrimary, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lesson.completed
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.surfaceDim,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(lesson.emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  lesson.description,
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 13, color: AppColors.warning),
                    const SizedBox(width: 3),
                    Text('+${lesson.xp} XP', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lección en preparación — ¡pronto disponible!')),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Iniciar', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color cardBg;
  final Color textPrimary;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.cardBg,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary)),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
