import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:study_vault/core/services/image_processing_service.dart';
import 'dart:io';

class ScanState {
  final File? image;
  final String? extractedText;
  final bool isProcessing;
  final String? error;

  ScanState({this.image, this.extractedText, this.isProcessing = false, this.error});

  ScanState copyWith({File? image, String? extractedText, bool? isProcessing, String? error}) {
    return ScanState(
      image: image ?? this.image,
      extractedText: extractedText ?? this.extractedText,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error ?? this.error,
    );
  }
}

class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier() : super(ScanState());

  final ImagePicker _picker = ImagePicker();
  final ImageProcessingService _ocrService = ImageProcessingService();

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        state = state.copyWith(image: File(pickedFile.path), extractedText: null, error: null);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick image: $e');
    }
  }

  Future<void> processImage() async {
    if (state.image == null) return;

    state = state.copyWith(isProcessing: true, error: null);
    try {
      final text = await _ocrService.extractText(state.image!.path);
      state = state.copyWith(extractedText: text, isProcessing: false);
    } catch (e) {
      state = state.copyWith(error: 'OCR failed: $e', isProcessing: false);
    }
  }

  void clear() {
    state = ScanState();
  }
}

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier();
});
