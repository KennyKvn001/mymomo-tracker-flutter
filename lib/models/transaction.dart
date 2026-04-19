import 'package:flutter/material.dart';

class Transaction {
  final double amount;
  final String description;
  final DateTime date;
  final String? reference;
  final bool isIncoming;

  /// MoMo wallet balance after this SMS, if the body reports one.
  final double? momoBalance;

  /// MoKash savings balance after this SMS, if the body reports one.
  /// Combined "payment to Mokash Savings" SMS carry both balances at once.
  final double? mokashBalance;

  final bool isPayment;
  final bool isMokash;

  Transaction({
    required this.amount,
    required this.description,
    required this.date,
    this.reference,
    required this.isIncoming,
    this.momoBalance,
    this.mokashBalance,
    this.isPayment = false,
    this.isMokash = false,
  });

  /// Convenience for screens that just want "the" balance for the account
  /// this transaction is displayed under.
  double? get balance => isMokash ? mokashBalance : momoBalance;

  Color get displayColor =>
      isIncoming ? Colors.green : (isPayment ? Colors.orange : Colors.red);
  IconData get displayIcon => isPayment
      ? Icons.payment
      : (isIncoming ? Icons.arrow_downward : Icons.arrow_upward);
  String get amountPrefix => isIncoming ? "+" : "-";

  /// Parses an SMS body into one or two [Transaction] rows.
  ///
  /// Three SMS shapes are handled:
  ///
  /// 1. **Pure MoMo SMS** (no MoKash content) → one `isMokash: false` row.
  ///
  /// 2. **Combined deposit SMS** — an M-Money payment wrapper followed
  ///    by an embedded `Y'ello … transferred to your Mokash account …`
  ///    forward → TWO rows:
  ///      * MoMo wallet (outgoing payment to MoKash) with `momoBalance`
  ///      * MoKash account (incoming deposit from MoMo) with `mokashBalance`
  ///
  /// 3. **Standalone MoKash SMS** — the entire body is a `Y'ello …`
  ///    MoKash notification (e.g. withdrawal:
  ///    *"Y'ello. You have transferred RWF 5000 from your Mokash
  ///    account … Mokash balance is RWF 55387. Ref …"*) → one
  ///    `isMokash: true` row. We don't fabricate a paired MoMo row here
  ///    because if the corresponding MoMo deposit is announced by MTN
  ///    it'll arrive as its own SMS.
  static List<Transaction> fromSms(
    String sms, {
    required DateTime messageDate,
  }) {
    final amount = _extractAmount(sms);
    final reference = _extractReference(sms);
    final lower = sms.toLowerCase();
    final hasMokash = lower.contains('mokash');
    final yelloIdx = sms.indexOf("Y'ello");

    // Case 3: Standalone MoKash SMS — Y'ello is the very first token
    // (no M-Money wrapper in front of it).
    if (yelloIdx == 0 && hasMokash) {
      // Direction comes from MTN's own wording; words may sit between
      // "transferred" and "from your mokash" (e.g. "transferred RWF 5000
      // from your Mokash account"), so we only check the trailing phrase.
      final isIncoming = lower.contains('to your mokash');
      // Anything else with `mokash` but not `to your mokash` is treated
      // as outgoing from MoKash (withdrawal, fee, etc.).
      return [
        Transaction(
          amount: amount,
          description: _generateDescription(sms),
          date: messageDate,
          reference: reference,
          isIncoming: isIncoming,
          momoBalance: null,
          mokashBalance: _findBalance(sms),
          isPayment: false,
          isMokash: true,
        ),
      ];
    }

    final (momoPart, mokashPart) = _splitParts(sms);

    // Case 2: Combined SMS — wrapper before, MoKash forward after.
    if (mokashPart.isNotEmpty) {
      final mokashLower = mokashPart.toLowerCase();
      final mokashIsIncoming = mokashLower.contains('to your mokash');
      final mokashIsOutgoing = mokashLower.contains('from your mokash');

      final momoSide = Transaction(
        amount: amount,
        description: _generateDescription(momoPart),
        date: messageDate,
        reference: reference,
        // Money LEAVES MoMo when going INTO MoKash, and vice versa.
        isIncoming: mokashIsOutgoing,
        momoBalance: _findBalance(momoPart),
        mokashBalance: null,
        isPayment: true,
        isMokash: false,
      );

      final mokashSide = Transaction(
        amount: amount,
        description: _generateDescription(mokashPart),
        date: messageDate,
        reference: reference,
        isIncoming: mokashIsIncoming,
        momoBalance: null,
        mokashBalance: _findBalance(mokashPart),
        isPayment: false,
        isMokash: true,
      );

      return [momoSide, mokashSide];
    }

    // Case 1: Pure MoMo SMS.
    final isIncoming =
        lower.contains('received') || lower.contains('have received');
    final description = _generateDescription(sms);
    final lowerDesc = description.toLowerCase();
    final isPayment = lowerDesc.contains('payment of') ||
        lowerDesc.contains('mtn rwandacell') ||
        lowerDesc.contains('a transaction of');

    return [
      Transaction(
        amount: amount,
        description: description,
        date: messageDate,
        reference: reference,
        isIncoming: isIncoming,
        momoBalance: _findBalance(sms),
        mokashBalance: null,
        isPayment: isPayment,
        isMokash: false,
      ),
    ];
  }

