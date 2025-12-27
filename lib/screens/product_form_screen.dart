import 'dart:io';

import 'package:praticos/mobx/product_store.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({Key? key}) : super(key: key);

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Product? _product;
  final ProductStore _productStore = ProductStore();
  bool _isLoading = false;
  bool _initialized = false;

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
      Navigator.pop(context, _product);
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeria'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await _productStore.photoService.pickImageFromGallery();
                  if (file != null) {
                    await _productStore.uploadProductPhoto(file, _product!);
                    setState(() {}); // Força rebuild para mostrar a nova imagem
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Câmera'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await _productStore.photoService.takePhoto();
                  if (file != null) {
                    await _productStore.uploadProductPhoto(file, _product!);
                    setState(() {}); // Força rebuild para mostrar a nova imagem
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Editar Produto" : "Novo Produto"),
        elevation: 0,
      ),
      body: Observer(
        builder: (_) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header icon / Photo
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          if (_product?.photo != null && _product!.photo!.isNotEmpty)
                            ClipOval(
                              child: CachedImage(
                                imageUrl: _product!.photo!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.inventory_2,
                                size: 60,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          if (_productStore.isUploading)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary,
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Form fields
                  _buildNameField(),
                const SizedBox(height: 16),
                _buildValueField(),
                const SizedBox(height: 32),
                // Save button
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveProduct,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isLoading ? 'Salvando...' : 'Salvar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? prefix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      initialValue: _product!.name,
      decoration: _inputDecoration(
        label: 'Nome',
        icon: Icons.inventory_2_outlined,
        hint: 'Nome do produto',
      ),
      textCapitalization: TextCapitalization.sentences,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Preencha o nome do produto';
        }
        return null;
      },
      onSaved: (String? value) {
        _product!.name = value;
      },
    );
  }

  Widget _buildValueField() {
    return TextFormField(
      initialValue: _convertToCurrency(_product!.value),
      decoration: _inputDecoration(
        label: 'Valor',
        icon: Icons.attach_money,
        hint: '0,00',
      ),
      inputFormatters: [
        CurrencyTextInputFormatter.currency(
          locale: 'pt_BR',
          symbol: 'R\$ ',
          decimalDigits: 2,
        ),
      ],
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Preencha o valor do produto';
        }
        return null;
      },
      onSaved: (String? value) {
        value = value!
            .replaceAll(RegExp(r'R\$'), '')
            .replaceAll(RegExp(r'\.'), '')
            .replaceAll(RegExp(r','), '.')
            .trim();
        _product!.value = double.tryParse(value) ?? 0;
      },
    );
  }

  String _convertToCurrency(double? total) {
    if (total == null || total == 0) return '';
    NumberFormat numberFormat = NumberFormat.currency(
      locale: 'pt-BR',
      symbol: '',
    );
    return numberFormat.format(total);
  }
}
