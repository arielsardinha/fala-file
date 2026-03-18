import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

abstract class PDFDataSource {
  Future<String> extractText(String filePath);
}

class PDFDataSourceImpl implements PDFDataSource {
  @override
  Future<String> extractText(String filePath) async {
    final File file = File(filePath);
    final List<int> bytes = await file.readAsBytes();

    // Use compute to run text extraction in a separate isolate
    // to avoid blocking the main UI thread.
    return await compute(_extractTextFromBytes, bytes);
  }

  static String _extractTextFromBytes(List<int> bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);

    final String text = extractor.extractText();
    
    document.dispose();
    return text;
  }
}
