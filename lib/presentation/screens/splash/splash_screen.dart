import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    debugPrint('[SPLASH] initState — scheduling 4s timeout');

    // Safety net: if auth stays in "initial" for 4s, force to login
    _timeout = Timer(const Duration(seconds: 4), () {
      final status = ref.read(authProvider).status;
      debugPrint('[SPLASH] timeout fired — status=$status, mounted=$mounted');
      if (mounted && status == AuthStatus.initial) {
        debugPrint('[SPLASH] forcing navigation to /login');
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceLowest, AppColors.surfaceLow],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 24),
              Text(
                'Inchamba',
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.3, end: 0),
              const SizedBox(height: 8),
              Text(
                'Trabajo informal en Colombia',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ).animate(delay: 600.ms).fadeIn(duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}
