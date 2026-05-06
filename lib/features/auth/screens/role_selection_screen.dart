import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/auth_controller.dart';
import '../../../shared/widgets/custom_button.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.storefront,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to CreditApp',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your role to continue',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textLight,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              CustomButton(
                text: 'Continue as Owner',
                onPressed: () {
                  ref.read(selectedRoleProvider.notifier).setRole('owner');
                  context.push('/login');
                },
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Continue as Customer',
                isSecondary: true,
                onPressed: () {
                  ref.read(selectedRoleProvider.notifier).setRole('customer');
                  context.push('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
