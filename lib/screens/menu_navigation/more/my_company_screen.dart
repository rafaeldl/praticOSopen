import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/section_label.dart';

/// "Sua empresa": company data and the "Como você trabalha" switches.
///
/// "Valores e cobrança" is wired to `Company.useFinancial`, which does not
/// exist yet (writing it is a separate risk:high step, see
/// `2026-10-11-financeiro-opcional-design.md`). Until then pass no
/// [onFinancialChanged]: the row shows as on and disabled.
class MyCompanyScreen extends StatelessWidget {
  const MyCompanyScreen({
    super.key,
    required this.onOpenCompanyData,
    this.useFinancial = true,
    this.onFinancialChanged,
  });

  final VoidCallback onOpenCompanyData;
  final bool useFinancial;

  /// Null while the `useFinancial` field is not available (row disabled).
  final ValueChanged<bool>? onFinancialChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MorePage(
      title: l10n.yourCompany,
      children: [
        MoreRows(rows: [
          AppListRow(
            key: const ValueKey('company_data'),
            title: l10n.companyData,
            onTap: onOpenCompanyData,
          ),
        ]),
        SectionLabel(l10n.howYouWork),
        MoreRows(rows: [
          MoreSwitchRow(
            key: const ValueKey('company_use_financial'),
            title: l10n.valuesAndBilling,
            subtitle: onFinancialChanged == null
                ? l10n.valuesAndBillingSoon
                : l10n.valuesAndBillingHint,
            value: useFinancial,
            onChanged: onFinancialChanged,
          ),
        ]),
      ],
    );
  }
}
