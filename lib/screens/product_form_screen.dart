import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:praticos/mobx/product_store.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/widgets/cached_image.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Product? _product;
  final ProductStore _productStore = ProductStore();
  bool _isLoading = false;
  bool _initialized = false;
  
  late final CurrencyTextInputFormatter _currencyFormatter;
  final TextEditingController _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currencyFormatter = CurrencyTextInputFormatter.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('product')) {
        _product = args['product'];
      } else {
        _product = Product();
      }
      _valueController.text = _convertToCurrency(_product?.value);
      _initialized = true;
    }
  }

  bool get _isEditing => _product?.id != null;

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();
      await _productStore.saveProduct(_product!);
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context, _product);
      }
    }
  }

  Future<void> _pickImage() async {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Alterar Foto'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Tirar Foto'),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _productStore.photoService.takePhoto();
              if (file != null) {
                await _productStore.uploadProductPhoto(file, _product!);
                setState(() {}); // Força rebuild para mostrar a nova imagem
              }
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Escolher da Galeria'),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _productStore.photoService.pickImageFromGallery();
              if (file != null) {
                await _productStore.uploadProductPhoto(file, _product!);
                setState(() {}); // Força rebuild para mostrar a nova imagem
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? "Editar Produto" : "Novo Produto"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveProduct,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : const Text("Salvar", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              
              // Photo Section
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      if (_product?.photo != null && _product!.photo!.isNotEmpty)
                        ClipOval(
                          child: CachedImage(
                            imageUrl: _product!.photo!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey5.resolveFrom(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.cube_box,
                            size: 50,
                            color: CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                        ),
                      if (_productStore.isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: CupertinoColors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CupertinoActivityIndicator(color: CupertinoColors.white),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: CupertinoColors.activeBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.camera_fill,
                            size: 16,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Form Fields
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Nome", style: TextStyle(fontSize: 16)),
                    initialValue: _product?.name,
                    placeholder: "Nome do produto",
                    textCapitalization: TextCapitalization.sentences,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _product?.name = val,
                    validator: (val) => val == null || val.isEmpty ? "Obrigatório" : null,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: const Text("Valor", style: TextStyle(fontSize: 16)),
                    controller: _valueController,
                    placeholder: "0,00",
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    inputFormatters: [_currencyFormatter],
                    onSaved: (String? value) {
                      if (value != null) {
                        value = value
                            .replaceAll(RegExp(r'R\$'), '')
                            .replaceAll(RegExp(r'\.'), '')
                            .replaceAll(RegExp(r','), '.')
                            .trim();
                        _product!.value = double.tryParse(value) ?? 0;
                      }
                    },
                    validator: (val) => val == null || val.isEmpty ? "Obrigatório" : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null || total == 0) return '';
    NumberFormat numberFormat = NumberFormat.currency(
      locale: 'pt-BR',
      symbol: 'R\$',
    );
    return numberFormat.format(total);
  }
}