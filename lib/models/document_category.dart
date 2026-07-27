import 'package:flutter/material.dart';

/// A document category used by SmartScan's offline classifier to route
/// scanned documents into the right folder and extract relevant metadata.
class DocumentCategory {
  final String id;
  final String displayName;
  final IconData icon;
  final Color color;
  final String folderId;
  final List<String> keywords;

  const DocumentCategory({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.folderId,
    required this.keywords,
  });

  static const receipt = DocumentCategory(
    id: 'receipt',
    displayName: 'Receipt',
    icon: Icons.receipt_long,
    color: Color(0xFF22C55E),
    folderId: 'receipts',
    keywords: ['total', 'subtotal', 'vat', 'cash', 'receipt', 'change due', 'qty', 'cashier'],
  );

  static const invoice = DocumentCategory(
    id: 'invoice',
    displayName: 'Invoice',
    icon: Icons.description_outlined,
    color: Color(0xFF3B82F6),
    folderId: 'bills',
    keywords: ['invoice', 'invoice no', 'bill to', 'due date', 'amount due', 'po number'],
  );

  static const utilityBill = DocumentCategory(
    id: 'utility_bill',
    displayName: 'Utility Bill',
    icon: Icons.bolt_outlined,
    color: Color(0xFFF59E0B),
    folderId: 'bills',
    keywords: ['electricity', 'water bill', 'consumption', 'meter reading', 'utility', 'kwh', 'dewa', 'billing period'],
  );

  static const bankStatement = DocumentCategory(
    id: 'bank_statement',
    displayName: 'Bank Statement',
    icon: Icons.account_balance_outlined,
    color: Color(0xFF6366F1),
    folderId: 'bank_statements',
    keywords: ['statement', 'account number', 'opening balance', 'closing balance', 'iban', 'transaction history'],
  );

  static const medicalReport = DocumentCategory(
    id: 'medical_report',
    displayName: 'Medical Report',
    icon: Icons.medical_information_outlined,
    color: Color(0xFFEF4444),
    folderId: 'medical',
    keywords: ['patient', 'hemoglobin', 'cbc', 'laboratory', 'diagnosis', 'physician', 'hospital', 'prescription', 'dosage'],
  );

  static const identity = DocumentCategory(
    id: 'identity',
    displayName: 'Identity Document',
    icon: Icons.badge_outlined,
    color: Color(0xFF8B5CF6),
    folderId: 'identity',
    keywords: ['passport', 'nationality', 'passport no', 'emirates id', 'driving license', 'date of birth', 'place of issue'],
  );

  static const miscellaneous = DocumentCategory(
    id: 'miscellaneous',
    displayName: 'Document',
    icon: Icons.insert_drive_file_outlined,
    color: Color(0xFF6B7280),
    folderId: 'documents',
    keywords: [],
  );

  /// All categories considered during classification, in priority order.
  /// [miscellaneous] is intentionally excluded — it's the fallback when
  /// nothing else scores above threshold.
  static const List<DocumentCategory> all = [
    receipt,
    invoice,
    utilityBill,
    bankStatement,
    medicalReport,
    identity,
  ];
}
