import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ImageProcessingService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    
    return recognizedText.text;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
