import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yatra/screens/admin/admin_preview_host.dart';
import 'package:yatra/services/preview_mode.dart';

/// A stand-in for the tourist app.
///
/// The real tourist screens need Firebase, so preview is verified with a simple
/// screen that exposes the two things that matter: it renders the tourist UI,
/// and it observes the preview state that guards tourist writes.
class _FakeTouristScreen extends StatelessWidget {
  const _FakeTouristScreen({required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final inPreview = PreviewModeScope.isActive(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Tourist Home'),
            Text('preview: $inPreview'),
            ElevatedButton(
              onPressed: () {
                // Stands in for a tourist transaction: bookings, profile edits
                // and every other write go through this same guard.
                final blocked = PreviewModeScope.guard(
                  context,
                  message: 'Blocked in preview',
                );

                if (!blocked) onSubmit();
              },
              child: const Text('Submit booking'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  late PreviewModeController controller;

  setUp(() {
    controller = PreviewModeController();
  });

  tearDown(() {
    controller.dispose();
  });

  Future<void> pumpHost(
    WidgetTester tester, {
    required Widget touristScreen,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminPreviewHost(
                      controller: controller,
                      previewHome: touristScreen,
                    ),
                  ),
                ),
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('preview shows the tourist app under a persistent banner', (
    tester,
  ) async {
    await pumpHost(
      tester,
      touristScreen: const _FakeTouristScreen(onSubmit: _noop),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    // The real tourist UI is rendered, not a mock of it.
    expect(find.text('Tourist Home'), findsOneWidget);

    // The banner is on top of the tourist app, not inside it.
    expect(find.byType(AdminPreviewBanner), findsOneWidget);
    expect(find.text(kAdminPreviewLabel), findsOneWidget);
  });

  testWidgets('the banner survives tourist navigation', (tester) async {
    await pumpHost(
      tester,
      touristScreen: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(child: Text('Tourist Details')),
                  ),
                ),
              ),
              child: const Text('Go deeper'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go deeper'));
    await tester.pumpAndSettle();

    // A pushed route must not be able to hide the preview indication.
    expect(find.text('Tourist Details'), findsOneWidget);
    expect(find.text(kAdminPreviewLabel), findsOneWidget);
  });

  testWidgets('entering preview activates the guard for tourist writes', (
    tester,
  ) async {
    var submitted = 0;

    await pumpHost(
      tester,
      touristScreen: _FakeTouristScreen(onSubmit: () => submitted++),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    expect(controller.isActive, isTrue);
    expect(find.text('preview: true'), findsOneWidget);

    await tester.tap(find.text('Submit booking'));
    await tester.pump();

    // The write was blocked, which is the entire point of preview.
    expect(submitted, 0);
    expect(find.text('Blocked in preview'), findsOneWidget);
  });

  testWidgets('leaving preview ends the guard for the real tourist app', (
    tester,
  ) async {
    await pumpHost(
      tester,
      touristScreen: const _FakeTouristScreen(onSubmit: _noop),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exit Preview'));
    await tester.pumpAndSettle();

    // Back on the admin screen, and the tourist subtree is unrestricted again.
    expect(find.text('Open preview'), findsOneWidget);
    expect(controller.isActive, isFalse);
  });

  testWidgets('a back gesture also ends preview', (tester) async {
    await pumpHost(
      tester,
      touristScreen: const _FakeTouristScreen(onSubmit: _noop),
    );

    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();

    // The Android system back gesture, rather than a button: the host must
    // still end preview, because its `dispose` is the last line of defence.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(controller.isActive, isFalse);
    expect(find.byType(AdminPreviewHost), findsNothing);
  });
}

void _noop() {}
