import 'package:flutter/material.dart';
import 'package:praticos/screens/catalog/catalog_list_screen.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/screens/device_form_screen.dart';
import 'package:praticos/screens/device_list_screen.dart';
import 'package:praticos/screens/order_form.dart';
import 'package:praticos/screens/order_product_screen.dart';
import 'package:praticos/screens/menu_navigation/collaborator_form_screen.dart';
import 'package:praticos/screens/menu_navigation/collaborator_list_screen.dart';
import 'package:praticos/screens/menu_navigation/company_form_screen.dart';
import 'package:praticos/screens/order_service_screen.dart';
import 'package:praticos/screens/payment_management_screen.dart';
import 'package:praticos/screens/customers/customer_detail_screen.dart';
import 'package:praticos/screens/customers/customer_form_screen.dart';
import 'package:praticos/screens/customers/customer_list_screen.dart';
import 'package:praticos/screens/dashboard/financial_dashboard_simple.dart';
import 'package:praticos/screens/forms/form_template_list_screen.dart';
import 'package:praticos/screens/forms/form_template_form_screen.dart';
import 'package:praticos/screens/user_profile_edit_screen.dart';
import 'package:praticos/screens/accumulated_value_list_screen.dart';
import 'package:praticos/screens/ratings/ratings_screen.dart';
import 'package:praticos/screens/notifications/notification_list_screen.dart';
import 'package:praticos/screens/devices/device_detail_screen.dart';
import 'package:praticos/screens/contracts/contract_list_screen.dart';
import 'package:praticos/screens/integrations/integration_list_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  // '/onboarding': removed - onboarding now handled by AuthWrapper with authStore
  // Catalog: one screen "Serviços | Produtos". The old list routes (also used
  // by the order to pick an item) open it on the matching kind.
  '/catalog': (context) => const CatalogListScreen(),
  '/service_list': (context) => const CatalogListScreen(),
  '/product_list': (context) =>
      const CatalogListScreen(initialKind: CatalogKind.product),
  '/customer_form': (context) => CustomerFormScreen(),
  '/customer_list': (context) => CustomerListScreen(),
  '/customer_detail': (context) => const CustomerDetailScreen(),
  '/device_form': (context) => DeviceFormScreen(),
  '/device_list': (context) => DeviceListScreen(),
  '/device_detail': (context) => const DeviceDetailScreen(),
  '/accumulated_value_list': (context) => AccumulatedValueListScreen(),
  '/order': (context) => OrderForm(),
  '/order_service': (context) => OrderServiceScreen(),
  '/order_product': (context) => OrderProductScreen(),
  '/payment_management': (context) => PaymentManagementScreen(),
  '/financial_dashboard_simple': (context) => FinancialDashboardSimple(),
  '/collaborator_list': (context) => CollaboratorListScreen(),
  '/collaborator_form': (context) => CollaboratorFormScreen(),
  '/company_form': (context) => CompanyFormScreen(),
  '/form_template_list': (context) => FormTemplateListScreen(),
  '/form_template_form': (context) => FormTemplateFormScreen(),
  '/user_profile_edit': (context) => const UserProfileEditScreen(),
  '/ratings': (context) => const RatingsScreen(),
  '/notifications': (context) => const NotificationListScreen(),
  '/contract_list': (context) => const ContractListScreen(),
  '/integrations': (context) => const IntegrationListScreen(),
};
