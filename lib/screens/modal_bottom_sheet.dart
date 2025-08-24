import 'package:flutter/material.dart';

class ModalBottomSheet {
  showModal(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            color: Color(0xFF737373),
            height: 180,
            child: Container(
              decoration: BoxDecoration(
                  color: Theme.of(context).canvasColor,
                  borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(15),
                      topRight: const Radius.circular(15))),
              child: Column(children: <Widget>[
                _buildListTile(Icon(Icons.info), Text('Aberto'), () {
                  print('Aberto');
                }),
                _buildListTile(Icon(Icons.info), Text('Em Execução'), () {
                  print('Em Execução');
                }),
                _buildListTile(Icon(Icons.info), Text('Concluído'), () {
                  print('Concluído');
                })
              ]),
            ),
          );
        });
  }

  Widget _buildListTile(Icon icon, Text title, Function onTap) {
    return ListTile(
      leading: icon,
      title: title,
      onTap: () => onTap(),
    );
  }
}
