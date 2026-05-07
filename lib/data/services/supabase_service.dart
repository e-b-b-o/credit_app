import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_model.dart';
import '../models/transaction_model.dart';
import '../models/complaint_model.dart';
import '../../core/constants/env_constants.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(ref.watch(supabaseProvider));
});

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // Auth Methods
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password, Map<String, dynamic> data) async {
    return await _client.auth.signUp(email: email, password: password, data: data);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  Future<void> deleteOwnerAccount() async {
    await _client.rpc('delete_user_account');
    await signOut();
  }

  // Customers
  Future<List<CustomerModel>> getCustomers() async {
    final response = await _client
        .from('customers')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (response as List).map((json) => CustomerModel.fromJson(json)).toList();
  }

  Future<CustomerModel> getCustomerById(String id) async {
    final response = await _client.from('customers').select().eq('id', id).single();
    return CustomerModel.fromJson(response);
  }

  Future<CustomerModel> addCustomer(String name, String phone) async {
    final ownerId = currentUser?.id;
    if (ownerId == null) throw Exception('Not logged in');

    final response = await _client.from('customers').insert({
      'name': name,
      'phone': phone,
      'owner_id': ownerId,
    }).select().single();

    return CustomerModel.fromJson(response);
  }

  Future<void> deactivateCustomer(String customerId) async {
    await _client.from('customers').update({'is_active': false}).eq('id', customerId);
  }

  Future<CustomerModel> getCurrentCustomerProfile() async {
    final uid = currentUser?.id;
    if (uid == null) throw Exception('Not logged in');
    final response = await _client
        .from('customers')
        .select()
        .eq('auth_user_id', uid)
        .single();
    return CustomerModel.fromJson(response);
  }

  Future<void> createCustomerCredentials(String email, String password, String customerId) async {
    final ownerId = currentUser?.id;
    if (ownerId == null) throw Exception('Not logged in');

    // Create a temporary, isolated Supabase client to prevent overwriting the owner's session.
    // - EmptyLocalStorage: no session persisted to SharedPreferences
    // - AuthFlowType.implicit: avoids the PKCE flow which requires async storage for a code verifier
    final tempClient = SupabaseClient(
      EnvConstants.supabaseUrl,
      EnvConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        authFlowType: AuthFlowType.implicit,
      ),
    );

    try {
      // 1. Sign up the customer using the proper GoTrue Auth API
      final response = await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {'role': 'customer'},
      );

      final newUserId = response.user?.id;
      if (newUserId == null) throw Exception('Failed to create user auth record. Ensure email confirmation is disabled in Supabase.');

      // 2. Link the new auth user id to the customer record using the OWNER's authenticated client
      // (This respects RLS: owners can only update their own customers)
      final updateResponse = await _client
          .from('customers')
          .update({'auth_user_id': newUserId})
          .eq('id', customerId)
          .eq('owner_id', ownerId)
          .select();
          
      if (updateResponse.isEmpty) {
        throw Exception('Failed to link auth account to customer record');
      }
    } finally {
      tempClient.dispose();
    }
  }

  // Transactions
  Future<List<TransactionModel>> getTransactionsForCustomer(String customerId) async {
    final response = await _client
        .from('transactions')
        .select()
        .eq('customer_id', customerId)
        .order('date', ascending: false);
    return (response as List).map((json) => TransactionModel.fromJson(json)).toList();
  }
  
  Future<List<TransactionModel>> getAllTransactions() async {
    // Relies on RLS to only fetch the ones allowed
    final response = await _client
        .from('transactions')
        .select()
        .order('date', ascending: false);
    return (response as List).map((json) => TransactionModel.fromJson(json)).toList();
  }

  Future<TransactionModel> addTransaction(
    String customerId,
    double amount,
    String type, {
    String? title,
    String? note,
    DateTime? dueDate,
  }) async {
    final response = await _client.from('transactions').insert({
      'customer_id': customerId,
      'amount': amount,
      'type': type,
      'title': title,
      'note': note,
      'due_date': dueDate?.toIso8601String(),
      'date': DateTime.now().toIso8601String(),
    }).select().single();

    return TransactionModel.fromJson(response);
  }

  Future<TransactionModel> updateTransaction(
    String transactionId, {
    double? amount,
    String? title,
    String? note,
    DateTime? dueDate,
  }) async {
    final updates = <String, dynamic>{};
    if (amount != null) updates['amount'] = amount;
    if (title != null) updates['title'] = title;
    if (note != null) updates['note'] = note;
    updates['due_date'] = dueDate?.toIso8601String();

    final response = await _client
        .from('transactions')
        .update(updates)
        .eq('id', transactionId)
        .select()
        .single();

    return TransactionModel.fromJson(response);
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _client.from('transactions').delete().eq('id', transactionId);
  }

  // Complaints
  Future<List<ComplaintModel>> getComplaints() async {
    final response = await _client
        .from('complaints')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((json) => ComplaintModel.fromJson(json)).toList();
  }

  Future<ComplaintModel> submitComplaint(String customerId, String ownerId, String message) async {
    final response = await _client.from('complaints').insert({
      'customer_id': customerId,
      'owner_id': ownerId,
      'message': message,
    }).select().single();

    return ComplaintModel.fromJson(response);
  }

  Future<void> resolveComplaint(String complaintId, String newStatus) async {
    await _client.from('complaints').update({'status': newStatus}).eq('id', complaintId);
  }
}
