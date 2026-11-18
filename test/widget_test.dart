import 'package:cotopole/core/theme/app_theme.dart';
import 'package:cotopole/core/widgets/common.dart';
import 'package:cotopole/core/widgets/gradient_button.dart';
import 'package:cotopole/core/widgets/pin_pad.dart';
import 'package:cotopole/data/models/models.dart';
import 'package:cotopole/features/auth/pin_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('GradientButton fires when enabled and not when disabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(GradientButton(label: 'Submit', onPressed: () => taps++)));
    await tester.tap(find.text('Submit'));
    expect(taps, 1);

    await tester.pumpWidget(_wrap(const GradientButton(label: 'Submit', onPressed: null)));
    await tester.tap(find.text('Submit'), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('PinEntryView reports the full PIN and shows the error', (tester) async {
    String? received;
    await tester.pumpWidget(_wrap(SingleChildScrollView(
      child: PinEntryView(
        title: 'Enter PIN',
        onCompleted: (pin) async {
          received = pin;
          return 'Wrong PIN';
        },
      ),
    )));
    for (final d in ['4', '8', '2', '9', '1', '5']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(received, '482915');
    expect(find.text('Wrong PIN'), findsOneWidget);
    expect(find.byType(PinDots), findsOneWidget);
  });

  testWidgets('RatingSelector toggles a rating on and off', (tester) async {
    LeadRating? value;
    await tester.pumpWidget(_wrap(StatefulBuilder(
      builder: (context, setState) => RatingSelector(
        value: value,
        onChanged: (r) => setState(() => value = r),
      ),
    )));
    await tester.tap(find.text('Hot'));
    await tester.pump();
    expect(value, LeadRating.hot);
    await tester.tap(find.text('Hot'));
    await tester.pump();
    expect(value, isNull);
  });
}
