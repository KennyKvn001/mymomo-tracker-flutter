import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/transaction.dart';
import 'dart:developer' as developer;

/// Categorized result returned by [SmsService.getCategorizedTransactions].
///
/// [all] is the full, date-sorted (newest first) list. [momo] / [mokash] are
/// disjoint subsets, split by [Transaction.isMokash] (which the parser sets
/// from SMS body content — there is no separate MoKash sender on this
/// network; MoKash deposit notifications are wrapped inside M-Money payment
/// SMS).
///
/// [momoBalance] / [mokashBalance] are the latest non-null balances seen for
/// each account across the whole list.
typedef MomoSnapshot = ({
  List<Transaction> all,
  List<Transaction> momo,
  List<Transaction> mokash,
  double? momoBalance,
  double? mokashBalance,
});

class SmsService {
  static const _platform = MethodChannel('com.example.momoapp/sms');

  /// Backwards-compatible flat list (newest first). Prefer
  /// [getCategorizedTransactions] when the screen also needs balances.
  Future<List<Transaction>> getTransactions() async {
    final snapshot = await getCategorizedTransactions();
    return snapshot.all;
  }

  Future<MomoSnapshot> getCategorizedTransactions() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      throw Exception('SMS permission denied');
    }

    try {
      final List<dynamic> messages =
          await _platform.invokeMethod('getSmsMessages');

      developer.log('Received ${messages.length} messages');

      final accepted = messages.where((message) {
        if (message['body'] == null) return false;
        final address = message['address']?.toString().toLowerCase() ?? '';
        // Accept M-Money (regular MoMo + combined deposit SMS) and any
        // sender whose name contains "mokash" (standalone MoKash SMS).
        final senderOk = address == 'm-money' || address.contains('mokash');
        if (!senderOk) return false;
        final body = message['body'].toString().toLowerCase();
        return body.contains('transferred to') ||
            (body.contains('transferred') &&
                body.contains('from your mokash')) ||
            body.contains('payment of') ||
            body.contains('received') ||
            body.contains('mokash');
      }).toList();

      developer.log('Accepted ${accepted.length} M-Money messages');

      final parsed = accepted
          .expand<Transaction>((message) {
            try {
              return Transaction.fromSms(
                message['body'] as String,
                messageDate:
                    DateTime.fromMillisecondsSinceEpoch(message['date'] as int),
              );
            } catch (e) {
              developer.log('Error processing message: $e');
              return const <Transaction>[];
            }
          })
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      // Deduplicate MoKash rows. MTN sends BOTH a combined "M-Money payment
      // to Mokash Savings ... Y'ello ..." SMS *and* a standalone "[Mokash]
      // Y'ello ..." SMS for the same deposit, sharing the same Ref. Both
      // produce a MoKash incoming row (the combined one as the embedded
      // forward, the standalone one on its own), so without this we'd
      // double-count every deposit.
      //
      // MoMo rows are never deduped — each M-Money SMS represents a real
      // distinct wallet event. MoKash withdrawals arrive only from the
      // standalone [Mokash] SMS, so they have no twin to collide with.
      final seenMokashKeys = <String>{};
      final dropped = <Transaction>[];
      final all = <Transaction>[];
      for (final t in parsed) {
        if (t.isMokash) {
          final key = '${t.reference ?? ""}|${t.amount}|${t.isIncoming}';
          if (key != '||' && !seenMokashKeys.add(key)) {
            dropped.add(t);
            continue;
          }
        }
        all.add(t);
      }
      if (dropped.isNotEmpty) {
        developer.log(
            'Deduped ${dropped.length} duplicate MoKash row(s) (same Ref + amount + direction)');
      }

      final momo = all.where((t) => !t.isMokash).toList();
      final mokash = all.where((t) => t.isMokash).toList();

      // Latest balance per account = the newest transaction (across the
      // whole list, regardless of which card it's displayed under) that
      // actually carries that field. A combined "payment to Mokash Savings"
      // SMS contributes to BOTH balances at once.
      double? latestMomoBalance;
      double? latestMokashBalance;
      for (final t in all) {
        latestMomoBalance ??= t.momoBalance;
        latestMokashBalance ??= t.mokashBalance;
        if (latestMomoBalance != null && latestMokashBalance != null) break;
      }

      developer.log(
          'Parsed ${all.length} tx (MoMo: ${momo.length}, MoKash: ${mokash.length}) '
          '· balances MoMo=$latestMomoBalance MoKash=$latestMokashBalance');

      return (
        all: all,
        momo: momo,
        mokash: mokash,
        momoBalance: latestMomoBalance,
        mokashBalance: latestMokashBalance,
      );
    } catch (e) {
      developer.log('Error reading SMS: $e', error: e);
      throw Exception('Failed to read SMS: $e');
    }
  }
}
