class Transaction {
  final double amount;
  final String description;
  final DateTime date;
  final String? reference;
  final bool isIncoming;
  final double? balance;

  Transaction({
    required this.amount,
    required this.description,
    required this.date,
    this.reference,
    required this.isIncoming,
    this.balance,
  });

  factory Transaction.fromSms(String sms, {required DateTime messageDate}) {
    final isIncoming =
        sms.contains('received') || sms.contains('have received');
    final amount = _extractAmount(sms);
    final reference = _extractReference(sms);
    final balance = _extractBalance(sms);

    return Transaction(
      amount: amount,
      description: _generateDescription(sms),
      date: messageDate,
      reference: reference,
      isIncoming: isIncoming,
      balance: balance,
    );
  }

  static double _extractAmount(String sms) {
    final regex = RegExp(r'(\d+,?\d*) RWF');
    final match = regex.firstMatch(sms);
    if (match == null) return 0;
    return double.parse(match.group(1)!.replaceAll(',', ''));
  }

  static String? _extractReference(String sms) {
    final regex = RegExp(r'Id: (\d+)');
    final match = regex.firstMatch(sms);
    return match?.group(1);
  }

  static double? _extractBalance(String sms) {
    final patterns = [
      RegExp(r'Balance\s*:?\s*(\d+,?\d*)\s*RWF', caseSensitive: false),
      RegExp(r'Balance\s*is\s*(\d+,?\d*)\s*RWF', caseSensitive: false),
      RegExp(r'New\s*balance\s*:?\s*(\d+,?\d*)\s*RWF', caseSensitive: false),
      RegExp(r'new\s*balance\s*:?\s*(\d+,?\d*)\s*RWF', caseSensitive: false),
      RegExp(r'Your\s*balance\s*is\s*(\d+,?\d*)\s*RWF', caseSensitive: false),
      RegExp(r'Account\s*balance\s*:?\s*(\d+,?\d*)\s*RWF',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        final balanceStr = match.group(1)!.replaceAll(',', '');
        return double.tryParse(balanceStr);
      }
    }

    return null;
  }

  static String _generateDescription(String sms) {
    // Extract the main transaction description
    // This is a simple implementation - you might want to enhance it
    return sms.split('.')[0];
  }
}
