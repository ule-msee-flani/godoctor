import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/enums.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.local_hospital, size: 56, color: Color(0xFF0F9D6C)),
              const SizedBox(height: 16),
              Text(
                'GoDoctor',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Consult a doctor or order medicine, wherever you are.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              _RoleCard(
                icon: Icons.person_outline,
                title: 'I am a patient',
                subtitle: 'See a doctor or order medicine',
                onTap: () => context.go('/auth/login/${_role(UserRole.patient)}'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.medical_services_outlined,
                title: 'I am a doctor',
                subtitle: 'Accept consultations, issue prescriptions',
                onTap: () => context.go('/auth/login/${_role(UserRole.doctor)}'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.local_pharmacy_outlined,
                title: 'I am a chemist',
                subtitle: 'Manage inventory, fulfill orders',
                onTap: () => context.go('/auth/login/${_role(UserRole.chemist)}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _role(UserRole role) => EnumDbCoding.toDb(role);
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
