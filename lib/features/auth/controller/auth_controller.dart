import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/supabase_service.dart';

class AuthController extends AsyncNotifier<User?> {
  late final SupabaseService _supabaseService;

  @override
  FutureOr<User?> build() {
    _supabaseService = ref.watch(supabaseServiceProvider);
    
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      state = AsyncValue.data(data.session?.user);
    });

    return _supabaseService.currentUser;
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _supabaseService.signIn(email, password);
      state = AsyncValue.data(_supabaseService.currentUser);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signUp(String email, String password, String role) async {
    state = const AsyncValue.loading();
    try {
      await _supabaseService.signUp(email, password, {'role': role});
      state = AsyncValue.data(_supabaseService.currentUser);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _supabaseService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(() {
  return AuthController();
});

class SelectedRoleNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setRole(String role) {
    state = role;
  }
}

final selectedRoleProvider = NotifierProvider<SelectedRoleNotifier, String?>(() {
  return SelectedRoleNotifier();
});
