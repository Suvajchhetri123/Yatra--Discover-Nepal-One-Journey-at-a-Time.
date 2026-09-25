import 'package:flutter/material.dart';

import '../models/itinerary_booking.dart';
import '../theme/app_theme.dart';
import 'yatra_components.dart';

/// Colours used for each booking status across the app (centralized so the
/// tourist and admin UIs never disagree).
Color bookingStatusColor(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return AppColors.warning;
    case BookingStatus.confirmed:
      return AppColors.success;
    case BookingStatus.cancelled:
      return AppColors.danger;
    case BookingStatus.completed:
      return AppColors.primary;
  }
}

/// A soft pill showing a booking status label and its colour.
class BookingStatusChip extends StatelessWidget {
  final BookingStatus status;

  const BookingStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return YatraStatusBadge(
      label: status.label,
      color: bookingStatusColor(status),
    );
  }
}
