import 'package:praticos/mobx/device_store.dart';
import 'package:praticos/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

class DeviceListScreen extends StatefulWidget {
  @override
  _DeviceListScreenState createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  DeviceStore store = DeviceStore();

  final PageController pageController = PageController();
  Map<String, dynamic>? args;

  @override
  Widget build(BuildContext context) {
    args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args!.containsKey('order')) {
      print('Device List Screen: has order');
    }

    store.retrieveDevices();

    return Scaffold(
      appBar: AppBar(
        title: Text('Veículos'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/device_form').then((device) => {
                    if (args != null && args!.containsKey('order'))
                      {Navigator.pop(context, device)}
                  });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          child: Observer(
            builder: (_) {
              return _buildDeviceList(store);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList(DeviceStore deviceStore) {
    if (deviceStore.deviceList == null) {
      return Center(
        child: ElevatedButton(
          onPressed: deviceStore.retrieveDevices(),
          child: Text('Error'),
        ),
      );
    }

    if (deviceStore.deviceList!.hasError) {
      return Center(
        child: ElevatedButton(
          onPressed: deviceStore.retrieveDevices(),
          child: Text('Error'),
        ),
      );
    }

    List<Device>? deviceList = deviceStore.deviceList!.data;

    if (deviceList == null || deviceList.isEmpty) {
      return Center(
        child: Text(
          'Não há veículos cadastrados',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    List<Device> list = deviceStore.deviceList!.data;

    return Container(
      padding: EdgeInsets.all(0.0),
      margin: EdgeInsets.all(20.0),
      child: ListView.separated(
        itemCount: list.length,
        itemBuilder: (context, index) {
          Device device = list[index];

          return Dismissible(
            direction: DismissDirection.endToStart,
            key: Key(device.id!),
            onDismissed: (direction) {
              deviceStore.deleteDevice(device);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Veículo ${device.name} removido")));
            },
            background: Container(color: Colors.red, child: Icon(Icons.cancel)),
            child: ListTile(
              title: Text("${device.name} ${device.serial} "),
              subtitle: Text(device.manufacturer!),
              trailing: Icon(Icons.keyboard_arrow_right),
              onTap: () {
                print('Selecionado o veiculo');
                if (args != null && args!.containsKey('order')) {
                  Navigator.pop(context, device);
                } else {
                  Navigator.pushNamed(context, '/device_form',
                      arguments: {'device': device});
                }
              },
            ),
          );
        },
        separatorBuilder: (context, index) {
          return Divider();
        },
      ),
    );
  }
}
