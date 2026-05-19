import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/api/api_service.dart';

class TransactionModel {
  final String id;
  final DateTime date;
  final String invoiceNumber;
  final String branchName;
  final String customerName;
  final String serviceName;
  final double amount;

  TransactionModel({
    required this.id, required this.date, required this.invoiceNumber, required this.branchName,
    required this.customerName, required this.serviceName, required this.amount,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    String bName = 'Herik Salon';
    if (json['branchId'] is Map && json['branchId']['name'] != null) {
      bName = json['branchId']['name'].toString();
    } else if (json['branchName'] != null) {
      bName = json['branchName'].toString();
    }

    String cName = 'Walk-In Customer';
    if (json['visitorId'] is Map && json['visitorId']['name'] != null) {
      cName = json['visitorId']['name'].toString();
    } else if (json['visitorName'] != null) {
      cName = json['visitorName'].toString();
    } else if (json['customerName'] != null) {
      cName = json['customerName'].toString();
    }

    String sName = 'Salon Service';
    if (json['services'] is List && (json['services'] as List).isNotEmpty) {
      var firstService = json['services'][0];
      if (firstService is Map && firstService['name'] != null) {
        sName = firstService['name'].toString();
      } else if (firstService is String) {
        sName = 'Custom Service';
      }
    } else if (json['serviceName'] != null) {
      sName = json['serviceName'].toString();
    }

    String generatedInvoice = 'INV-0000';
    if (json['invoiceNumber'] != null) {
      generatedInvoice = json['invoiceNumber'].toString();
    } else if (json['_id'] != null && json['_id'].toString().length >= 6) {
      generatedInvoice = 'INV-${json['_id'].toString().substring(0, 6).toUpperCase()}';
    }

    return TransactionModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['endTime']?.toString() ?? json['createdAt']?.toString() ?? json['date']?.toString() ?? '') ?? DateTime.now(),
      invoiceNumber: generatedInvoice,
      branchName: bName,
      customerName: cName,
      serviceName: sName,
      amount: (json['finalPrice'] ?? json['totalBasePrice'] ?? json['amount'] ?? 0).toDouble(),
    );
  }
}

class RevenueProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<TransactionModel> transactions = [];
  double totalRevenue = 0.0;
  List<dynamic> branches = [];
  
  // 🚀 Added Pagination Tracking Variables
  int totalPages = 1;
  int totalItems = 0;

  Future<void> fetchInitialData(String role, String branchId) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (role == 'ADMIN' || role == 'OWNER' || role == 'MANAGER') {
        branches = await _apiService.getBranches();
      }
      await fetchRevenueData(role == 'STAFF' ? branchId : 'all');
    } catch (e) {
      debugPrint("Initial Fetch Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🚀 FIXED: Added page parameter to trigger backend pagination
  Future<void> fetchRevenueData(String targetBranch, {String? startDate, String? endDate, String? serviceId, String? search, int page = 1}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Passes page down to api_service
      final response = await _apiService.getBranchRevenue(
        targetBranch, startDate: startDate, endDate: endDate, serviceId: serviceId, search: search, page: page
      );
      
      // 🚀 Safe Extraction for Map (Paginated API) vs List
      List<dynamic> dataList = [];
      if (response is Map) {
        dataList = response['data'] as List? ?? [];
        totalPages = response['totalPages'] ?? 1;
        totalItems = response['totalItems'] ?? 0;
      } else if (response is List) {
        dataList = response as List<dynamic>;
        totalPages = 1;
        totalItems = dataList.length;
      }
      
      transactions = dataList.map((json) => TransactionModel.fromJson(json)).toList();
      totalRevenue = transactions.fold(0.0, (sum, item) => sum + item.amount);

    } catch (e) {
      debugPrint("Revenue Fetch Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> exportToExcel() async {
    debugPrint("Exporting to Excel...");
  }

  // =========================================================================
  // 🎨 MINIMALIST INVOICE DESIGN
  // =========================================================================
  Future<pw.Document> _generateInvoicePdf(TransactionModel transaction, bool applyGst) async {
    final pdf = pw.Document();

    pw.ImageProvider? logoImage;
    try {
      final ByteData imageBytes = await rootBundle.load('assets/herik_logo.png');
      final Uint8List logoData = imageBytes.buffer.asUint8List();
      logoImage = pw.MemoryImage(logoData);
    } catch (e) {
      debugPrint("Could not load logo image: $e");
    }

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final double baseAmount = transaction.amount;
    final double gstAmount = applyGst ? (baseAmount * 0.18) : 0.0;
    final double totalAmount = baseAmount + gstAmount;
    final dateStr = "${transaction.date.day.toString().padLeft(2, '0')}/${transaction.date.month.toString().padLeft(2, '0')}/${transaction.date.year}";

    final textDark = PdfColor.fromHex('#333333');
    final textLight = PdfColor.fromHex('#666666');
    final headerBgColor = PdfColor.fromHex('#E8CBB3'); 
    final logoBgColor = PdfColor.fromHex('#1E1E1E'); 

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(50), 
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold), 
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 140,
                    height: 140,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      color: logoBgColor,
                      borderRadius: pw.BorderRadius.circular(8)
                    ),
                    child: logoImage != null
                        ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                        : pw.Text('HERIK\nSALON', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE', style: pw.TextStyle(fontSize: 28, letterSpacing: 2, fontWeight: pw.FontWeight.normal, color: textDark)),
                      pw.SizedBox(height: 12),
                      pw.Text('Herik Family Salon', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textLight)),
                      pw.Text('${transaction.branchName} Branch', style: pw.TextStyle(fontSize: 10, color: textLight)),
                      pw.Text('Ahmedabad, Gujarat', style: pw.TextStyle(fontSize: 10, color: textLight)),
                      pw.Text('India', style: pw.TextStyle(fontSize: 10, color: textLight)),
                      pw.SizedBox(height: 8),
                      pw.Text('hello@heriksalon.com', style: pw.TextStyle(fontSize: 10, color: textLight)),
                    ]
                  )
                ]
              ),
              pw.SizedBox(height: 50),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Billed to:', style: pw.TextStyle(fontSize: 10, color: textDark)),
                      pw.Text(transaction.customerName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: textDark)),
                      pw.Text('Walk-in Customer', style: pw.TextStyle(fontSize: 10, color: textDark)),
                    ]
                  ),
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Invoice No.:', style: pw.TextStyle(fontSize: 10, color: textDark)),
                            pw.Text(transaction.invoiceNumber, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                          ]
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Issue date:', style: pw.TextStyle(fontSize: 10, color: textDark)),
                            pw.Text(dateStr, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                          ]
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Payment Method:', style: pw.TextStyle(fontSize: 10, color: textDark)),
                            pw.Text('POS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                          ]
                        ),
                      ]
                    )
                  )
                ]
              ),
              pw.SizedBox(height: 30),
              pw.Container(
                color: headerBgColor,
                padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 5, child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark))),
                    pw.Expanded(flex: 2, child: pw.Text('QUANTITY', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark))),
                    pw.Expanded(flex: 2, child: pw.Text('UNIT PRICE (₹)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark))),
                    pw.Expanded(flex: 2, child: pw.Text('AMOUNT (₹)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark))),
                  ]
                )
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 5, child: pw.Text(transaction.serviceName, style: pw.TextStyle(fontSize: 10, color: textDark))),
                    pw.Expanded(flex: 2, child: pw.Text('1', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, color: textDark))),
                    pw.Expanded(flex: 2, child: pw.Text(baseAmount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, color: textDark))),
                    pw.Expanded(flex: 2, child: pw.Text(baseAmount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, color: textDark))),
                  ]
                )
              ),
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.SizedBox(
                  width: 250,
                  child: pw.Column(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 12),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL (INR):', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                            pw.Text('₹${baseAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, color: textLight)),
                          ]
                        ),
                      ),
                      if (applyGst) ...[
                        pw.SizedBox(height: 6),
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 12),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('TAX (18%):', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
                              pw.Text('₹${gstAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, color: textLight)),
                            ]
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 8),
                      pw.Divider(color: headerBgColor, thickness: 1.5), 
                      pw.SizedBox(height: 8),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(right: 12),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL DUE (INR)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textDark)),
                            pw.Text('₹${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, color: textDark)),
                          ]
                        ),
                      ),
                    ]
                  )
                )
              ),
            ]
          );
        }
      ),
    );

    return pdf;
  }

  Future<void> downloadInvoice(TransactionModel transaction, bool applyGst) async {
    try {
      final pdf = await _generateInvoicePdf(transaction, applyGst);
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Herik_Invoice_${transaction.invoiceNumber}.pdf');
    } catch (e) {
      debugPrint('Download Error: $e');
    }
  }

  Future<void> printInvoice(TransactionModel transaction, bool applyGst) async {
    try {
      final pdf = await _generateInvoicePdf(transaction, applyGst);
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Invoice_${transaction.invoiceNumber}');
    } catch (e) {
      debugPrint('Print Error: $e');
    }
  }
}