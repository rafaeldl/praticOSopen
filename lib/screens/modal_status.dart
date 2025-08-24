import 'package:praticos/models/order.dart';
import 'package:flutter/material.dart';

class ModalStatus {
  Future showModal(BuildContext context) {
    return showModalBottomSheet(
        context: context,
        builder: (context) {
          var items = Order.statusMap.entries.toList();

          return Container(
            color: Color(0xFF737373),
            height: 275,
            child: Container(
                decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor,
                    borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(15),
                        topRight: const Radius.circular(15))),
                child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      var item = items[i];
                      return _buildListTile(context, Icon(Icons.info),
                          Text(item.value), item.key);
                    })),
          );
        });
  }

  Widget _buildListTile(
      BuildContext context, Icon icon, Text title, String key) {
    return ListTile(
      leading: icon,
      title: title,
      onTap: () => Navigator.pop(context, key),
    );
  }
}
