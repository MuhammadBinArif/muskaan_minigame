import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muskaan_minigame/shared/widgets/food_illustrations.dart';

Future<List<int>> pixels(FoodPainter painter, int size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Size.square(size.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData();
  final result = data!.buffer.asUint8List().toList();
  image.dispose();
  picture.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'supplied artwork is deterministic and fillings remain distinct',
    () async {
      const masala = FoodPainter(pani: false);
      const pani = FoodPainter(pani: true);
      for (final size in [24, 72, 180]) {
        final first = await pixels(masala, size);
        expect(first.any((value) => value != 0), isTrue);
        expect(await pixels(masala, size), first);
        expect(await pixels(pani, size), isNot(first));
      }
    },
  );

  test('texture is bounded for invalid or excessive input', () async {
    for (final texture in [double.nan, double.infinity, -1.0, 1e12]) {
      expect(
        await pixels(FoodPainter(pani: false, texture: texture), 32),
        isNotEmpty,
      );
    }
  });

  testWidgets('existing icon sizes retain their layout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: GolgappaIcon(size: 72))),
    );
    expect(tester.getSize(find.byType(GolgappaIcon)), const Size.square(72));
    expect(tester.takeException(), isNull);
  });

  test('optional artwork preview', () async {
    final destination = Platform.environment['MUSKAAN_ART_PREVIEW'];
    if (destination == null) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF182031), BlendMode.src);
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(i * 180, 0);
      FoodPainter(
        pani: i.isOdd,
        crust: GolgappaCrust.values[i],
      ).paint(canvas, const Size.square(180));
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(720, 180);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(destination).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
