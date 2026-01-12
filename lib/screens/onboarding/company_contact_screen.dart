import 'package:flutter/cupertino.dart';
import 'package:easy_mask/easy_mask.dart';
import 'package:image_picker/image_picker.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'select_segment_screen.dart';

class CompanyContactScreen extends StatefulWidget {
  final AuthStore authStore;
  final String? companyId;
  final String companyName;
  final String? address;
  final XFile? logoFile;
  final String? initialPhone;
  final String? initialEmail;
  final String? initialSite;

  const CompanyContactScreen({
    super.key,
    required this.authStore,
    this.companyId,
    required this.companyName,
    this.address,
    this.logoFile,
    this.initialPhone,
    this.initialEmail,
    this.initialSite,
  });

  @override
  State<CompanyContactScreen> createState() => _CompanyContactScreenState();
}

class _CompanyContactScreenState extends State<CompanyContactScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _siteController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController(text: widget.initialEmail);
    _siteController = TextEditingController(text: widget.initialSite);
  }

  void _next() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => SelectSegmentScreen(
            authStore: widget.authStore,
            companyId: widget.companyId,
            companyName: widget.companyName,
            address: widget.address ?? '',
            phone: _phoneController.text,
            email: _emailController.text,
            site: _siteController.text,
            logoFile: widget.logoFile,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Contatos'),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      'Meios de Contato',
                      style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Como seus clientes podem falar com você?',
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),

              CupertinoListSection.insetGrouped(
                header: const Text('CONTATOS'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _phoneController,
                    prefix: const Text('Telefone'),
                    placeholder: '(00) 00000-0000',
                    keyboardType: TextInputType.phone,
                    textAlign: TextAlign.right,
                    inputFormatters: [
                      TextInputMask(mask: ['(99) 9999-9999', '(99) 99999-9999'])
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Obrigatório';
                      }
                      return null;
                    },
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _emailController,
                    prefix: const Text('Email'),
                    placeholder: 'contato@empresa.com',
                    keyboardType: TextInputType.emailAddress,
                    textAlign: TextAlign.right,
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _siteController,
                    prefix: const Text('Site'),
                    placeholder: 'www.exemplo.com.br',
                    keyboardType: TextInputType.url,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _next,
                    child: const Text('Próximo'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _siteController.dispose();
    super.dispose();
  }
}
