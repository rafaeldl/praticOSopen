import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:praticos/global.dart';

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final UserStore _userStore = UserStore();

  final List<String> item = ['Serviço', 'Produto', 'Cliente'];

  @override
  Widget build(BuildContext context) {
    _userStore.findCurrentUser();

    return Scaffold(
      appBar: AppBar(title: Text('Ajustes')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
          child: Column(
            children: <Widget>[
              Container(
                decoration: new BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Color(0xfffcbf1e),
                    )),
                child: CircleAvatar(
                  radius: 80,
                  backgroundImage: NetworkImage(Global.currentUser!.photoURL!),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      Global.currentUser!.displayName!,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 17.0,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      Global.currentUser!.email!,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 17.0,
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeader('CADASTRO'),
              _buildListTile('Clientes', FontAwesomeIcons.userPen, () {
                Navigator.pushNamed(context, '/customer_list');
              }),
              Divider(),
              _buildListTile('Veículos', FontAwesomeIcons.car, () {
                Navigator.pushNamed(context, '/device_list');
              }),
              Divider(),
              _buildListTile('Serviços', FontAwesomeIcons.wrench, () {
                Navigator.pushNamed(context, '/service_list');
              }),
              Divider(),
              _buildListTile('Produtos', Icons.devices_other, () {
                Navigator.pushNamed(context, '/product_list');
              }),
              _buildHeader('CONFIGURAÇÕES'),
              // _buildListTile('Empresa', Icons.business, () {}),
              // _buildHeader('APLICATIVO'),
              // _buildListTile('Sobre', Icons.info, () {}),
              // Divider(),
              // _buildListTile('Termos de uso', Icons.view_list, () {}),
              // Divider(),
              _buildListTile('Sair', Icons.exit_to_app, () async {
                AuthStore().signOutGoogle();
              }),
              Divider(),
              _buildVersionNumber(),
            ],
          ),
        ),
      ),
    );
  }

  Padding _buildListTile(text, icon, Function onTapAction) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ListTile(
          leading: Icon(icon),
          title: Text(
            text,
            style: TextStyle(
              color: Color(0xFF34495e),
              fontWeight: FontWeight.bold,
              fontSize: 15.0,
            ),
          ),
          onTap: onTapAction as void Function()?),
    );
  }

  Padding _buildHeader(text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6.0, 0, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Color(0x888888),
                boxShadow: [
                  BoxShadow(
                    offset: Offset(0.00, 4.00),
                    color: Color(0xff455b63).withOpacity(0.08),
                    blurRadius: 10,
                  ),
                ],
                borderRadius: BorderRadius.circular(9.00),
                border: Border.all(
                  color: Colors.grey,
                  width: 0.1,
                ),
              ),
              child: ListTile(
                title: Text(
                  text,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Padding _buildVersionNumber() {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ListTile(
        leading: Icon(Icons.info_outline),
        title: Text(
          'Versão ' + Global.version,
          style: TextStyle(
            color: Color(0xFF34495e),
            fontWeight: FontWeight.bold,
            fontSize: 14.0,
          ),
        ),
      ),
    );
  }
}
