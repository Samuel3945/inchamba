import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../providers/notification_provider.dart';

class ShellScaffold extends ConsumerWidget {
  final bool isEmployer;
  final Widget child;

  const ShellScaffold({
    super.key,
    required this.isEmployer,
    required this.child,
  });

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final prefix = isEmployer ? '/employer' : '/worker';
    if (location == prefix) return 0;
    if (location == '$prefix/${isEmployer ? "offers" : "applications"}') return 1;
    if (location == '$prefix/messages') return 2;
    if (location == '$prefix/profile') return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final index = _currentIndex(context);
    final prefix = isEmployer ? '/employer' : '/worker';

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go(prefix);
              break;
            case 1:
              context.go('$prefix/${isEmployer ? "offers" : "applications"}');
              break;
            case 2:
              context.go('$prefix/messages');
              break;
            case 3:
              context.go('$prefix/profile');
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(isEmployer ? Icons.dashboard_rounded : Icons.work_rounded),
            label: isEmployer ? 'Dashboard' : 'Trabajos',
          ),
          BottomNavigationBarItem(
            icon: Icon(isEmployer ? Icons.list_alt_rounded : Icons.assignment_rounded),
            label: isEmployer ? 'Ofertas' : 'Postulaciones',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount', style: const TextStyle(fontSize: 10)),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.chat_bubble_rounded),
            ),
            label: 'Mensajes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
