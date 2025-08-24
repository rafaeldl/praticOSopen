import 'package:flutter/material.dart';

class ModalMenu {
  Map? options;

  ModalMenu({this.options});

  Future showModal(BuildContext context) {
    return showModalBottomSheet(
        context: context,
        builder: (context) {
          var items = options!.entries.toList();

          return Container(
            color: Color(0xFF737373),
            height: 60.0 * items.length,
            child: Container(
                decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor,
                    borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15))),
                child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      MapEntry item = items[i];
                      Map value = item.value;
                      return _buildListTile(context, value['icon'],
                          Text(value['text']), item.key);
                    })),
          );
        });
  }

  Widget _buildListTile(
      BuildContext context, Icon? icon, Text title, String key) {
    return ListTile(
      leading: icon,
      title: title,
      onTap: () => Navigator.pop(context, key),
    );
  }
}
