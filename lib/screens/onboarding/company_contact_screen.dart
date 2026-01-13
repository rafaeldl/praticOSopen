import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/widgets/dynamic_text_field.dart';
import 'package:praticos/providers/segment_config_provider.dart';
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
  String? _phone;
  late final TextEditingController _emailController;
  late final TextEditingController _siteController;
  bool _isLoading = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _phone = widget.initialPhone;
    _emailController = TextEditingController(text: widget.initialEmail);
    _siteController = TextEditingController(text: widget.initialSite);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Executa apenas uma vez
    if (!_initialized) {
      _initialized = true;
      _loadGlobalSegment();
    }
  }

  Future<void> _loadGlobalSegment() async {
    // Agenda para depois do build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final provider = context.read<SegmentConfigProvider>();

      // Se já está carregado, não precisa carregar novamente
      if (!provider.isLoaded) {
        try {
          await provider.initialize('global');

          // Detecta país do locale do dispositivo
          final locale = Localizations.localeOf(context);
          final countryCode = locale.countryCode ?? 'BR'; // Fallback para BR
          provider.setCountry(countryCode);
        } catch (e) {
          // Se falhar, continua sem máscaras
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _next() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => SelectSegmentScreen(
            authStore: widget.authStore,
            companyId: widget.companyId,
            companyName: widget.companyName,
            address: widget.address ?? '',
            phone: _phone ?? '',
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
    if (_isLoading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

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
                  DynamicTextField(
                    fieldKey: 'company.phone',
                    initialValue: _phone,
                    required: true,
                    onSaved: (val) => _phone = val,
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
    _emailController.dispose();
    _siteController.dispose();
    super.dispose();
  }
}
