import 'package:cloud_functions/cloud_functions.dart';

class AccountServiceException implements Exception {
  final String code;
  final String message;
  AccountServiceException(this.code, this.message);
}

/// Wraps the server-side `deleteAccount` Cloud Function — routed through a
/// callable rather than client-side `currentUser.delete()` so it isn't
/// subject to Firebase Auth's "requires-recent-login" restriction.
class AccountService {
  AccountService._();

  static Future<void> deleteAccount() async {
    try {
      await FirebaseFunctions.instance.httpsCallable('deleteAccount').call();
    } on FirebaseFunctionsException catch (e) {
      throw AccountServiceException(e.code, e.message ?? 'Failed to delete account.');
    }
  }
}
