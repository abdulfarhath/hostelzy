import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// F14 board 12: the A4 resident QR poster as a real PDF, in the app's fonts
/// and colours. [link] is the hostel's invite link.
Future<Uint8List> residentPoster({required String hostel, required String link}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Archivo-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Archivo-ExtraBold.ttf'));
  const ink = PdfColor.fromInt(0xFF201E1D), red = PdfColor.fromInt(0xFFEC3013), mu = PdfColor.fromInt(0xFF605D5D);
  pw.TextStyle st(double size, {bool b = false, PdfColor c = ink}) => pw.TextStyle(font: b ? bold : regular, fontSize: size, color: c);
  final doc = pw.Document(title: 'Join $hostel on Hostelzy', author: 'Hostelzy');
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('hostelzy', style: st(22, b: true)), pw.Text(hostel.toUpperCase(), style: st(11, c: mu))]),
          pw.SizedBox(height: 28),
          pw.Text('Join your hostel on Hostelzy', style: st(44, b: true)),
          pw.SizedBox(height: 24),
          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: ink, width: 3)),
              child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: link, width: 260, height: 260, color: ink),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Text(link.replaceFirst('https://', ''), style: st(18, b: true))),
          pw.SizedBox(height: 28),
          for (final (t, d) in const [('Pay rent', 'Straight to the owner by UPI, with a receipt'), ('Raise complaints', 'Track them until they are fixed'), ('See the food menu', 'The whole week, updated by the owner')])
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: ink, width: 2))),
              child: pw.Row(children: [pw.Expanded(child: pw.Text(t, style: st(20, b: true))), pw.Text(d, style: st(12, c: mu))]),
            ),
          pw.SizedBox(height: 18),
          pw.Container(
            color: red,
            padding: const pw.EdgeInsets.all(14),
            child: pw.Text('Scan  >  Sign in with Google, one tap  >  Confirm your bed', style: st(18, b: true, c: PdfColors.white)),
          ),
          pw.Spacer(),
          pw.Text('Hostelzy never asks for your password or UPI PIN.', style: st(12, b: true)),
        ],
      ),
    ),
  );
  return doc.save();
}
