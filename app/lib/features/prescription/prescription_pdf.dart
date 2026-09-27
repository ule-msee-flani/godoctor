import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/utils/format.dart';
import 'rx_line.dart';

/// Everything printed on the PDF copy of a prescription.
class PrescriptionPdfData {
  const PrescriptionPdfData({
    required this.doctorName,
    required this.patientName,
    required this.issuedAt,
    required this.lines,
    this.doctorDetail,
    this.patientAge,
    this.patientGender,
    this.validUntil,
    this.reference,
  });

  final String doctorName;
  final String? doctorDetail;
  final String patientName;
  final int? patientAge;
  final String? patientGender;
  final DateTime issuedAt;
  final DateTime? validUntil;
  final String? reference;
  final List<RxLine> lines;
}

const _rule = PdfColor.fromInt(0xFF7FA8D9);
const _navy = PdfColor.fromInt(0xFF16305C);
const _ink = PdfColor.fromInt(0xFF0B1730);
const _soft = PdfColor.fromInt(0xFF57617A);

/// The PDF's built-in fonts only cover Latin-1: swap the few characters
/// that aren't (dashes, curly quotes) and drop anything else.
String pdfSafe(String s) => s
    .replaceAll(RegExp('[–—]'), '-')
    .replaceAll(RegExp('[‘’]'), "'")
    .replaceAll(RegExp('[“”]'), '"')
    .replaceAll('…', '...')
    .replaceAll(RegExp(r'[^\x00-\xFF]'), '');

/// Builds the A4 PDF (same layout as the on-screen prescription).
Future<Uint8List> buildPrescriptionPdf(
  PrescriptionPdfData d, {
  Uint8List? logo,
}) async {
  final doc = pw.Document(
    title: 'GoDoctor prescription ${rxReference(d.reference)}',
    author: pdfSafe(d.doctorName),
  );
  final serif = pw.Font.timesBold();
  final sign = pw.Font.timesBoldItalic();
  final base = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();

  pw.Widget blank(String label, String? value) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Text(
        '$label:',
        style: pw.TextStyle(font: base, fontSize: 10, color: _navy),
      ),
      pw.SizedBox(width: 6),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 2),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.8)),
          ),
          child: pw.Text(
            pdfSafe(value ?? ''),
            style: pw.TextStyle(font: bold, fontSize: 11, color: _ink),
          ),
        ),
      ),
    ],
  );

  pw.Widget ruled(String text, {bool strong = false}) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.only(bottom: 3),
    margin: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.6)),
    ),
    child: pw.Text(
      pdfSafe(text),
      style: pw.TextStyle(
        font: strong ? bold : base,
        fontSize: strong ? 12 : 11,
        color: _ink,
      ),
    ),
  );

  pw.Widget fill(String text) => pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(6, 0, 6, 1),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.8)),
    ),
    child: pw.Text(text, style: pw.TextStyle(font: bold, fontSize: 11)),
  );

  final label = pw.TextStyle(font: base, fontSize: 10, color: _navy);
  final ref = rxReference(d.reference);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 44),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.ClipRRect(
                  horizontalRadius: 10,
                  verticalRadius: 10,
                  child: pw.Image(pw.MemoryImage(logo), width: 52, height: 52),
                ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'GoDoctor',
                    style: pw.TextStyle(font: bold, fontSize: 16, color: _navy),
                  ),
                  pw.Text(
                    'Digital prescription',
                    style: pw.TextStyle(font: base, fontSize: 10, color: _rule),
                  ),
                  if (ref.isNotEmpty)
                    pw.Text(
                      'Ref $ref',
                      style: pw.TextStyle(
                        font: base,
                        fontSize: 10,
                        color: _rule,
                      ),
                    ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(height: 1.6, color: _rule),
          pw.SizedBox(height: 16),
        ],
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(font: base, fontSize: 8, color: _soft),
        ),
      ),
      build: (_) => [
        pw.Row(
          children: [
            pw.Expanded(flex: 3, child: blank('Patient', d.patientName)),
            pw.SizedBox(width: 18),
            pw.Expanded(flex: 2, child: blank('Date', formatDate(d.issuedAt))),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(flex: 3, child: blank('Age', d.patientAge?.toString())),
            pw.SizedBox(width: 18),
            pw.Expanded(flex: 2, child: blank('Gender', d.patientGender)),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Rx',
          style: pw.TextStyle(font: serif, fontSize: 40, color: _navy),
        ),
        pw.SizedBox(height: 10),
        for (var i = 0; i < d.lines.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 14),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 22,
                  child: pw.Text(
                    '${i + 1}.',
                    style: pw.TextStyle(font: bold, fontSize: 12),
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      ruled(
                        [
                          d.lines[i].name,
                          if (d.lines[i].form != null) '(${d.lines[i].form})',
                        ].join(' '),
                        strong: true,
                      ),
                      if (d.lines[i].dose != null) ruled(d.lines[i].dose!),
                      if (d.lines[i].timesDaily != null ||
                          d.lines[i].days != null)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 6),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              if (d.lines[i].timesDaily != null) ...[
                                pw.Text('Take ', style: label),
                                fill(d.lines[i].timesLabel),
                                pw.Text(' daily ', style: label),
                              ],
                              if (d.lines[i].days != null) ...[
                                pw.Text('for ', style: label),
                                fill('${d.lines[i].days}'),
                                pw.Text(
                                  d.lines[i].days == 1 ? ' day.' : ' days.',
                                  style: label,
                                ),
                              ],
                            ],
                          ),
                        ),
                      pw.Text(
                        pdfSafe(
                          [
                            'Quantity: ${d.lines[i].quantity}',
                            if (d.lines[i].note != null) d.lines[i].note!,
                          ].join('   -   '),
                        ),
                        style: pw.TextStyle(
                          font: base,
                          fontSize: 9,
                          color: _soft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 18),
        pw.Container(height: 1, color: _rule),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    d.validUntil == null
                        ? 'Issued ${formatDate(d.issuedAt)}'
                        : 'Valid until ${formatDate(d.validUntil!)}',
                    style: pw.TextStyle(font: base, fontSize: 10, color: _navy),
                  ),
                  pw.Text(
                    'Issued through GoDoctor',
                    style: pw.TextStyle(font: base, fontSize: 9, color: _rule),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  pdfSafe(d.doctorName),
                  style: pw.TextStyle(font: sign, fontSize: 20, color: _navy),
                ),
                pw.Container(
                  width: 170,
                  height: 0.8,
                  margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  color: _rule,
                ),
                pw.Text(
                  pdfSafe(
                    [
                      d.doctorName,
                      if (d.doctorDetail != null && d.doctorDetail!.isNotEmpty)
                        d.doctorDetail!,
                    ].join(', '),
                  ),
                  style: pw.TextStyle(font: base, fontSize: 9, color: _soft),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// Makes the PDF and opens the share sheet (save to files, WhatsApp, email,
/// print...).
Future<void> sharePrescriptionPdf(PrescriptionPdfData d) async {
  Uint8List? logo;
  try {
    // A small copy keeps the PDF light enough to send on WhatsApp.
    logo = (await rootBundle.load(
      'assets/logo/app_icon_small.png',
    )).buffer.asUint8List();
  } catch (_) {}
  final bytes = await buildPrescriptionPdf(d, logo: logo);
  final ref = rxReference(d.reference);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
      fileNameOverrides: [
        'GoDoctor-prescription${ref.isEmpty ? '' : '-$ref'}.pdf',
      ],
      subject: 'Prescription from ${d.doctorName}',
    ),
  );
}
