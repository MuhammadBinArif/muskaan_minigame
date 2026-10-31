import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:muskaan_minigame/shared/widgets/food_illustrations.dart';

void main() {
  testWidgets('welcome preview shows animated falling food', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    final food = find.byType(GolgappaIcon);
    expect(food, findsNWidgets(2));
    final firstPosition = tester.getTopLeft(food.first);
    final secondPosition = tester.getTopLeft(food.last);

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(food.first).dy, greaterThan(firstPosition.dy));
    expect(tester.getTopLeft(food.last).dy, greaterThan(secondPosition.dy));
    expect(tester.takeException(), isNull);
  });
}
