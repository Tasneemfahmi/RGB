import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth RGB LED Controller',
      home: MyHomePage(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.tealAccent),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: Size(1, 45),
            primary: Colors.tealAccent,
            textStyle: TextStyle(fontSize: 16.0, color: Colors.black),
          ),
        ),
        textTheme: TextTheme(bodyMedium: TextStyle(color: Colors.tealAccent)),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? _selectedDevice;
  BluetoothCharacteristic? _characteristic;
  List<BluetoothDevice> _devices = [];
  Color _currentColor = Colors.white;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth RGB LED Controller'),
        backgroundColor: Colors.tealAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildDeviceSelector(),
            SizedBox(height: 20),
            _buildColorPicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () async {
            await _startScan();
            _showDevicesDialog();
          },
          child: Text('Scan for Devices'),
        ),
        SizedBox(height: 10),
        Text(_selectedDevice == null
            ? 'No Device Selected'
            : 'Selected Device: ${_selectedDevice!.name}'),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
      children: [
        ColorPicker(
          paletteType: PaletteType.hueWheel,
          pickerColor: _currentColor,
          onColorChanged: (color) {
            setState(() {
              _currentColor = color;
            });
          },
          showLabel: true,
          pickerAreaHeightPercent: 0.8,
        ),
        SizedBox(height: 10),
        ElevatedButton(
          onPressed: _sendColorToDevice,
          child: Text('Send Color to LED'),
        ),
      ],
    );
  }

  Future<void> _startScan() async {
    try {
      List<BluetoothDevice> devices = [];
      await flutterBlue.startScan(timeout: Duration(seconds: 4));

      flutterBlue.scanResults.listen((List<ScanResult> scanResults) {
        for (ScanResult result in scanResults) {
          if (!devices.contains(result.device)) {
            setState(() {
              devices.add(result.device);
            });
          }
        }
      });

      await Future.delayed(Duration(seconds: 4));
      flutterBlue.stopScan();

      setState(() {
        _devices = devices;
      });
    } catch (e) {
      print('Error scanning for devices: $e');
    }
  }

  void _sendColorToDevice() async {
    if (_selectedDevice != null && _characteristic != null) {
      try {
        String colorCommand =
            '${_currentColor.red}.${_currentColor.green}.${_currentColor.blue};';
        await _characteristic!.write(colorCommand.codeUnits);
      } catch (e) {
        print('Error sending data: $e');
      }
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('No Device Selected'),
            content: Text('Please select a Bluetooth device.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showDevicesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: EdgeInsets.all(5),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          title: Text('Choose a Bluetooth Device'),
          content: Column(
            children: _devices.map((device) {
              return ListTile(
                title: Text(device.name ?? 'Unknown Device'),
                subtitle: Text(device.id.id.toString()),
                onTap: () async {
                  setState(() {
                    _selectedDevice = device;
                  });
                  await _connectToDevice();
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _connectToDevice() async {
    if (_selectedDevice != null) {
      try {
        await _selectedDevice!.connect();
        List<BluetoothService> services =
            await _selectedDevice!.discoverServices();
        for (BluetoothService service in services) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.properties.write) {
              setState(() {
                _characteristic = characteristic;
              });
              break;
            }
          }
        }
        print('Connected to ${_selectedDevice!.name}');
      } catch (e) {
        print('Error connecting to device: $e');
      }
    }
  }
}
