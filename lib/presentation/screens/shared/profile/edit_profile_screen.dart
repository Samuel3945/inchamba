import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/common_widgets.dart';

class EditProfileScreen extends HookConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final nameCtrl = useTextEditingController(text: profile.fullName);
    final phoneCtrl = useTextEditingController(text: profile.phone);
    final bioCtrl = useTextEditingController(text: profile.bio ?? '');
    final companyCtrl = useTextEditingController(text: profile.companyName ?? '');
    final initialCity = profile.city.trim();
    final selectedCity = useState<String?>(
      AppConstants.colombianCities.contains(initialCity) ? initialCity : null,
    );
    final selectedCategories = useState<List<String>>(List.from(profile.categories));
    final avatarFile = useState<File?>(null);
    final isLoading = useState(false);

    Future<void> pickAvatar() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
      if (picked != null) avatarFile.value = File(picked.path);
    }

    Future<void> save() async {
      isLoading.value = true;
      try {
        String? avatarUrl = profile.avatarUrl;
        if (avatarFile.value != null) {
          final ds = ref.read(supabaseDatasourceProvider);
          avatarUrl = await ds.uploadFile(AppConstants.avatarsBucket, avatarFile.value!.path, avatarFile.value!);
        }

        await ref.read(authProvider.notifier).updateProfile({
          'full_name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'city': selectedCity.value ?? profile.city,
          'bio': bioCtrl.text.trim().isEmpty ? null : bioCtrl.text.trim(),
          'company_name': companyCtrl.text.trim().isEmpty ? null : companyCtrl.text.trim(),
          'avatar_url': avatarUrl,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil actualizado'), backgroundColor: AppColors.success),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.editProfile, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: isLoading.value ? null : save,
            child: isLoading.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text(AppStrings.save),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: isLoading.value,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(
                child: GestureDetector(
                  onTap: pickAvatar,
                  child: Stack(
                    children: [
                      avatarFile.value != null
                          ? CircleAvatar(
                              radius: 50,
                              backgroundImage: FileImage(avatarFile.value!),
                            )
                          : InchambaAvatar(
                              imageUrl: profile.avatarUrl,
                              fallbackInitials: profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                              radius: 50,
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: AppStrings.fullName, prefixIcon: Icon(Icons.person_outlined)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: AppStrings.phone, prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCity.value,
                decoration: const InputDecoration(labelText: AppStrings.city, prefixIcon: Icon(Icons.location_city_outlined)),
                items: AppConstants.colombianCities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => selectedCity.value = val,
              ),
              if (profile.isEmployer) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: companyCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: AppStrings.companyName, prefixIcon: Icon(Icons.business_outlined)),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: bioCtrl,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Biografía', alignLabelWithHint: true),
              ),
              const SizedBox(height: 24),
              Text('Categorías de trabajo', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.jobCategories.entries.map((e) {
                  final isSelected = selectedCategories.value.contains(e.key);
                  return FilterChip(
                    selected: isSelected,
                    label: Text(e.value),
                    onSelected: (selected) {
                      final list = List<String>.from(selectedCategories.value);
                      if (selected) {
                        list.add(e.key);
                      } else {
                        list.remove(e.key);
                      }
                      selectedCategories.value = list;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
