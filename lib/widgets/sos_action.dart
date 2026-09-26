import 'package:flutter/material.dart';

import '../screens/sos/sos_screen.dart';
import '../theme/app_theme.dart';

/// SOS AppBar action for every top-level tourist screen.
///
/// Tapping it always asks for confirmation first ("Send Emergency SOS?"),
/// then opens the [SosScreen] flow, which reads location on-device, loads the
/// saved Firestore profile, and lets the user share the message. Nothing is
/// sent automatically.
class YatraSosAction extends StatelessWidget {
  const YatraSosAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.emergency_outlined),
      tooltip: 'SOS',
      onPressed: () => confirmSosAndOpen(context),
    );
  }
}

/// Shows the "Send Emergency SOS?" confirmation dialog and, when confirmed,
/// opens the SOS flow. Shared by every SOS entry point so the user always
/// gives an explicit go-ahead before any location work or sharing begins.
Future<void> confirmSosAndOpen(BuildContext context) async {
  final navigator = Navigator.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Send Emergency SOS?'),
      content: const Text(
        'Your current location and emergency message will be prepared for '
        'your emergency contact.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Send SOS'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  navigator.push(MaterialPageRoute(builder: (context) => const SosScreen()));
}
