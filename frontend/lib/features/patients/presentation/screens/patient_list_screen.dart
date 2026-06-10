import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/patient_entity.dart';
import '../providers/patient_provider.dart';

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(patientsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Patients',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(patientsProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/patients/register'),
        icon: const Icon(Icons.person_add),
        label: const Text('New Patient'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, PRN or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(patientsProvider.notifier).search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => ref.read(patientsProvider.notifier).search(v),
            ),
          ),
          Expanded(
            child: state.isLoading && state.patients.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.patients.isEmpty
                    ? _EmptyState(
                        hasSearch: state.search?.isNotEmpty == true)
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount:
                            state.patients.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == state.patients.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child:
                                  Center(child: CircularProgressIndicator()),
                            );
                          }
                          return _PatientCard(
                            patient: state.patients[i],
                            onTap: () => context
                                .push('/patients/${state.patients[i].id}'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final PatientEntity patient;
  final VoidCallback onTap;
  const _PatientCard({required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  patient.initials,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (patient.ageSex.isNotEmpty) patient.ageSex,
                        'PRN: ${patient.prn}',
                      ].join('  ·  '),
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    if (patient.phone?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(patient.phone!,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No patients found' : 'No patients yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600]),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 8),
            Text('Tap + to register a new patient',
                style: TextStyle(color: Colors.grey[400])),
          ],
        ],
      ),
    );
  }
}
