import 'package:flutter/material.dart';

/// A single transportation mode available for a destination.
///
/// This is the shared typed representation used by both
/// [TransportationScreen] and [BoardingScreen] so that they agree
/// about which modes are available for each destination.
class TransportationOption {
  /// Canonical mode name, e.g. 'Flight', 'Jeep', 'Bus'.
  final String name;

  /// Icon shown in the UI.
  final IconData icon;

  /// Short description line.
  final String description;

  /// Additional detail line.
  final String details;

  const TransportationOption({
    required this.name,
    required this.icon,
    required this.description,
    required this.details,
  });
}
