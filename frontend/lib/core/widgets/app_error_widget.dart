import 'package:flutter/material.dart';

import '../error/failures.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'app_button.dart';

class AppErrorWidget extends StatelessWidget {
  final Failure? failure;
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    this.failure,
    this.message,
    this.onRetry,
  }) : assert(failure != null || message != null);

  @override
  Widget build(BuildContext context) {
    final displayMessage = message ?? _mapFailureToMessage(failure!);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(failure),
              size: 64,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              _titleFor(failure),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              displayMessage,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimensions.lg),
              AppButton(
                label: 'Try Again',
                onPressed: onRetry,
                isFullWidth: false,
                leadingIcon: Icons.refresh,
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _titleFor(Failure? failure) => switch (failure) {
        NetworkFailure() => 'No Connection',
        AuthFailure() => 'Session Expired',
        NotFoundFailure() => 'Not Found',
        _ => 'Something Went Wrong',
      };

  IconData _iconFor(Failure? failure) => switch (failure) {
        NetworkFailure() => Icons.wifi_off_rounded,
        AuthFailure() => Icons.lock_outline_rounded,
        NotFoundFailure() => Icons.search_off_rounded,
        _ => Icons.error_outline_rounded,
      };

  String _mapFailureToMessage(Failure failure) => switch (failure) {
        NetworkFailure f => f.message,
        ServerFailure f => f.message,
        AuthFailure _ =>
          'Your session has expired. Please log in again.',
        ValidationFailure f => f.message,
        NotFoundFailure f => f.message,
        CacheFailure _ => 'Failed to load cached data.',
        _ => 'An unexpected error occurred. Please try again.',
      };
}
