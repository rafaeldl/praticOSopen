import 'package:flutter/cupertino.dart';
import 'package:easy_mask/easy_mask.dart';
import 'select_segment_screen.dart';

class CompanyInfoScreen extends StatefulWidget {
  final String? companyId; // ID da empresa existente (se houver)
  final String? initialName;
  final String? initialPhone;
  final String? initialAddress;

  const CompanyInfoScreen({
    Key? key,
    this.companyId,
    this.initialName,
    this.initialPhone,
    this.initialAddress,
  }) : super(key: key);

  @override
  State<CompanyInfoScreen> createState() => _CompanyInfoScreenState();
}

class _CompanyInfoScreenState extends State<CompanyInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _addressController = TextEditingController(text: widget.initialAddress);
  }

  void _next() {
    if (_formKey.currentState?.validate() ?? false) {
      // Navega para escolha de segmento, passando os dados
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => SelectSegmentScreen(
            companyId: widget.companyId,
            companyName: _nameController.text,
            phone: _phoneController.text,
            address: _addressController.text,
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
        middle: Text('Criar Empresa'),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Cabeçalho de boas-vindas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      'Bem-vindo ao PráticOS!',
                      style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vamos começar com alguns dados da sua empresa',
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

              // Formulário Agrupado estilo iOS
              CupertinoListSection.insetGrouped(
                header: const Text('DADOS BÁSICOS'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _nameController,
                    prefix: const Text('Nome'),
                    placeholder: 'Nome da Empresa',
                    textCapitalization: TextCapitalization.words,
                    textAlign: TextAlign.right,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Obrigatório';
                      }
                      return null;
                    },
                  ),
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
                    controller: _addressController,
                    prefix: const Text('Endereço'),
                    placeholder: 'Opcional',
                    textCapitalization: TextCapitalization.sentences,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                  ),
                ],
              ),

              const Spacer(),

              // Botão de Ação
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
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
