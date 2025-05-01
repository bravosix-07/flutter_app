import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:io';
import '../pages/speech_page.dart';

void main() {
  runApp(const MyApp());
}

// Global variables to share connection between pages
BluetoothDevice? globalDevice;
BluetoothCharacteristic? globalWriteCharacteristic;
StreamController<String> globalDataController = StreamController<String>.broadcast();

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 BLE + Speech',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESP32 BLE + Speech App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('Connect to ESP32'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BLEPage()));
              },
            ),
            ElevatedButton(
              child: const Text('Speech to Text + Send'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SpeechPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class BLEPage extends StatefulWidget {
  const BLEPage({super.key});

  @override
  State<BLEPage> createState() => _BLEPageState();
}

class _BLEPageState extends State<BLEPage> {
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
      print("Bluetooth not supported");
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

            // Enable notifications for receiving data
            await characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((value) {
              final received = String.fromCharCodes(value);
              globalDataController.add(received);
            });

            setState(() {}); // Refresh the page to show connection
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
      appBar: AppBar(title: const Text('BLE Devices')),
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
          const Text('Incoming Data:', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 10),
          Text(
            incomingData.isNotEmpty ? incomingData : "No data received yet.",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
