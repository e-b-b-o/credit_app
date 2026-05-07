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
      final response = await _supabaseService.signIn(email, password);
      final user = response.user;

      // Enforce role: the role the user signed in with must match the
      // role they selected on the role selection screen.
      final selectedRole = ref.read(selectedRoleProvider) ?? 'owner';
      final actualRole = user?.userMetadata?['role'] as String? ?? 'owner';

      if (actualRole != selectedRole) {
        // Wrong role — sign out immediately and surface a clear error
        await _supabaseService.signOut();
        state = AsyncValue.error(
          selectedRole == 'owner'
              ? 'This account is a customer account. Please use "Continue as Customer".'  
              : 'This account is an owner account. Please use "Continue as Owner".',
          StackTrace.current,
        );
        return;
      }

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
