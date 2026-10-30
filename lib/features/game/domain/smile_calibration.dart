/// Derives hysteresis thresholds from neutral and natural-smile samples.
/// Samples are probabilities only; camera images are never retained here.
class SmileCalibration {
  const SmileCalibration({required this.enter, required this.exit});

  final double enter;
  final double exit;

  bool get isValid =>
      enter.isFinite &&
      exit.isFinite &&
      exit >= 0 &&
      enter <= 1 &&
      enter > exit &&
      enter - exit >= .04;

  static SmileCalibration? fromSamples({
    required Iterable<double?> neutral,
    required Iterable<double?> smile,
    int minimumSamples = 8,
  }) {
    List<double> valid(Iterable<double?> samples) =>
        samples
            .whereType<double>()
            .where((p) => p.isFinite && p >= 0 && p <= 1)
            .toList()
          ..sort();
    double median(List<double> values) {
      final middle = values.length ~/ 2;
      return values.length.isOdd
          ? values[middle]
          : (values[middle - 1] + values[middle]) / 2;
    }

    final neutralValues = valid(neutral);
    final smileValues = valid(smile);
    if (neutralValues.length < minimumSamples ||
        smileValues.length < minimumSamples) {
      return null;
    }
    final baseline = median(neutralValues);
    final smiling = median(smileValues);
    final separation = smiling - baseline;
    if (separation < .15) return null;
    return SmileCalibration(
      enter: baseline + separation * .65,
      exit: baseline + separation * .30,
    );
  }
}
