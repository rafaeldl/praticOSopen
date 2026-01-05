import 'package:flutter/material.dart';
import '../models/device_catalog_item.dart';
import '../repositories/device_catalog_repository.dart';

class DeviceAutocompleteField extends StatefulWidget {
  final String companyId;
  final String label;
  final String type; // "brand" ou "model"
  final String? initialValue;
  final Function(String) onSelected;
  final String? brandFilter; // Para filtrar modelos por marca
  final String? brandId; // ID da brand selecionada (para modelos)

  const DeviceAutocompleteField({
    Key? key,
    required this.companyId,
    required this.label,
    required this.type,
    this.initialValue,
    required this.onSelected,
    this.brandFilter,
    this.brandId,
  }) : super(key: key);

  @override
  State<DeviceAutocompleteField> createState() =>
      _DeviceAutocompleteFieldState();
}

class _DeviceAutocompleteFieldState extends State<DeviceAutocompleteField> {
  final _repo = DeviceCatalogRepository();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  Future<List<String>> _getSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      if (widget.type == 'brand') {
        // Busca brands
        final brands = await _repo.searchBrands(widget.companyId, query);
        return brands.map((b) => b.name).toList();
      } else {
        // Busca modelos
        final models = await _repo.searchModels(
          widget.companyId,
          query,
          brandId: widget.brandId,
        );
        return models.map((m) => m.model).toSet().toList(); // Remove duplicatas
      }
    } catch (e) {
      debugPrint('Erro ao buscar sugestões: $e');
      return [];
    }
  }

  void _handleSelection(String value) {
    widget.onSelected(value);

    // Incrementa uso no catálogo
    if (widget.type == 'brand') {
      _repo.addOrIncrementBrand(widget.companyId, value);
    } else {
      // Para modelos, precisa do brandName também
      if (widget.brandFilter != null) {
        final item = DeviceCatalogItem(
          brandId: widget.brandId,
          brand: widget.brandFilter!,
          model: value,
          searchKey: DeviceCatalogItem.generateSearchKey(
            widget.brandFilter!,
            value,
          ),
        );
        _repo.addOrIncrementModel(widget.companyId, item);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.initialValue ?? ''),
      optionsBuilder: (textEditingValue) async {
        return await _getSuggestions(textEditingValue.text);
      },
      onSelected: _handleSelection,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        // Sincroniza com controller local
        if (controller.text != _controller.text) {
          _controller.text = controller.text;
        }

        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _handleSelection(value);
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
