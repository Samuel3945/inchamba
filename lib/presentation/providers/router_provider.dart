import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/worker/dashboard/worker_dashboard_screen.dart';
import '../screens/worker/job_detail/job_detail_screen.dart';
import '../screens/worker/progress/progress_screen.dart';
import '../screens/worker/application/application_screen.dart';
import '../screens/worker/my_applications/my_applications_screen.dart';
import '../screens/worker/mark_completed/mark_completed_screen.dart';
import '../screens/employer/dashboard/employer_dashboard_screen.dart';
import '../screens/employer/create_offer/create_offer_screen.dart';
import '../screens/employer/payment/payment_screen.dart';
import '../screens/employer/my_offers/my_offers_screen.dart';
import '../screens/employer/offer_detail/employer_offer_detail_screen.dart';
import '../screens/employer/confirm_work/confirm_work_screen.dart';
import '../screens/employer/wallet/wallet_screen.dart';
import '../screens/shared/notifications/notifications_screen.dart';
import '../screens/shared/profile/profile_screen.dart';
import '../screens/shared/profile/edit_profile_screen.dart';
import '../screens/shared/profile/public_profile_screen.dart';
import '../screens/shared/ratings/rating_screen.dart';
import '../screens/shared/disputes/dispute_screen.dart';
import '../screens/shared/settings/settings_screen.dart';
import '../screens/guest/guest_feed_screen.dart';
import '../screens/shared/cedula_ocr/cedula_ocr_screen.dart';
import '../screens/shared/cedula_advisor/cedula_advisor_screen.dart';
import '../screens/shared/profile/phone_verify_screen.dart';
import '../widgets/shell_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final loc = state.matchedLocation;
    final isAuth = authState.status == AuthStatus.authenticated;
    final isAuthRoute = loc == '/login' ||
        loc == '/register' ||
        loc == '/splash' ||
        loc == '/forgot-password' ||
        loc == '/browse' ||
        loc == '/cedula-advisor';

    debugPrint('[ROUTER] redirect: loc=$loc, status=${authState.status}');

    if (authState.status == AuthStatus.initial) {
      if (loc == '/splash') return null;
      return '/splash';
    }
    // Once auth resolved, splash has no purpose — redirect out
    if (loc == '/splash') {
      if (isAuth) {
        final isEmployer = authState.profile?.isEmployer ?? false;
        return isEmployer ? '/employer' : '/worker';
      }
      return '/browse'; // primera vista: feed de ofertas sin registrarse
    }
    if (!isAuth && !isAuthRoute) return '/browse';
    if (isAuth && isAuthRoute) {
      final isEmployer = authState.profile?.isEmployer ?? false;
      return isEmployer ? '/employer' : '/worker';
    }
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        redirect: (_, _) => '/login',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(
          role: state.uri.queryParameters['role'],
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/browse',
        builder: (context, state) => const GuestFeedScreen(),
      ),
      // Worker shell
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ShellScaffold(
          isEmployer: false,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/worker',
            builder: (context, state) => const WorkerDashboardScreen(),
          ),
          GoRoute(
            path: '/worker/progress',
            builder: (context, state) => const ProgressScreen(),
          ),
          GoRoute(
            path: '/worker/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      // Employer shell
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(
          isEmployer: true,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/employer',
            builder: (context, state) => const EmployerDashboardScreen(),
          ),
          GoRoute(
            path: '/employer/offers',
            builder: (context, state) => const MyOffersScreen(),
          ),
          GoRoute(
            path: '/employer/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      // Detail routes (pushed on top of shell)
      GoRoute(
        path: '/job/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => JobDetailScreen(
          jobPostId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/job/:id/apply',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ApplicationScreen(
          jobPostId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/job/:id/mark-completed/:applicationId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => MarkCompletedScreen(
          jobPostId: state.pathParameters['id']!,
          applicationId: state.pathParameters['applicationId']!,
        ),
      ),
      GoRoute(
        path: '/employer/create-offer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateOfferScreen(),
      ),
      GoRoute(
        path: '/employer/offer/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => EmployerOfferDetailScreen(
          jobPostId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/employer/offer/:id/confirm-work/:completionId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ConfirmWorkScreen(
          jobPostId: state.pathParameters['id']!,
          completionId: state.pathParameters['completionId']!,
        ),
      ),
      GoRoute(
        path: '/payment/:jobPostId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PaymentScreen(
          jobPostId: state.pathParameters['jobPostId']!,
        ),
      ),
      GoRoute(
        path: '/employer/wallet',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/worker/wallet',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PublicProfileScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/rate/:jobPostId/:applicationId/:ratedId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RatingScreen(
          jobPostId: state.pathParameters['jobPostId']!,
          applicationId: state.pathParameters['applicationId']!,
          ratedId: state.pathParameters['ratedId']!,
        ),
      ),
      GoRoute(
        path: '/dispute/:jobPostId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => DisputeScreen(
          jobPostId: state.pathParameters['jobPostId']!,
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/cedula-ocr',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CedulaOCRScreen(),
      ),
      GoRoute(
        path: '/verify-phone',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PhoneVerifyScreen(),
      ),
      GoRoute(
        path: '/worker/applications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyApplicationsScreen(),
      ),
      GoRoute(
        path: '/cedula-advisor',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CedulaAdvisorScreen(),
      ),
    ],
  );
});
