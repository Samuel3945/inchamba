import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ).animate().scale(
                    begin: const Offset(0.8, 0.8),
                    duration: 500.ms,
                    curve: Curves.easeOut,
                  ),
              const SizedBox(height: 24),
              Text(
                AppStrings.appName,
                style: GoogleFonts.poppins(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textWhite,
                ),
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
              const SizedBox(height: 12),
              Text(
                AppStrings.tagline,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: AppColors.textLight,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 400.ms).fadeIn(),
              const Spacer(flex: 3),
              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/register?role=trabajador'),
                  icon: const Icon(Icons.construction_rounded),
                  label: const Text(AppStrings.imWorker),
                ),
              ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.3),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/register?role=empleador'),
                  icon: const Icon(Icons.business_rounded),
                  label: const Text(AppStrings.imEmployer),
                ),
              ).animate(delay: 700.ms).fadeIn().slideY(begin: 0.3),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppStrings.alreadyHaveAccount,
                    style: GoogleFonts.poppins(color: AppColors.textLight, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(AppStrings.login),
                  ),
                ],
              ).animate(delay: 800.ms).fadeIn(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
