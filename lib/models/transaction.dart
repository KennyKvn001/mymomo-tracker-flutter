import 'package:flutter/material.dart';

class Transaction {
  final double amount;
  final String description;
  final DateTime date;
  final String? reference;
  final bool isIncoming;
  final double? balance;
  final bool isPayment;
  final bool isMokash;

  Transaction({
    required this.amount,
    required this.description,
    required this.date,
    this.reference,
    required this.isIncoming,
    this.balance,
    this.isPayment = false,
    this.isMokash = false,
  });

  Color get displayColor =>
      isIncoming ? Colors.green : (isPayment ? Colors.orange : Colors.red);
  IconData get displayIcon => isPayment
      ? Icons.payment
      : (isIncoming ? Icons.arrow_downward : Icons.arrow_upward);
  String get amountPrefix => isIncoming ? "+" : "-";

  factory Transaction.fromSms(String sms, {required DateTime messageDate}) {
    final lowerSms = sms.toLowerCase();

    bool isIncoming = lowerSms.contains('received') || lowerSms.contains('have received');
    bool isMokash = false;

    if (lowerSms.contains('to your mokash')) {
      isMokash = true;
      isIncoming = true; // Money entering MoKash
    } else if (lowerSms.contains('from your mokash')) {
      isMokash = true;
      isIncoming = false; // Money leaving MoKash
    } else if (lowerSms.contains('mokash')) {
      isMokash = true;
    }

    final amount = _extractAmount(sms);
    final reference = _extractReference(sms);
    final balance = _extractBalance(sms);
    final description = _generateDescription(sms);
    
    final lowerDesc = description.toLowerCase();
    final isPayment = lowerDesc.contains('payment of') ||
        lowerDesc.contains('mtn rwandacell') ||
        lowerDesc.contains('a transaction of');

    return Transaction(
      amount: amount,
      description: description,
      date: messageDate,
      reference: reference,
      isIncoming: isIncoming,
      balance: balance,
      isPayment: isPayment,
      isMokash: isMokash,
    );
  }

  static double _extractAmount(String sms) {
    final regex =
        RegExp(r'(\d+[,.]?\d*)\s*(?:RWF|FRW|Rwf)', caseSensitive: false);
    final match = regex.firstMatch(sms);
    if (match == null) {
      // Fallback: sometimes amount might just be digits after 'payment of ' or 'transferred '
      final fallbackRegex = RegExp(
          r'(?:payment of|transferred|received)\s*(\d+[,.]?\d*)',
          caseSensitive: false);
      final fallbackMatch = fallbackRegex.firstMatch(sms);
      if (fallbackMatch != null) {
        return double.parse(fallbackMatch.group(1)!.replaceAll(',', ''));
      }
      return 0;
    }
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
    if (sms.isEmpty) return 'Unknown Transaction';

    // Commonly, trailing parts like Fee, Balance, or Id carry metadata instead of the action descripton.
    final delimiters = [
      ' Fee',
      ' fee',
      ' Balance',
      ' balance',
      ' Id:',
      ' ID:',
      ' TxId',
      ' Financial'
    ];

    String desc = sms;
    for (final delimiter in delimiters) {
      if (desc.contains(delimiter)) {
        desc = desc.split(delimiter)[0];
      }
    }

    // Fallback if no delimiter was hit, but there is a clear sentence ending
    if (desc.length == sms.length && sms.contains('.')) {
      desc = sms.split('.')[0];
    }

    // Strip trailing periods and whitespace
    return desc.replaceAll(RegExp(r'[\.\s]+$'), '').trim();
  }
}
