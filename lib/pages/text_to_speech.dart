import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class TextToSpeech extends StatefulWidget {
  final TextEditingController textController;
  final Function(String) onSpeechResult; // Pass search function as callback

  const TextToSpeech({
    super.key,
    required this.textController,
    required this.onSpeechResult,
  });

  @override
  _TextToSpeechState createState() => _TextToSpeechState();
}

class _TextToSpeechState extends State<TextToSpeech> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      widget.textController.text =
          result.recognizedWords; // Populate the search bar
      if (!_speechToText.isListening && result.recognizedWords.isNotEmpty) {
        widget
            .onSpeechResult(result.recognizedWords); // Trigger search function
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed:
          _speechToText.isNotListening ? _startListening : _stopListening,
      tooltip: 'Listen',
      icon: Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
    );
  }
}
