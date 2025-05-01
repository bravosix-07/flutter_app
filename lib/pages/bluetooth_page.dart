import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:io';
import '../main.dart'; // For globalDevice, globalWriteCharacteristic, and globalDataController

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({super.key});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  final FlutterBluePlus flutterBlue = FlutterBluePlus();
  List<ScanResult> scanResults = [];
  StreamSubscription? scanSubscription;

  final Guid serviceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final Guid characteristicUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");

  String incomingData = "";

  @override
  void initState() {
    super.initState();
    startBluetooth();
    // Listen to live incoming BLE data
    globalDataController.stream.listen((data) {
      setState(() {
        incomingData = data;
      });
    });
  }

  Future<void> startBluetooth() async {
    await FlutterBluePlus.setLogLevel(LogLevel.verbose);
    await FlutterBluePlus.setOptions();

    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported on this device");
      return;
    }

    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10), withServices: [serviceUuid]);
    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect();
    globalDevice = device;

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == characteristicUuid) {
            globalWriteCharacteristic = characteristic;

            // Enable notifications to listen to ESP32 data
            await characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((value) {
              final received = String.fromCharCodes(value);
              globalDataController.add(received);
            });

            setState(() {}); // Refresh page after connecting
            break;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Devices')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                return ListTile(
                  title: Text(device.platformName.isNotEmpty ? device.platformName : device.remoteId.str),
                  subtitle: Text(device.remoteId.str),
                  onTap: () => connectToDevice(device),
                );
              },
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Incoming Data from ESP32:', style: TextStyle(fontSize: 18)),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              incomingData.isNotEmpty ? incomingData : "No data yet...",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
