import 'package:expense_tracker/models/category_model.dart';
import 'package:expense_tracker/models/transaction_model.dart';
import 'package:expense_tracker/services/refund_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel txn(
  int id,
  int rupees,
  DateTime at, {
  String type = 'expense',
  String? merchant,
  int? refundOf,
  bool self = false,
}) => TransactionModel(
  id: id,
  amountPaise: rupees * 100,
  type: type,
  categoryId: 1,
  paymentMode: 'UPI',
  dateTime: at,
  merchant: merchant,
  refundOfId: refundOf,
  isSelfTransfer: self,
);

void main() {
  final day = DateTime(2026, 11, 20, 12);
  DateTime ago(int days) => day.subtract(Duration(days: days));

  group('isRefundCategory', () {
    CategoryModel cat(String name, String type) =>
        CategoryModel(name: name, icon: 'x', color: 0, type: type);

    test('only the income Refund category', () {
      expect(RefundMatcher.isRefundCategory(cat('Refund', 'income')), isTrue);
      expect(RefundMatcher.isRefundCategory(cat(' refund ', 'income')), isTrue);
      expect(RefundMatcher.isRefundCategory(cat('Refund', 'expense')), isFalse);
      expect(
        RefundMatcher.isRefundCategory(cat('Cashback', 'income')),
        isFalse,
      );
      expect(RefundMatcher.isRefundCategory(null), isFalse);
    });
  });

  group('candidates', () {
    test('same merchant only, case does not matter', () {
      final refund = txn(9, 499, day, type: 'income', merchant: 'Flipkart');
      final all = [
        txn(1, 499, ago(5), merchant: 'FLIPKART'),
        txn(2, 499, ago(5), merchant: 'Amazon'),
        txn(3, 499, ago(5)), // no merchant
        refund,
      ];
      expect(RefundMatcher.candidates(refund, all).map((t) => t.id), [1]);
    });

    test('only expenses from the 60 days before the refund', () {
      final refund = txn(9, 100, day, type: 'income', merchant: 'Myntra');
      final all = [
        txn(1, 100, ago(60), merchant: 'Myntra'), // exactly 60 days: kept
        txn(2, 100, ago(61), merchant: 'Myntra'), // too old
        txn(3, 100, day.add(const Duration(days: 1)), merchant: 'Myntra'),
        txn(4, 100, ago(3), merchant: 'Myntra', type: 'income'),
      ];
      expect(RefundMatcher.candidates(refund, all).map((t) => t.id), [1]);
    });

    test('self transfers and fully refunded expenses are skipped', () {
      final refund = txn(9, 200, day, type: 'income', merchant: 'Amazon');
      final all = [
        txn(1, 500, ago(2), merchant: 'Amazon', self: true),
        txn(2, 300, ago(4), merchant: 'Amazon'),
        txn(3, 300, ago(3), type: 'income', merchant: 'Amazon', refundOf: 2),
        txn(4, 800, ago(6), merchant: 'Amazon'),
        txn(5, 200, ago(1), type: 'income', merchant: 'Amazon', refundOf: 4),
      ];
      // 2 is fully refunded; 4 is only partly refunded, so still offered.
      expect(RefundMatcher.candidates(refund, all).map((t) => t.id), [4]);
    });

    test('its own earlier link does not hide the expense', () {
      final refund = txn(
        9,
        300,
        day,
        type: 'income',
        merchant: 'Amazon',
        refundOf: 2,
      );
      final all = [txn(2, 300, ago(4), merchant: 'Amazon'), refund];
      expect(RefundMatcher.candidates(refund, all).map((t) => t.id), [2]);
    });

    test('same amount first, then newest first, at most 10', () {
      final refund = txn(99, 450, day, type: 'income', merchant: 'Swiggy');
      final all = [
        for (var i = 1; i <= 12; i++) txn(i, 300, ago(i), merchant: 'Swiggy'),
        txn(50, 450, ago(20), merchant: 'Swiggy'),
      ];
      final ids = RefundMatcher.candidates(refund, all).map((t) => t.id);
      expect(ids.length, 10);
      expect(ids.first, 50);
      expect(ids.skip(1).take(3), [1, 2, 3]);
    });

    test('no merchant (manual refund): expenses at least as big', () {
      final refund = txn(9, 500, day, type: 'income');
      final all = [
        txn(1, 400, ago(1), merchant: 'Zomato'),
        txn(2, 500, ago(2)),
        txn(3, 900, ago(3), merchant: 'Croma'),
      ];
      expect(RefundMatcher.candidates(refund, all).map((t) => t.id), [2, 3]);
    });

    test('"Unknown" merchant counts as no merchant', () {
      final refund = txn(9, 100, day, type: 'income', merchant: 'Unknown');
      final all = [txn(1, 150, ago(1), merchant: 'Ola')];
      expect(RefundMatcher.candidates(refund, all).map((t) => t.id), [1]);
    });
  });

  test('refundedTotals adds up refunds per expense', () {
    final totals = RefundMatcher.refundedTotals([
      txn(1, 1000, ago(5)),
      txn(2, 200, ago(2), type: 'income', refundOf: 1),
      txn(3, 300, ago(1), type: 'income', refundOf: 1),
      txn(4, 50, ago(1), type: 'income'),
    ]);
    expect(totals, {1: 50000});
  });

  test('withRefundOf sets and clears the link, keeping the rest', () {
    final t = txn(7, 120, day, type: 'income', merchant: 'Ajio');
    final linked = t.withRefundOf(3);
    expect(linked.refundOfId, 3);
    expect(linked.id, 7);
    expect(linked.merchant, 'Ajio');
    expect(linked.amountPaise, 12000);
    expect(linked.withRefundOf(null).refundOfId, isNull);
  });
}
