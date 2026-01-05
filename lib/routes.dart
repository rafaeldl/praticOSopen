import 'package:flutter/material.dart';
import 'package:praticos/screens/device_form_screen.dart';
import 'package:praticos/screens/device_list_screen.dart';
import 'package:praticos/screens/order_form.dart';
import 'package:praticos/screens/order_product_screen.dart';
import 'package:praticos/screens/menu_navigation/collaborator_form_screen.dart';
import 'package:praticos/screens/menu_navigation/collaborator_list_screen.dart';
import 'package:praticos/screens/menu_navigation/company_form_screen.dart';
import 'package:praticos/screens/order_service_screen.dart';
import 'package:praticos/screens/payment_form_screen.dart';
import 'package:praticos/screens/product_form_screen.dart';
import 'package:praticos/screens/product_list_screen.dart';
import 'package:praticos/screens/customers/customer_form_screen.dart';
import 'package:praticos/screens/customers/customer_list_screen.dart';
import 'package:praticos/screens/info_form_screen.dart';
import 'package:praticos/screens/service_form_screen.dart';
import 'package:praticos/screens/service_list_screen.dart';
import 'package:praticos/screens/dashboard/financial_dashboard_simple.dart';
import 'package:praticos/screens/onboarding/company_info_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/onboarding': (context) => const CompanyInfoScreen(),
  '/service_list': (context) => ServiceListScreen(),
  '/service_form': (context) => ServiceFormScreen(),
  '/product_list': (context) => ProductListScreen(),
  '/product_form': (context) => ProductFormScreen(),
  '/customer_form': (context) => CustomerFormScreen(),
  '/customer_list': (context) => CustomerListScreen(),
  '/device_form': (context) => DeviceFormScreen(),
  '/device_list': (context) => DeviceListScreen(),
  '/info_form': (context) => InfoFormScreen(),
  '/order': (context) => OrderForm(),
  '/order_service': (context) => OrderServiceScreen(),
  '/order_product': (context) => OrderProductScreen(),
  '/payment_form_screen': (context) => PaymentFormScreen(),
  '/financial_dashboard_simple': (context) => FinancialDashboardSimple(),
  '/collaborator_list': (context) => CollaboratorListScreen(),
  '/collaborator_form': (context) => CollaboratorFormScreen(),
  '/company_form': (context) => CompanyFormScreen(),
};
