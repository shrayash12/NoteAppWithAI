import 'package:intl/intl.dart';
import '../models/document_category.dart';

/// Result of classifying a scanned document's OCR text.
class DocumentClassification {
  final DocumentCategory category;
  final String title;
  final List<String> tags;
  final Map<String, String> metadata;

  const DocumentClassification({
    required this.category,
    required this.title,
    required this.tags,
    required this.metadata,
  });
}

/// Offline, rule-based document classifier. Runs entirely on-device via
/// keyword matching against OCR text — no AI calls, no cost, works for
/// every user regardless of subscription tier.
class DocumentClassifierService {
  const DocumentClassifierService();

  static final _amountPattern = RegExp(
    r'(?:total|amount due|balance due|grand total)\s*[:\-]?\s*[A-Za-z]{0,4}\s?([\d,]+\.\d{2})',
    caseSensitive: false,
  );
  static final _currencyFallbackPattern = RegExp(r'\b(?:AED|USD|INR|EUR|GBP)\s?([\d,]+\.\d{2})\b');
  static final _datePattern = RegExp(
    r'\b(\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}|\d{4}-\d{2}-\d{2})\b',
  );
  static final _accountNumberPattern = RegExp(r'account\s*(?:no\.?|number)?\s*[:\-]?\s*([A-Z0-9]{6,20})', caseSensitive: false);
  static final _passportNumberPattern = RegExp(r'passport\s*no\.?\s*[:\-]?\s*([A-Z0-9]{6,12})', caseSensitive: false);
  static final _expiryPattern = RegExp(
    r'(?:expiry|expiration|valid until|exp\.?)\s*(?:date)?\s*[:\-]?\s*(\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4})',
    caseSensitive: false,
  );

  DocumentClassification classify(String ocrText) {
    final category = _bestCategory(ocrText);
    final metadata = _extractMetadata(category, ocrText);
    final title = _generateTitle(category, metadata);
    final tags = _generateTags(category, metadata);
    return DocumentClassification(category: category, title: title, tags: tags, metadata: metadata);
  }

  DocumentCategory _bestCategory(String ocrText) {
    final lower = ocrText.toLowerCase();
    DocumentCategory best = DocumentCategory.miscellaneous;
    int bestScore = 0;

    for (final category in DocumentCategory.all) {
      var score = 0;
      for (final keyword in category.keywords) {
        if (lower.contains(keyword)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = category;
      }
    }

    // Require at least one real keyword hit — otherwise stay Miscellaneous
    // rather than guessing.
    return bestScore > 0 ? best : DocumentCategory.miscellaneous;
  }

  Map<String, String> _extractMetadata(DocumentCategory category, String ocrText) {
    final metadata = <String, String>{};

    switch (category.id) {
      case 'receipt':
      case 'invoice':
      case 'utility_bill':
        final amount = _amountPattern.firstMatch(ocrText)?.group(1) ??
            _currencyFallbackPattern.firstMatch(ocrText)?.group(1);
        if (amount != null) metadata['amount'] = amount;
        final date = _datePattern.firstMatch(ocrText)?.group(0);
        if (date != null) metadata['date'] = date;
        final merchant = _firstMeaningfulLine(ocrText);
        if (merchant != null) metadata['merchant'] = merchant;
        break;

      case 'bank_statement':
        final account = _accountNumberPattern.firstMatch(ocrText)?.group(1);
        if (account != null) metadata['accountNumber'] = account;
        final bankName = _matchAny(ocrText, const [
          'emirates nbd', 'adcb', 'fab', 'first abu dhabi bank', 'dib', 'mashreq', 'rakbank', 'hsbc', 'citibank',
        ]);
        if (bankName != null) metadata['bank'] = bankName;
        break;

      case 'medical_report':
        final patient = _labeledValue(ocrText, 'patient');
        if (patient != null) metadata['patient'] = patient;
        final hospital = _labeledValue(ocrText, 'hospital') ?? _labeledValue(ocrText, 'laboratory');
        if (hospital != null) metadata['hospital'] = hospital;
        break;

      case 'identity':
        final passportNo = _passportNumberPattern.firstMatch(ocrText)?.group(1);
        if (passportNo != null) metadata['documentNumber'] = passportNo;
        final expiry = _expiryPattern.firstMatch(ocrText)?.group(1);
        if (expiry != null) metadata['expiryDate'] = expiry;
        break;
    }

    return metadata;
  }

  String _generateTitle(DocumentCategory category, Map<String, String> metadata) {
    final dateStr = DateFormat('MMM d, yyyy').format(DateTime.now());
    final merchant = metadata['merchant'];
    final bank = metadata['bank'];

    if (category.id == 'receipt' && merchant != null) return '$merchant Receipt';
    if (category.id == 'invoice' && merchant != null) return '$merchant Invoice';
    if (category.id == 'bank_statement' && bank != null) return '$bank Statement';
    return '${category.displayName} - $dateStr';
  }

  List<String> _generateTags(DocumentCategory category, Map<String, String> metadata) {
    final tags = <String>{category.displayName};
    if (metadata['merchant'] != null) tags.add(metadata['merchant']!);
    if (metadata['bank'] != null) tags.add(metadata['bank']!);
    if (metadata['hospital'] != null) tags.add(metadata['hospital']!);
    return tags.toList();
  }

  /// Returns the first non-trivial line of text — a common heuristic for
  /// the merchant/store name at the top of a receipt or invoice.
  String? _firstMeaningfulLine(String ocrText) {
    for (final rawLine in ocrText.split('\n')) {
      final line = rawLine.trim();
      if (line.length >= 3 && line.length <= 40 && RegExp(r'[A-Za-z]{3,}').hasMatch(line)) {
        return line;
      }
    }
    return null;
  }

  /// Finds a line containing "<label>:" and returns the text after it.
  String? _labeledValue(String ocrText, String label) {
    final pattern = RegExp('$label\\s*[:\\-]\\s*(.+)', caseSensitive: false);
    final match = pattern.firstMatch(ocrText);
    return match?.group(1)?.trim();
  }

  String? _matchAny(String ocrText, List<String> candidates) {
    final lower = ocrText.toLowerCase();
    for (final candidate in candidates) {
      if (lower.contains(candidate)) return candidate;
    }
    return null;
  }
}
