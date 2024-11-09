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
  final SpeechToText speechToText = SpeechToText();
  bool speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    speechEnabled = await speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _stopListening() async {
    await speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      widget.textController.text =
          result.recognizedWords; // Populate the search bar
      if (!speechToText.isListening && result.recognizedWords.isNotEmpty) {
        widget
            .onSpeechResult(result.recognizedWords); // Trigger search function
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: speechToText.isNotListening ? _startListening : _stopListening,
      tooltip: 'Listen',
      icon: Icon(speechToText.isNotListening ? Icons.mic_off : Icons.mic),
    );
  }
}
