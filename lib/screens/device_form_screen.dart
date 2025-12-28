import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/widgets/cached_image.dart';

class DeviceFormScreen extends StatefulWidget {
  const DeviceFormScreen({Key? key}) : super(key: key);

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Device? _device;
  final DeviceStore _deviceStore = DeviceStore();
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('device')) {
        _device = args['device'];
      } else {
        _device = Device();
      }
      _initialized = true;
    }
  }

  bool get _isEditing => _device?.id != null;

  Future<void> _saveDevice() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      _formKey.currentState!.save();
      await _deviceStore.saveDevice(_device!);
      setState(() => _isLoading = false);
      if (mounted) {
        Navigator.pop(context, _device);
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
              final file = await _deviceStore.photoService.takePhoto();
              if (file != null) {
                await _deviceStore.uploadDevicePhoto(file, _device!);
                setState(() {});
              }
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Escolher da Galeria'),
            onPressed: () async {
              Navigator.pop(context);
              final file = await _deviceStore.photoService.pickImageFromGallery();
              if (file != null) {
                await _deviceStore.uploadDevicePhoto(file, _device!);
                setState(() {});
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
        middle: Text(_isEditing ? "Editar Veículo" : "Novo Veículo"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveDevice,
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
                      if (_device?.photo != null && _device!.photo!.isNotEmpty)
                        ClipOval(
                          child: CachedImage(
                            imageUrl: _device!.photo!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 100,
                          height: 100,
                          decoration: const BoxDecoration(
                            color: CupertinoColors.systemGrey5,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.car_detailed,
                            size: 50,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      if (_deviceStore.isUploading)
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
                  _buildCupertinoFormField(
                    label: "Fabricante",
                    initialValue: _device?.manufacturer,
                    placeholder: "Ex: Fiat, VW",
                    textCapitalization: TextCapitalization.words,
                    onSaved: (val) => _device?.manufacturer = val,
                    validator: (val) => val == null || val.isEmpty ? "Obrigatório" : null,
                  ),
                  _buildCupertinoFormField(
                    label: "Modelo",
                    initialValue: _device?.name,
                    placeholder: "Ex: Uno, Gol",
                    textCapitalization: TextCapitalization.words,
                    onSaved: (val) => _device?.name = val,
                    validator: (val) => val == null || val.isEmpty ? "Obrigatório" : null,
                  ),
                  _buildCupertinoFormField(
                    label: "Placa",
                    initialValue: _device?.serial,
                    placeholder: "ABC1D23",
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [TextInputMask(mask: 'AAA9N99')],
                    onSaved: (val) => _device?.serial = val?.toUpperCase(),
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

  Widget _buildCupertinoFormField({
    required String label,
    String? initialValue,
    String? placeholder,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
  }) {
    return CupertinoListTile(
      title: SizedBox(
        width: 80,
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
      additionalInfo: SizedBox(
        width: 200, // Constrain width or use Expanded logic if possible within ListTile
        child: CupertinoTextFormFieldRow(
          initialValue: initialValue,
          placeholder: placeholder,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          padding: EdgeInsets.zero,
          textAlign: TextAlign.right,
          decoration: null, // Remove border
          style: const TextStyle(color: CupertinoColors.label),
          validator: validator,
          onSaved: onSaved,
        ),
      ),
    );
  }
}
