import 'package:easy_mask/easy_mask.dart';
import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/device.dart';
import 'package:flutter/material.dart';

class DeviceFormScreen extends StatelessWidget {
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  Map<String, dynamic>? args;

  Device? _device = Device();
  final DeviceStore _deviceStore = DeviceStore();

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args!.containsKey('device')) {
      _device = args!['device'];
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Novo Veículo"),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  await _deviceStore.saveDevice(_device!);
                  Navigator.pop(context, _device);
                }
              },
              child: Text("Salvar"),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.fromLTRB(20, 30, 20, 0),
            child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  _buildManufacturerField(),
                  SizedBox(height: 50.0),
                  _buildNameField(),
                  SizedBox(height: 50.0),
                  _buildSerialField(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManufacturerField() {
    return TextFormField(
      initialValue: _device!.manufacturer,
      decoration: const InputDecoration(
        icon: Icon(Icons.business),
        labelText: 'Fabricante',
      ),
      validator: (value) {
        if (value!.isEmpty) {
          return 'Preencha o nome do fabricante';
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
      decoration: const InputDecoration(
        icon: Icon(Icons.directions_car),
        labelText: 'Modelo',
      ),
      validator: (value) {
        if (value!.isEmpty) {
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
      decoration: const InputDecoration(
        icon: Icon(Icons.info_outline),
        labelText: 'Placa',
      ),
      validator: (value) {
        if (value!.isEmpty) {
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
