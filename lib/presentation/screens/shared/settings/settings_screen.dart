import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/core_providers.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.settings, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        children: [
          // Theme
          SwitchListTile(
            title: Text('Modo oscuro', style: GoogleFonts.poppins()),
            subtitle: Text(isDark ? 'Activado' : 'Desactivado', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted)),
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppColors.primary),
            value: isDark,
            activeThumbColor: AppColors.primary,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const Divider(),
          // Change password
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(AppStrings.changePassword, style: GoogleFonts.poppins()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context, ref),
          ),
          const Divider(),
          // Edit profile
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(AppStrings.editProfile, style: GoogleFonts.poppins()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/edit-profile'),
          ),
          const Divider(),
          const SizedBox(height: 32),
          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(AppStrings.cancel)),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(AppStrings.logout)),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authProvider.notifier).signOut();
                }
              },
              icon: const Icon(Icons.logout),
              label: Text(AppStrings.logout, style: GoogleFonts.poppins()),
            ),
          ),
          const SizedBox(height: 16),
          // Delete account
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar cuenta'),
                    content: const Text(
                      'Esta acción es irreversible. Se eliminarán todos tus datos. ¿Estás seguro?',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(AppStrings.cancel)),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        child: const Text(AppStrings.delete),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final ds = ref.read(supabaseDatasourceProvider);
                  final userId = ds.currentUserId;
                  if (userId != null) {
                    await ds.deleteAccount(userId);
                    await ref.read(authProvider.notifier).signOut();
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(AppStrings.deleteAccount, style: GoogleFonts.poppins()),
            ),
          ),
          const SizedBox(height: 32),
          // App version
          Center(
            child: Text(
              'Inchamba v1.0.0',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: TextField(
          controller: passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Nueva contraseña',
            hintText: 'Mínimo 6 caracteres',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (passwordCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mínimo 6 caracteres')),
                );
                return;
              }
              try {
                final ds = ref.read(supabaseDatasourceProvider);
                await ds.updatePassword(passwordCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contraseña actualizada'), backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }
}
