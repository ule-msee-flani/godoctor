import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
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
                    return const EmptyView(message: 'No medicines found.');
                  }
                  return ListView.builder(
                    itemCount: drugs.length,
                    itemBuilder: (context, i) {
                      final drug = drugs[i];
                      return ListTile(
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(drug.displayName),
                        subtitle: Text(
                          [
                            if (drug.form != null) drug.form!,
                            if (drug.requiresPrescription) 'Prescription required',
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/patient/chemist-select/${drug.id}'),
                      );
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
