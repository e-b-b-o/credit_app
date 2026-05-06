import 'package:flutter/material.dart';

class CustomerHistoryScreen extends StatelessWidget {
  const CustomerHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: const Center(
        child: Text('History coming soon!'),
      ),
    );
  }
}
