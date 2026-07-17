import 'package:cloud_functions/cloud_functions.dart';

/// Thrown when an AI request can't be completed.
class AIServiceException implements Exception {
  final String code; // 'empty_input' | 'unauthenticated' | 'quota_exceeded' | 'request_failed'
  final String message;
  AIServiceException(this.code, this.message);

  bool get isQuotaExceeded => code == 'quota_exceeded';

  @override
  String toString() => message;
}

/// Calls the `runAIAction` Cloud Function, which holds the Gemini API key
/// server-side. No key is ever stored or shipped on-device.
class AIService {
  AIService._();

  static Future<String> _run(
    String action,
    String text, {
    String? targetLanguage,
  }) async {
    if (text.trim().isEmpty) {
      throw AIServiceException('empty_input', 'Add some text first.');
    }
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('runAIAction');
      final response = await callable.call<Map<String, dynamic>>({
        'action': action,
        'text': text,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      });
      final result = response.data['result'] as String?;
      if (result == null || result.isEmpty) {
        throw AIServiceException('request_failed', 'The AI returned an empty response.');
      }
      return result;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        throw AIServiceException('unauthenticated', 'Please sign in to use AI features.');
      }
      if (e.code == 'resource-exhausted') {
        throw AIServiceException(
          'quota_exceeded',
          e.message ?? 'You\'ve reached your AI usage limit for this period.',
        );
      }
      throw AIServiceException('request_failed', e.message ?? 'AI request failed.');
    } on AIServiceException {
      rethrow;
    } catch (e) {
      throw AIServiceException('request_failed', 'AI request failed: $e');
    }
  }

  static Future<String> enhanceWriting(String text) => _run('enhance', text);

  static Future<String> summarize(String text) => _run('summarize', text);

  static Future<String> translate(String text, String targetLanguage) =>
      _run('translate', text, targetLanguage: targetLanguage);
}
