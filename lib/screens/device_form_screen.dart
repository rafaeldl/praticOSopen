
import 'package:easy_mask/easy_mask.dart';
import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

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
      Navigator.pop(context, _device);
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
                  final file = await _deviceStore.photoService.pickImageFromGallery();
                  if (file != null) {
                    await _deviceStore.uploadDevicePhoto(file, _device!);
                    setState(() {});
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Câmera'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await _deviceStore.photoService.takePhoto();
                  if (file != null) {
                    await _deviceStore.uploadDevicePhoto(file, _device!);
                    setState(() {});
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
        title: Text(_isEditing ? "Editar Veículo" : "Novo Veículo"),
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
                          if (_device?.photo != null)
                            ClipOval(
                              child: CachedImage(
                                imageUrl: _device!.photo!,
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
                                Icons.directions_car,
                                size: 60,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          if (_deviceStore.isUploading)
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
                  _buildManufacturerField(),
                const SizedBox(height: 16),
                _buildNameField(),
                const SizedBox(height: 16),
                _buildSerialField(),
                const SizedBox(height: 32),
                // Save button
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveDevice,
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
    ));
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
    );
  }

  Widget _buildManufacturerField() {
    return TextFormField(
      initialValue: _device!.manufacturer,
      decoration: _inputDecoration(
        label: 'Fabricante',
        icon: Icons.business_outlined,
        hint: 'Ex: Fiat, Volkswagen, Honda',
      ),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Preencha o fabricante';
        }
        return null;
      },
      onSaved: (String? value) {
        _device!.manufacturer = value;
      },
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      initialValue: _device!.name,
      decoration: _inputDecoration(
        label: 'Modelo',
        icon: Icons.directions_car_outlined,
        hint: 'Ex: Uno, Gol, CG 160',
      ),
      textCapitalization: TextCapitalization.words,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Preencha o modelo';
        }
        return null;
      },
      onSaved: (String? value) {
        _device!.name = value;
      },
    );
  }

  Widget _buildSerialField() {
    return TextFormField(
      initialValue: _device!.serial,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [TextInputMask(mask: 'AAA9N99')],
      decoration: _inputDecoration(
        label: 'Placa',
        icon: Icons.pin_outlined,
        hint: 'ABC1D23',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Preencha a placa';
        }
        return null;
      },
      onSaved: (String? value) {
        _device!.serial = value!.toUpperCase();
      },
    );
  }
}
