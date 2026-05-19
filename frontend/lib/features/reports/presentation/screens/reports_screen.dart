import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

class _Report {
  final String title;
  final String patientName;
  final String date;
  final String size;
  final String type;
  final Color typeColor;
  final IconData typeIcon;

  const _Report({
    required this.title,
    required this.patientName,
    required this.date,
    required this.size,
    required this.type,
    required this.typeColor,
    required this.typeIcon,
  });
}

final _mockReports = [
  _Report(
    title: 'Blood Test Report',
    patientName: 'Emily Carter',
    date: 'May 8, 2026',
    size: '1.4 MB',
    type: 'Lab Result',
    typeColor: AppColors.info,
    typeIcon: Icons.science_outlined,
  ),
  _Report(
    title: 'ECG — Cardiology',
    patientName: 'Robert Kim',
    date: 'May 6, 2026',
    size: '2.1 MB',
    type: 'Cardiology',
    typeColor: AppColors.error,
    typeIcon: Icons.monitor_heart_outlined,
  ),
  _Report(
    title: 'MRI Brain Scan',
    patientName: 'Sophia Martinez',
    date: 'May 3, 2026',
    size: '8.7 MB',
    type: 'Radiology',
    typeColor: AppColors.primary,
    typeIcon: Icons.biotech_outlined,
  ),
  _Report(
    title: 'Discharge Summary',
    patientName: 'David Thompson',
    date: 'Apr 28, 2026',
    size: '0.8 MB',
    type: 'Summary',
    typeColor: AppColors.success,
    typeIcon: Icons.summarize_outlined,
  ),
  _Report(
    title: 'Urine Analysis',
    patientName: 'Anna Fischer',
    date: 'Apr 22, 2026',
    size: '0.5 MB',
    type: 'Lab Result',
    typeColor: AppColors.info,
    typeIcon: Icons.science_outlined,
  ),
  _Report(
    title: 'X-Ray Chest PA',
    patientName: 'Mark Johnson',
    date: 'Apr 18, 2026',
    size: '3.2 MB',
    type: 'Radiology',
    typeColor: AppColors.primary,
    typeIcon: Icons.biotech_outlined,
  ),
  _Report(
    title: 'Prescription History',
    patientName: 'Emily Carter',
    date: 'Apr 10, 2026',
    size: '0.3 MB',
    type: 'Prescription',
    typeColor: AppColors.warning,
    typeIcon: Icons.medication_outlined,
  ),
];

const _filterTabs = ['All', 'Last Month', 'Week'];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedFilter = 0;
  String _searchQuery = '';

  List<_Report> get _filtered {
    var list = _mockReports;
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((r) =>
              r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.patientName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.sidebarBg,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => context.go(RouteNames.dashboard),
            ),
            title: const Text(
              'Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                onPressed: () {},
                tooltip: 'Upload Report',
              ),
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
                onPressed: () {},
                tooltip: 'Filter',
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppDimensions.md,
                    0,
                    AppDimensions.md,
                    AppDimensions.md),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search reports...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Colors.white.withOpacity(0.6)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLg),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusLg),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.15)),
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
          ),
          // Filter tabs
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Row(
                children: List.generate(_filterTabs.length, (i) {
                  final isSelected = i == _selectedFilter;
                  return Padding(
                    padding: EdgeInsets.only(
                        right: i < _filterTabs.length - 1 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedFilter = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.md, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusRound),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _filterTabs[i],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            if (i == 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.2)
                                      : AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_mockReports.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // Report list
          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppDimensions.sm),
              itemBuilder: (context, i) =>
                  _ReportItem(report: filtered[i]),
            ),
          ),
          const SliverPadding(
              padding: EdgeInsets.only(bottom: AppDimensions.xl)),
        ],
      ),
    );
  }
}

class _ReportItem extends StatelessWidget {
  final _Report report;

  const _ReportItem({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // File icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: report.typeColor.withOpacity(0.10),
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(report.typeIcon,
                color: report.typeColor, size: 24),
          ),
          const SizedBox(width: AppDimensions.md),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      report.patientName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('·',
                        style: TextStyle(color: AppColors.textDisabled)),
                    const SizedBox(width: 8),
                    Text(
                      report.date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _TypeBadge(
                        label: report.type, color: report.typeColor),
                    const SizedBox(width: 8),
                    Text(
                      report.size,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          Column(
            children: [
              _ActionButton(
                icon: Icons.download_rounded,
                color: AppColors.primary,
                onTap: () {},
              ),
              const SizedBox(height: 6),
              _ActionButton(
                icon: Icons.share_outlined,
                color: AppColors.textSecondary,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
