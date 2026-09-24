import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/google_maps_queries.dart';

/// Minimal Google Maps navigation integration.
///
/// Yatra does not embed the Google Maps SDK and does not require an API key.
/// It hands navigation over to the installed Google Maps app (or the mobile
/// web fallback) using a standard directions deep-link built from the real
/// Yatra travel segment: [from], [to] and [transportation].
///
/// Endpoints are always textual place-name queries resolved by
/// [googleMapsQueryFor] so Google Maps resolves the intended location itself.
/// Yatra coordinates are never passed to external navigation: Google Maps can
/// snap a raw lat/lng pair to an unrelated point of interest (e.g. a nearby
/// office with that exact coordinate) instead of the intended destination.
///
/// Before launching, the tourist is reminded that navigation works best with
/// an offline area downloaded in Google Maps.
class GoogleMapsLauncher {
  GoogleMapsLauncher._();

  /// Overridable in tests to capture the exact URI that would be opened.
  @visibleForTesting
  static Future<bool> Function(Uri uri) openUri = _defaultOpenUri;

  static Future<bool> _defaultOpenUri(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Maps a Yatra transportation mode to a Google Maps travel mode.
  ///
  /// Only explicit ground modes are pinned so an incorrect route is never
  /// forced:
  ///   * Car / Taxi / Jeep / Private Vehicle / Motorbike -> driving
  ///   * Walk / Trek / Hiking -> walking
  ///   * Flight -> no forced mode (opened as point-to-point directions)
  ///   * Bus -> no forced mode (Google transit routing is unreliable in
  ///     remote Nepal, so the map default is left untouched)
  ///   * Unknown / null -> no forced mode
  static String? travelModeFor(String? transportation) {
    if (transportation == null) {
      return null;
    }

    final transport = transportation.toLowerCase().trim();

    if (transport.contains('walk') ||
        transport.contains('trek') ||
        transport.contains('hik')) {
      return 'walking';
    }

    if (transport.contains('flight') || transport.contains('air')) {
      return null;
    }

    if (transport.contains('bus')) {
      return null;
    }

    if (transport.contains('car') ||
        transport.contains('taxi') ||
        transport.contains('jeep') ||
        transport.contains('vehicle') ||
        transport.contains('motor')) {
      return 'driving';
    }

    return null;
  }

  /// Builds the official Google Maps directions URL for a travel segment.
  ///
  /// Uses the [official Google Maps URL scheme]
  /// (https://developers.google.com/maps/documentation/urls/get-url)
  /// `https://www.google.com/maps/dir/?api=1&origin=...&destination=...`.
  ///
  /// Google returns 404 for `/maps/dir` without the trailing slash, so the
  /// path is always `/maps/dir/`. Origin and destination are canonical
  /// place-name queries from [googleMapsQueryFor] (e.g. "Kathmandu, Nepal"),
  /// never coordinates. Query parameters are passed as raw values and encoded
  /// by [Uri] — never pre-encoded.
  static Uri buildDirectionsUri({
    required String from,
    required String to,
    String? transportation,
  }) {
    final mode = travelModeFor(transportation);

    return Uri.https('www.google.com', '/maps/dir/', <String, String>{
      'api': '1',
      'origin': googleMapsQueryFor(from),
      'destination': googleMapsQueryFor(to),
      'travelmode': ?mode,
    });
  }

  /// Shows the offline reminder and opens Google Maps directions when the
  /// tourist confirms. Nothing happens when the reminder is cancelled.
  ///
  /// When the device cannot open Google Maps an error message is shown
  /// instead of crashing.
  static Future<void> launch(
    BuildContext context, {
    required String from,
    required String to,
    String? transportation,
  }) async {
    final openGoogleMaps = await _showOfflineReminder(context);

    if (openGoogleMaps != true || !context.mounted) {
      return;
    }

    final uri = buildDirectionsUri(
      from: from,
      to: to,
      transportation: transportation,
    );

    debugPrint('Google Maps URL: $uri');
    debugPrint('Google Maps origin: ${googleMapsQueryFor(from)}');
    debugPrint('Google Maps destination: ${googleMapsQueryFor(to)}');

    bool opened;

    try {
      opened = await openUri(uri);
    } catch (_) {
      opened = false;
    }

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Google Maps on this device.'),
        ),
      );
    }
  }

  static Future<bool?> _showOfflineReminder(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Map & Offline Access'),
          content: const Text(
            'Yatra uses Google Maps for navigation. If you may travel '
            'without internet, download the required area in Google Maps '
            'before your trip for offline use.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open Google Maps'),
            ),
          ],
        );
      },
    );
  }
}
