// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:flutter/material.dart';

// class SpeechService {
//   static final stt.SpeechToText _speech = stt.SpeechToText();
//   static bool _isAvailable = false;

//   // Initialize the speech recognition service
//   static Future<void> initialize() async {
//     _isAvailable = await _speech.initialize(
//       onStatus: (status) {
//         if (kDebugMode) {
//           print("Speech status: $status");
//         }
//       },
//       onError: (error) {
//         if (kDebugMode) {
//           print("Speech recognition error: ${error.errorMsg}");
//         }
//       },
//     );
//   }

//   // Get speech input from the user
//   static Future<String> getSpeechInput(BuildContext context) async {
//     if (!_isAvailable) {
//       await initialize();
//       if (!_isAvailable) {
//         throw Exception("Speech recognition not available");
//       }
//     }

//     final completer = Completer<String>();
//     String recognizedText = "";

//     _speech.listen(
//       onResult: (result) {
//         if (result.finalResult) {
//           recognizedText = result.recognizedWords;
//           if (kDebugMode) {
//             print("Recognized: $recognizedText");
//           }
//           if (!completer.isCompleted) {
//             completer.complete(recognizedText); // Complete with recognized text
//           }
//         }
//       },
//       listenFor: const Duration(seconds: 30),
//       pauseFor: const Duration(seconds: 10), // Increased pause duration
//       partialResults: true,
//       listenMode: stt.ListenMode.confirmation,
//       cancelOnError: false, // Don't cancel on error
//     ).catchError((error) {
//       if (kDebugMode) {
//         print("Speech error occurred: $error");
//       }
//       // Handle error cases
//       if (!completer.isCompleted) {
//         completer.completeError('An error occurred during speech recognition: $error');
//       }
//     });

//     // Set a timeout for the speech recognition to stop after 30 seconds
//     Future.delayed(const Duration(seconds: 30), () {
//       if (!completer.isCompleted) {
//         _speech.stop();
//         completer.completeError('Speech recognition timed out');
//       }
//     });

//     // Return the recognized text or error message
//     return completer.future;
//   }

//   // Stop listening for speech input
//   static void stopListening() {
//     if (_speech.isListening) {
//       _speech.stop();
//     }
//   }

//   // Check if the system is currently listening for speech input
//   static bool isListening() {
//     return _speech.isListening;
//   }
// }