  // Matches a number, with or without thousand separators, optional decimals.
  //
  // Two alternatives, ORDER MATTERS:
  //   1. comma-grouped: 1,234 / 1,234,567 / 1,234.56 — REQUIRES at least one
  //      "(,\d{3})" group so it cannot win on a plain number like "1300000"
  //      and capture only the first 3 digits.
  //   2. plain digits: 42859 / 1300000 / 42859.50.
  static const _numRe =
      r'(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)';
  static const _cur = r'(?:RWF|FRW|Rwf)';

  static double _extractAmount(String sms) {
    // MTN Rwanda writes the amount in either order depending on the sender:
    //   MoKash:  "Y'ello. RWF 25000 transferred to your Mokash account ..."
    //   M-Money: "... received 25,000 RWF from ..."
    final patterns = [
      RegExp('$_cur\\s*$_numRe', caseSensitive: false),
      RegExp('$_numRe\\s*$_cur', caseSensitive: false),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(sms);
      if (match != null) {
        final v = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (v != null) return v;
      }
    }
    // Fallback: amount right after an action verb, with no currency token.
    final fallback = RegExp(
        '(?:payment of|transferred|received)\\s*$_numRe',
        caseSensitive: false);
    final fm = fallback.firstMatch(sms);
    if (fm != null) {
      return double.tryParse(fm.group(1)!.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  static String? _extractReference(String sms) {
    // Accept both M-Money ("Id: 1234") and MoKash ("Ref 27387371972") styles.
    final regex = RegExp(r'(?:Id|Ref|TxId)\s*:?\s*(\d+)', caseSensitive: false);
    return regex.firstMatch(sms)?.group(1);
  }

  /// Splits a combined "M-Money payment to Mokash Savings" SMS into the
  /// MoMo wrapper (before the embedded MoKash forward) and the MoKash
  /// forward itself.
  ///
  /// MTN appends `Message: -` to MANY M-Money SMS even when nothing
  /// MoKash-related follows it (Airtime, Cash Power, plain `- -. *RW#`
  /// trailers, etc.). We therefore only treat the SMS as combined when
  /// the candidate trailing fragment actually mentions "mokash". Anything
  /// else is a pure MoMo SMS and the second value comes back empty.
  static (String momoPart, String mokashPart) _splitParts(String sms) {
    for (final marker in ["Y'ello", 'Message: -', 'Message:-']) {
      final idx = sms.indexOf(marker);
      if (idx <= 0) continue;
      final tail = sms.substring(idx);
      if (tail.toLowerCase().contains('mokash')) {
        return (sms.substring(0, idx), tail);
      }
    }
    return (sms, '');
  }

  /// Generic "balance … <number> RWF" / "balance … RWF <number>" matcher.
  /// Used identically for both accounts — the *scoping* is what makes one
  /// match the MoMo balance and the other match the MoKash balance.
  static double? _findBalance(String scope) {
    if (scope.isEmpty) return null;
    final patterns = [
      RegExp(r'balance\s*(?:is\s*)?:?\s*' + _cur + r'\s*' + _numRe,
          caseSensitive: false),
      RegExp(r'balance\s*(?:is\s*)?:?\s*' + _numRe + r'\s*' + _cur,
          caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(scope);
      if (match != null) {
        final raw = match.group(1)!.replaceAll(',', '');
        final parsed = double.tryParse(raw);
        if (parsed != null) return parsed;
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
