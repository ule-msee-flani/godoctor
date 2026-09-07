import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/drug.dart';
import '../../../data/providers/repository_providers.dart';

final _searchQueryProvider = StateProvider<String>((ref) => '');

final _searchResultsProvider = FutureProvider<List<Drug>>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  return ref.watch(drugRepositoryProvider).searchDrugs(query);
});

class MedicineSearchScreen extends ConsumerStatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  ConsumerState<MedicineSearchScreen> createState() =>
      _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends ConsumerState<MedicineSearchScreen> {
  Timer? _debounce;
  final _controller = TextEditingController();

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_searchQueryProvider.notifier).state = value;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(_searchResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order Medicine')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(14),
                    child: Icon(LucideIcons.search, size: 20),
                  ),
                  hintText: 'Search for a medicine, e.g. Paracetamol',
                ),
              ),
            ),
            Expanded(
              child: results.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(message: '$e'),
                data: (drugs) {
                  if (drugs.isEmpty) {
                    return const EmptyView(
                      message: 'No medicines found.',
                      icon: LucideIcons.search,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: drugs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final drug = drugs[i];
                      return _DrugTile(drug: drug);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrugTile extends StatelessWidget {
  const _DrugTile({required this.drug});

  final Drug drug;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/patient/chemist-select/${drug.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.accentTealSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.pill,
                    color: AppColors.accentTeal,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(drug.displayName, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (drug.form != null) ...[
                          Text(drug.form!, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(width: 8),
                        ],
                        if (drug.requiresPrescription)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warningSoft,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Rx required',
                              style: TextStyle(color: AppColors.warning, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: AppColors.inkFaint,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
