import 'package:praticos/mobx/service_store.dart';
import 'package:praticos/models/service.dart';
import 'package:flutter/material.dart';

class InfoFormScreen extends StatelessWidget {
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  final Service _service = Service();
  final ServiceStore _serviceStore = ServiceStore();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Nova Informação"),
        ),
        body: SingleChildScrollView(
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.fromLTRB(20, 30, 20, 0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    _buildCommentField(),
                    SizedBox(height: 50.0),
                    _buildImageField(),
                    SizedBox(height: 50.0),
                    ElevatedButton(
                        child: Text(
                          'Salvar',
                          style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 16),
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            _serviceStore.saveService(_service);
                            Navigator.pop(context);
                          }
                        })
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentField() {
    return TextFormField(
      decoration: const InputDecoration(
        icon: Icon(Icons.edit),
        labelText: 'Comentário',
      ),
      validator: (value) {
        if (value!.isEmpty) {
          return 'Campo obrigatório';
        }
        return null;
      },
      onSaved: (String? value) {
        _service.name = value;
      },
    );
  }

  Widget _buildImageField() {
    return GestureDetector(
      child: Container(
        padding: EdgeInsets.all(100),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: Colors.grey[350]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey[200]!,
                blurRadius: 2.0, // soften the shadow
                spreadRadius: 1.2, //extend the shadow
                offset: Offset(
                  5.0, // Move to right 10  horizontally
                  5.0, // Move to bottom 10 Vertically
                ),
              )
            ]),
        child: Icon(
          Icons.camera_alt,
          color: Color(0xFF3498db),
          size: 30.0,
        ),
      ),
      onTap: () {
        print('Image Snapshot');
      },
    );
  }
}
