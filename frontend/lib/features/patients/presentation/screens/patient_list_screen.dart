import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/entities/patient_entity.dart';
import '../providers/patient_provider.dart';
import '../widgets/patient_card.dart';

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() =>
      _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Always reload from SQLite when the screen is created so data is
    // fresh after login, logout-and-relogin, or app restart.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(patientsProvider.notifier).loadPatients(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(patientsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _PatientAppBar(
            searchController: _searchController,
            onSearch: (q) =>
                ref.read(patientsProvider.notifier).search(q),
            onBack: () => context.go(RouteNames.dashboard),
            onSync: () =>
                ref.read(patientsProvider.notifier).syncNow(),
          ),
        ],
        body: Builder(
          builder: (context) {
            if (state.isLoading) {
              return const AppLoader(message: 'Loading patients...');
            }
            if (state.failure != null && state.patients.isEmpty) {
              return AppErrorWidget(
                failure: state.failure,
                onRetry: () => ref
                    .read(patientsProvider.notifier)
                    .loadPatients(refresh: true),
              );
            }
            if (state.patients.isEmpty) {
              return _EmptyState(query: state.searchQuery);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppDimensions.md),
              itemCount: state.patients.length +
                  (state.isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppDimensions.sm),
              itemBuilder: (context, i) {
                if (i == state.patients.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppDimensions.md),
                    child: AppLoader(size: 32),
                  );
                }
                return PatientCard(
                  patient: state.patients[i],
                  isPending: state.pendingSyncIds
                      .contains(state.patients[i].id),
                  onTap: () => context.go(
                      '${RouteNames.patients}/${state.patients[i].id}'),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(RouteNames.patientCreate),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Patient',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PatientAppBar extends ConsumerWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onBack;
  final VoidCallback onSync;

  const _PatientAppBar({
    required this.searchController,
    required this.onSearch,
    required this.onBack,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pendingIds = ref.watch(
      patientsProvider.select((s) => s.pendingSyncIds),
    );
    final hasPending = pendingIds.isNotEmpty;

    final IconData syncIcon;
    final Color syncColor;
    final String syncTooltip;

    if (!isOnline) {
      syncIcon = Icons.sync_disabled;
      syncColor = AppColors.textSecondary;
      syncTooltip = 'Offline — changes will sync when online';
    } else if (hasPending) {
      syncIcon = Icons.sync;
      syncColor = AppColors.primary;
      syncTooltip = 'Sync ${pendingIds.length} pending changes';
    } else {
      syncIcon = Icons.cloud_done_outlined;
      syncColor = AppColors.success;
      syncTooltip = 'All changes synced';
    }

    return SliverAppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      floating: true,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          const Expanded(
            child: Text(
              'Search Patient',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Tooltip(
            message: syncTooltip,
            child: IconButton(
              onPressed: isOnline && hasPending ? onSync : null,
              icon: Icon(syncIcon, size: 22, color: syncColor),
              splashRadius: 20,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.tune_rounded,
                size: 18, color: AppColors.textPrimary),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppDimensions.md, 0, AppDimensions.md, AppDimensions.md),
          child: TextField(
            controller: searchController,
            onChanged: onSearch,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search by name, phone, blood type...',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          color: AppColors.textSecondary, size: 18),
                      onPressed: () {
                        searchController.clear();
                        onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md, vertical: 14),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLg),
                borderSide:
                    const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLg),
                borderSide:
                    const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusLg),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? query;

  const _EmptyState({this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_rounded,
                size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            query != null ? 'No results for "$query"' : 'No patients yet',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try a different search term or add a new patient',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
