import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/profile_model.dart';
import 'core_providers.dart';

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final ProfileModel? profile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    ProfileModel? profile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseDatasource? _datasource;

  AuthNotifier(SupabaseDatasource datasource)
      : _datasource = datasource,
        super(const AuthState()) {
    _init();
  }

  /// Fallback when Supabase is not available — immediately unauthenticated.
  AuthNotifier._fallback()
      : _datasource = null,
        super(const AuthState(status: AuthStatus.unauthenticated));

  SupabaseDatasource get _ds {
    final ds = _datasource;
    if (ds == null) {
      throw StateError('Supabase not available');
    }
    return ds;
  }

  void _init() {
    debugPrint('[AUTH] _init() started');
    try {
      final session = _ds.client.auth.currentSession;
      debugPrint('[AUTH] currentSession=${session != null ? "exists" : "null"}');

      if (session != null) {
        _loadProfile(session.user.id);
      } else {
        debugPrint('[AUTH] No session → unauthenticated');
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }

      _ds.client.auth.onAuthStateChange.listen((data) {
        debugPrint('[AUTH] onAuthStateChange: ${data.event}');
        if (data.event == AuthChangeEvent.signedIn && data.session != null) {
          _loadProfile(data.session!.user.id);
        } else if (data.event == AuthChangeEvent.signedOut) {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      });
    } catch (e) {
      debugPrint('[AUTH] _init error: $e');
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _loadProfile(String userId) async {
    debugPrint('[AUTH] _loadProfile($userId) started');
    try {
      // Heal profile from user_metadata if needed (e.g. signUp upsert was
      // blocked by RLS before email verification).
      try {
        await _ds.ensureProfile().timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('[AUTH] ensureProfile skipped: $e');
      }

      final data = await _ds.getProfile(userId)
          .timeout(const Duration(seconds: 5));
      final profile = ProfileModel.fromJson(data);
      debugPrint('[AUTH] _loadProfile success → authenticated (role=${profile.role})');
      state = AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
      );
    } catch (e) {
      debugPrint('[AUTH] _loadProfile failed: $e');
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Error cargando perfil',
      );
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String city = '',
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final namePart = email.split('@').first.replaceAll(RegExp(r'[._+]'), ' ');
      final fullName = namePart.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ').trim();
      await _ds.signUp(
        email: email,
        password: password,
        profileData: {
          'full_name': fullName.isEmpty ? 'Usuario' : fullName,
          'phone': '',
          'city': city,
          'role': role,
        },
      );
      // Don't auto-authenticate — user must verify email first
      state = state.copyWith(isLoading: false, status: AuthStatus.unauthenticated);
    } catch (e) {
      String message = 'Error al registrarse';
      if (e is AuthException) {
        if (e.message.contains('already registered')) {
          message = 'Este correo ya está registrado';
        } else {
          message = e.message;
        }
      }
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _ds.signIn(email: email, password: password);
    } catch (e) {
      String message = 'Error al iniciar sesión';
      if (e is AuthException) {
        message = 'Credenciales incorrectas';
      }
      state = state.copyWith(isLoading: false, error: message);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _ds.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> resetPassword(String email) async {
    await _ds.resetPassword(email);
  }

  Future<void> refreshProfile() async {
    final userId = _ds.currentUserId;
    if (userId != null) {
      await _loadProfile(userId);
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = _ds.currentUserId;
    if (userId == null) return;
    await _ds.updateProfile(userId, data);
    await _loadProfile(userId);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  try {
    return AuthNotifier(ref.watch(supabaseDatasourceProvider));
  } catch (e) {
    debugPrint('[AUTH] Provider creation failed (Supabase not ready): $e');
    return AuthNotifier._fallback();
  }
});

final currentProfileProvider = Provider<ProfileModel?>((ref) {
  return ref.watch(authProvider).profile;
});

final isEmployerProvider = Provider<bool>((ref) {
  return ref.watch(currentProfileProvider)?.isEmployer ?? false;
});
