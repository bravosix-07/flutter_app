import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../main.dart'; // For globalWriteCharacteristic

class SpeechPage extends StatefulWidget {
  const SpeechPage({super.key});

  @override
  State<SpeechPage> createState() => _SpeechPageState();
}

class _SpeechPageState extends State<SpeechPage> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    initializeSpeech();
  }

  Future<void> initializeSpeech() async {
    await Permission.microphone.request();
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!_speech.isListening) {
              startListening();
            }
          });
        }
      },
      onError: (error) {
        Future.delayed(const Duration(seconds: 1), () {
          if (!_speech.isListening) {
            startListening();
          }
        });
      },
      debugLogging: false,
    );
    if (available) {
      startListening();
    }
  }

  Future<void> startListening() async {
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
    );
  }

  Future<void> sendTextCharacterByCharacter() async {
    if (globalWriteCharacteristic != null && _recognizedText.isNotEmpty) {
      for (var ch in _recognizedText.characters) {
        await globalWriteCharacteristic!.write(ch.codeUnits, withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 100)); // delay to avoid ESP32 buffer overflow
      }
    } else {
      print("No BLE device connected or no text to send");
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speech to Text')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  _recognizedText.isEmpty ? 'Say something...' : _recognizedText,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: sendTextCharacterByCharacter,
              child: const Text('Send Text Character-by-Character'),
            ),
          ],
        ),
      ),
    );
  }
}
