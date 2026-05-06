import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_model.dart';
import '../models/transaction_model.dart';

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

  // Customers
  Future<List<CustomerModel>> getCustomers() async {
    final response = await _client.from('customers').select().order('created_at', ascending: false);
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
    String? note,
  }) async {
    final response = await _client.from('transactions').insert({
      'customer_id': customerId,
      'amount': amount,
      'type': type,
      'note': note,
      'date': DateTime.now().toIso8601String(),
    }).select().single();

    return TransactionModel.fromJson(response);
  }
}
