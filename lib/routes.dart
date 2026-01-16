import 'package:flutter/material.dart';
import 'package:praticos/screens/device_form_screen.dart';
import 'package:praticos/screens/device_list_screen.dart';
import 'package:praticos/screens/order_form.dart';
import 'package:praticos/screens/order_product_screen.dart';
import 'package:praticos/screens/menu_navigation/collaborator_form_screen.dart';
import 'package:praticos/screens/menu_navigation/collaborator_list_screen.dart';
import 'package:praticos/screens/menu_navigation/company_form_screen.dart';
import 'package:praticos/screens/order_service_screen.dart';
import 'package:praticos/screens/payment_management_screen.dart';
import 'package:praticos/screens/product_form_screen.dart';
import 'package:praticos/screens/product_list_screen.dart';
import 'package:praticos/screens/customers/customer_form_screen.dart';
import 'package:praticos/screens/customers/customer_list_screen.dart';
import 'package:praticos/screens/info_form_screen.dart';
import 'package:praticos/screens/service_form_screen.dart';
import 'package:praticos/screens/service_list_screen.dart';
import 'package:praticos/screens/dashboard/financial_dashboard_simple.dart';
import 'package:praticos/screens/forms/form_template_list_screen.dart';
import 'package:praticos/screens/forms/form_template_form_screen.dart';
import 'package:praticos/screens/user_profile_edit_screen.dart';
import 'package:praticos/screens/accumulated_value_list_screen.dart';
import 'package:praticos/screens/timeline/timeline_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  // '/onboarding': removed - onboarding now handled by AuthWrapper with authStore
  '/service_list': (context) => ServiceListScreen(),
  '/service_form': (context) => ServiceFormScreen(),
  '/product_list': (context) => ProductListScreen(),
  '/product_form': (context) => ProductFormScreen(),
  '/customer_form': (context) => CustomerFormScreen(),
  '/customer_list': (context) => CustomerListScreen(),
  '/device_form': (context) => DeviceFormScreen(),
  '/device_list': (context) => DeviceListScreen(),
  '/accumulated_value_list': (context) => AccumulatedValueListScreen(),
  '/info_form': (context) => InfoFormScreen(),
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
  '/timeline': (context) => const TimelineScreen(),
};
