import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';

Widget wrap(Widget child, {double scale = 1.0, double width = 390}) {
  return CupertinoApp(
    locale: const Locale('pt'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
    ],
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        size: Size(width, 800),
      ),
      child: app!,
    ),
    home: CupertinoPageScaffold(child: SafeArea(
        child: Align(alignment: Alignment.topCenter, child: child),
      ),
    ),
  );
}

void main() {
  group('AppListRow', () {
    testWidgets('shows title, subtitle and trailing beside the title',
        (tester) async {
      await tester.pumpWidget(wrap(const AppListRow(
        title: 'Maria Silva',
        subtitle: 'Troca de óleo',
        trailing: 'R\$ 120,00',
      )));
      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.text('Troca de óleo'), findsOneWidget);
      final title = tester.getTopLeft(find.text('Maria Silva'));
      final value = tester.getTopLeft(find.text('R\$ 120,00'));
      expect(value.dx, greaterThan(title.dx));
      final subtitleBottom =
          tester.getBottomLeft(find.text('Troca de óleo')).dy;
      expect(value.dy, lessThan(subtitleBottom));
    });

    testWidgets('chevron only when onTap is set', (tester) async {
      await tester.pumpWidget(wrap(const AppListRow(title: 'A')));
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);

      var taps = 0;
      await tester.pumpWidget(
        wrap(AppListRow(title: 'A', onTap: () => taps++)),
      );
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsOneWidget);
      await tester.tap(find.text('A'));
      expect(taps, 1);
    });

    testWidgets('showChevron overrides the default', (tester) async {
      await tester.pumpWidget(
        wrap(AppListRow(title: 'A', onTap: () {}, showChevron: false)),
      );
      expect(find.byIcon(CupertinoIcons.chevron_forward), findsNothing);
    });

    testWidgets('renders leading and keeps 44pt minimum height',
        (tester) async {
      await tester.pumpWidget(wrap(const AppListRow(
        title: 'A',
        leading: Icon(CupertinoIcons.person, key: Key('lead')),
      )));
      expect(find.byKey(const Key('lead')), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppListRow)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('long title wraps instead of ellipsizing', (tester) async {
      const long = 'Revisão completa com troca de filtros e alinhamento';
      await tester.pumpWidget(wrap(
        const AppListRow(title: long, trailing: 'R\$ 1.200,00'),
        width: 320,
      ));
      final text = tester.widget<Text>(find.text(long));
      expect(text.overflow, isNull);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text(long)).height, greaterThan(30));
    });

    testWidgets('stacks trailing under the title at accessibility sizes',
        (tester) async {
      await tester.pumpWidget(wrap(
        const AppListRow(title: 'Maria', trailing: 'R\$ 120,00'),
        scale: 1.6,
      ));
      final title = tester.getTopLeft(find.text('Maria'));
      final value = tester.getTopLeft(find.text('R\$ 120,00'));
      expect(value.dy, greaterThan(title.dy));
      expect(value.dx, title.dx);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not stack below the threshold', (tester) async {
      await tester.pumpWidget(wrap(
        const AppListRow(title: 'Maria', trailing: 'R\$ 120,00'),
        scale: 1.2,
      ));
      final title = tester.getTopLeft(find.text('Maria'));
      final value = tester.getTopLeft(find.text('R\$ 120,00'));
      expect(value.dx, greaterThan(title.dx));
    });
  });

  group('SectionLabel', () {
    testWidgets('keeps sentence case and is a semantic header',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(const SectionLabel('Serviços')));
      expect(find.text('Serviços'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Serviços')),
        matchesSemantics(label: 'Serviços', isHeader: true),
      );
      handle.dispose();
    });
  });

  group('states', () {
    testWidgets('EmptyState shows text and action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(EmptyState(
        title: 'Nenhum cliente',
        message: 'Cadastre o primeiro.',
        actionLabel: 'Novo cliente',
        onAction: () => tapped = true,
      )));
      expect(find.text('Nenhum cliente'), findsOneWidget);
      expect(find.text('Cadastre o primeiro.'), findsOneWidget);
      await tester.tap(find.text('Novo cliente'));
      expect(tapped, isTrue);
    });

    testWidgets('EmptyState without action has no button', (tester) async {
      await tester.pumpWidget(wrap(const EmptyState(title: 'Vazio')));
      expect(find.byType(CupertinoButton), findsNothing);
    });

    testWidgets('ErrorState shows localized default and retries',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(wrap(ErrorState(onRetry: () => retries++)));
      expect(find.textContaining('Não deu para carregar'), findsOneWidget);
      await tester.tap(find.byType(CupertinoButton));
      expect(retries, 1);
    });

    testWidgets('ErrorState accepts a custom message', (tester) async {
      await tester.pumpWidget(
        wrap(ErrorState(message: 'Falhou', onRetry: () {})),
      );
      expect(find.text('Falhou'), findsOneWidget);
    });

    testWidgets('LoadingState shows spinner and optional label',
        (tester) async {
      await tester.pumpWidget(wrap(const LoadingState(label: 'Buscando')));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text('Buscando'), findsOneWidget);
    });

    testWidgets('states do not overflow at large text', (tester) async {
      await tester.pumpWidget(wrap(
        EmptyState(
          title: 'Nenhum cliente cadastrado ainda',
          message: 'Cadastre o primeiro cliente para começar.',
          actionLabel: 'Novo cliente',
          onAction: () {},
        ),
        scale: 2.0,
        width: 320,
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
