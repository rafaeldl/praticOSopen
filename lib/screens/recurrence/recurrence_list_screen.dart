import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType, Divider, InkWell;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/recurrence_store.dart';
import 'package:praticos/models/recurrence_rule.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/extensions/context_extensions.dart';

class RecurrenceListScreen extends StatefulWidget {
  const RecurrenceListScreen({super.key});

  @override
  State<RecurrenceListScreen> createState() => _RecurrenceListScreenState();
}

class _RecurrenceListScreenState extends State<RecurrenceListScreen> {
  final RecurrenceStore _store = RecurrenceStore();

  @override
  void initState() {
    super.initState();
    _store.loadRules();
  }

  String _frequencyLabel(BuildContext context, String? frequency) {
    switch (frequency) {
      case 'daily':
        return context.l10n.recurrenceFrequencyDaily;
      case 'weekly':
        return context.l10n.recurrenceFrequencyWeekly;
      case 'monthly':
        return context.l10n.recurrenceFrequencyMonthly;
      case 'yearly':
        return context.l10n.recurrenceFrequencyYearly;
      default:
        return frequency ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();
    final formatService = FormatService();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(context.l10n.recurrenceRules),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add),
                onPressed: () {
                  Navigator.pushNamed(context, '/recurrence_form');
                },
              ),
            ),

            Observer(
              builder: (_) => _buildBody(config, formatService),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SegmentConfigProvider config, FormatService formatService) {
    if (_store.ruleList == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_store.ruleList!.hasError) {
      return SliverFillRemaining(
        child: Center(
          child: Text(context.l10n.errorLoading),
        ),
      );
    }

    final rawData = _store.ruleList!.data;
    if (rawData == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final rules = rawData.whereType<RecurrenceRule>().toList();

    if (rules.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.repeat,
                  size: 64,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.noRecurrenceRules,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final rule = rules[index];
          return _buildRuleItem(rule, config, formatService, index == rules.length - 1);
        },
        childCount: rules.length,
      ),
    );
  }

  Widget _buildRuleItem(
    RecurrenceRule rule,
    SegmentConfigProvider config,
    FormatService formatService,
    bool isLast,
  ) {
    final isActive = rule.active ?? false;
    final frequencyStr = _frequencyLabel(context, rule.frequency);
    final intervalStr = (rule.interval != null && rule.interval! > 1)
        ? '${context.l10n.recurrenceInterval} ${rule.interval} $frequencyStr'
        : frequencyStr;
    final nextDueStr = rule.nextDueDate != null
        ? formatService.formatDate(rule.nextDueDate!)
        : '';

    return Dismissible(
      key: Key(rule.id ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(CupertinoIcons.trash, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(context.l10n.confirm),
            content: Text('${context.l10n.doYouWantToRemoveThe} "${rule.name}"?'),
            actions: [
              CupertinoDialogAction(
                child: Text(context.l10n.cancel),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: Text(context.l10n.delete),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _store.deleteRule(rule),
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/recurrence_form',
              arguments: {'rule': rule},
            );
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Active indicator
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isActive
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.systemGrey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule.name ?? intervalStr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$intervalStr${rule.customer?.name != null ? ' - ${rule.customer!.name}' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                          if (nextDueStr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${context.l10n.recurrenceNextDue}: $nextDueStr',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (rule.autoGenerate == true)
                      Icon(
                        CupertinoIcons.bolt_fill,
                        size: 16,
                        color: CupertinoColors.systemOrange.resolveFrom(context),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: CupertinoColors.systemGrey3.resolveFrom(context),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 38,
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
