import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'settings_service.dart';

/// Plain document data used by both PDF and Bluetooth receipt printing.
class PrintDoc {
  final String title; // e.g. INVOICE
  final String number; // e.g. #233
  final DateTime date;
  final List<String> partyLines; // shop name, khata, phone ...
  final List<String> headers;
  final List<List<String>> rows;
  final List<MapEntry<String, String>> totals;
  final String note;

  PrintDoc({
    required this.title,
    this.number = '',
    DateTime? date,
    this.partyLines = const [],
    required this.headers,
    required this.rows,
    this.totals = const [],
    this.note = '',
  }) : date = date ?? DateTime.now();
}

class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  static const _navy = PdfColor.fromInt(0xFF0F3460);
  static const _light = PdfColor.fromInt(0xFFEFF4FF);

  Future<Uint8List> build(PrintDoc d, {bool landscape = false}) async {
    final s = SettingsService.instance;
    final doc = pw.Document();
    final df = DateFormat('dd-MM-yyyy hh:mm a');

    doc.addPage(
      pw.MultiPage(
        pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(s.businessName,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _navy)),
                  if (s.businessAddress.isNotEmpty) pw.Text(s.businessAddress, style: const pw.TextStyle(fontSize: 9)),
                  if (s.businessPhone.isNotEmpty) pw.Text(s.businessPhone, style: const pw.TextStyle(fontSize: 9)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(d.title,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _navy)),
                  if (d.number.isNotEmpty) pw.Text(d.number, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(df.format(d.date), style: const pw.TextStyle(fontSize: 9)),
                ]),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: _navy, thickness: 1.2),
            pw.SizedBox(height: 6),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(s.invoiceFooter, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
        build: (ctx) => [
          if (d.partyLines.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              margin: const pw.EdgeInsets.only(bottom: 10),
              decoration: pw.BoxDecoration(color: _light, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < d.partyLines.length; i++)
                    pw.Text(d.partyLines[i],
                        style: pw.TextStyle(
                            fontSize: i == 0 ? 11 : 9, fontWeight: i == 0 ? pw.FontWeight.bold : null)),
                ],
              ),
            ),
          pw.TableHelper.fromTextArray(
            headers: d.headers,
            data: d.rows,
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _navy),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            oddRowDecoration: const pw.BoxDecoration(color: _light),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
          if (d.totals.isNotEmpty) pw.SizedBox(height: 10),
          if (d.totals.isNotEmpty)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 230,
                child: pw.Column(children: [
                  for (final t in d.totals)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(t.key, style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(t.value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                ]),
              ),
            ),
          if (d.note.isNotEmpty) pw.SizedBox(height: 12),
          if (d.note.isNotEmpty) pw.Text(d.note, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
    return doc.save();
  }

  /// Opens the Android share sheet (WhatsApp etc.)
  Future<void> share(PrintDoc d, String filename, {bool landscape = false}) async {
    final bytes = await build(d, landscape: landscape);
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Opens the Android print dialog.
  Future<void> printDoc(PrintDoc d, {bool landscape = false}) async {
    final bytes = await build(d, landscape: landscape);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: d.title);
  }
}
