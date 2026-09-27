import '../../data/models/medication.dart';
import '../../data/models/prescription.dart';

/// One medicine as written on a prescription: name, the dose as the doctor
/// wrote it, and "Take N times daily for N days" when the dose says so.
class RxLine {
  const RxLine({
    required this.name,
    required this.quantity,
    this.form,
    this.dose,
    this.timesDaily,
    this.days,
    this.note,
  });

  final String name;
  final String? form;
  final String? dose;
  final int? timesDaily;
  final int? days;
  final int quantity;
  final String? note;

  factory RxLine.of(PrescriptionItem i) {
    final perDay = dosesPerDayIn(i.dosage, i.instructions);
    return RxLine(
      name: i.displayName,
      form: i.drug?.form,
      dose: (i.dosage ?? '').trim().isEmpty ? null : i.dosage!.trim(),
      timesDaily: perDay,
      days: courseDaysIn(
        dosage: i.dosage,
        instructions: i.instructions,
        quantity: i.quantity,
        perDay: perDay,
      ),
      quantity: i.quantity,
      note: (i.instructions ?? '').trim().isEmpty
          ? null
          : i.instructions!.trim(),
    );
  }

  String get timesLabel => timesDaily == 1 ? 'once' : '$timesDaily times';
}

/// Short reference printed on the prescription.
String rxReference(String? id) =>
    id == null ? '' : id.substring(0, id.length.clamp(0, 8)).toUpperCase();
