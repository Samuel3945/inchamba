import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/profile.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class RegisterScreen extends HookConsumerWidget {
  final String? role;

  const RegisterScreen({super.key, this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final nameCtrl = useTextEditingController();
    final emailCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final passwordCtrl = useTextEditingController();
    final confirmPasswordCtrl = useTextEditingController();
    final companyCtrl = useTextEditingController();
    final selectedCity = useState<String?>(null);
    final selectedRole = useState<String>(
      role == Profile.roleEmployer ? Profile.roleEmployer : Profile.roleWorker,
    );
    final acceptedTerms = useState(false);
    final isLoading = useState(false);
    final obscurePassword = useState(true);

    final isEmployer = selectedRole.value == Profile.roleEmployer;

    Future<void> register() async {
      if (!formKey.currentState!.validate()) return;
      if (!acceptedTerms.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes aceptar los términos y condiciones')),
        );
        return;
      }
      if (selectedCity.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona tu ciudad')),
        );
        return;
      }
      isLoading.value = true;
      try {
        await ref.read(authProvider.notifier).signUp(
              email: emailCtrl.text.trim(),
              password: passwordCtrl.text,
              fullName: nameCtrl.text.trim(),
              phone: phoneCtrl.text.trim(),
              city: selectedCity.value!,
              role: selectedRole.value,
              companyName: isEmployer ? companyCtrl.text.trim() : null,
            );
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.mark_email_read_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text('Verifica tu correo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ],
              ),
              content: Text(
                'Te enviamos un enlace de verificación a ${emailCtrl.text.trim()}.\n\nRevisa tu bandeja de entrada (y spam) y haz clic en el enlace para activar tu cuenta. Luego podrás iniciar sesión.',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/login');
                  },
                  child: const Text('Ir a iniciar sesión'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ref.read(authProvider).error ?? 'Error al registrarse')),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: LoadingOverlay(
        isLoading: isLoading.value,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Crear cuenta',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textWhite,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elige qué quieres hacer. Siempre puedes cambiarlo luego desde tu perfil.',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 20),
                  _RoleToggle(
                    selected: selectedRole.value,
                    onChanged: (val) => selectedRole.value = val,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nameCtrl,
                    validator: Validators.fullName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: AppStrings.fullName,
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    decoration: const InputDecoration(
                      labelText: AppStrings.email,
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                    decoration: const InputDecoration(
                      labelText: AppStrings.phone,
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCity.value,
                    decoration: const InputDecoration(
                      labelText: AppStrings.city,
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                    items: AppConstants.colombianCities
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) => selectedCity.value = val,
                    validator: (val) => val == null ? 'Selecciona una ciudad' : null,
                  ),
                  if (isEmployer) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: companyCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: AppStrings.companyName,
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscurePassword.value,
                    validator: Validators.password,
                    autofillHints: const [],
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: AppStrings.password,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => obscurePassword.value = !obscurePassword.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordCtrl,
                    obscureText: true,
                    validator: (val) => Validators.confirmPassword(val, passwordCtrl.text),
                    autofillHints: const [],
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: AppStrings.confirmPassword,
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: acceptedTerms.value,
                        onChanged: (val) => acceptedTerms.value = val ?? false,
                        activeColor: AppColors.primary,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => acceptedTerms.value = !acceptedTerms.value,
                          child: Text(
                            AppStrings.acceptTerms,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: register,
                      child: const Text(AppStrings.register),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _RoleToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleCard(
            label: 'Trabajador',
            subtitle: 'Busca trabajos',
            icon: Icons.construction_rounded,
            selected: selected == Profile.roleWorker,
            onTap: () => onChanged(Profile.roleWorker),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleCard(
            label: 'Empleador',
            subtitle: 'Publica ofertas',
            icon: Icons.business_rounded,
            selected: selected == Profile.roleEmployer,
            onTap: () => onChanged(Profile.roleEmployer),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.darkBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textLight),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textWhite,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
