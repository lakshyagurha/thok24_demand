import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_space.dart';
import '../app_type.dart';

/// One bill, rendered one way.
///
/// The same five line items were previously drawn by three separate
/// implementations — `cartScreen._buildBillRow` at 13sp,
/// `checkout._buildSummaryRow` at 12sp and `order_summary._billRow` at
/// 12/14sp — so a shopper saw the identical bill at three sizes on three
/// consecutive screens. Worse, the grand total shrank as commitment grew:
/// 17sp black in the cart, 16sp green at checkout, 14sp black on the summary.
///
/// Here the total is always [AppText.priceL] and always the heaviest thing in
/// the card.
class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.title,
    required this.rows,
    required this.totalLabel,
    required this.totalValue,
    this.savings,
    this.savingsLabel,
  });

  final String title;
  final List<BillRow> rows;
  final String totalLabel;
  final double totalValue;
  final double? savings;
  final String? savingsLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpace.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.h3()),
          AppSpace.gapH(AppSpace.md),
          for (final r in rows) ...[
            r,
            AppSpace.gapH(AppSpace.sm),
          ],
          Padding(
            padding: AppSpace.symmetric(vertical: AppSpace.xs),
            child: const Divider(height: 1),
          ),
          AppSpace.gapH(AppSpace.sm),
          Row(
            children: [
              Expanded(child: Text(totalLabel, style: AppText.h3())),
              Text('₹${totalValue.toStringAsFixed(0)}', style: AppText.priceL()),
            ],
          ),
          if (savings != null && savings! > 0) ...[
            AppSpace.gapH(AppSpace.md),
            SavingsStrip(
              amount: savings!,
              label: savingsLabel ?? 'You saved',
            ),
          ],
        ],
      ),
    );
  }
}

class BillRow extends StatelessWidget {
  const BillRow({
    super.key,
    required this.label,
    required this.value,
    this.strikethrough,
    this.positive = false,
  });

  final String label;
  final String value;

  /// An original amount shown struck through beside [value].
  final String? strikethrough;

  /// Renders the value in the savings colour — discounts, free delivery.
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppText.bodyM(color: AppColors.textSecondary),
            maxLines: 2,
          ),
        ),
        if (strikethrough != null) ...[
          Text(strikethrough!, style: AppText.mrp()),
          AppSpace.gapW(AppSpace.sm),
        ],
        Text(
          value,
          style: AppText.label(
            color: positive ? AppColors.savingsText : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// The "you saved" confirmation.
///
/// Previously three variants: a primary-tinted block with a left-aligned
/// `check_circle_outline`, a `Colors.green` one with the same icon, and a
/// `success50` one with `savings_outlined`, centred.
class SavingsStrip extends StatelessWidget {
  const SavingsStrip({
    super.key,
    required this.amount,
    this.label = 'You saved',
  });

  final double amount;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpace.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.savingsSurface,
        borderRadius: AppRadius.xsAll,
        border: Border.all(color: AppColors.successBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.savings_outlined, size: 16, color: AppColors.savingsText),
          AppSpace.gapW(AppSpace.sm),
          Expanded(
            child: Text(
              '$label ₹${amount.toStringAsFixed(0)} on this order',
              style: AppText.labelS(color: AppColors.savingsText),
            ),
          ),
        ],
      ),
    );
  }
}
