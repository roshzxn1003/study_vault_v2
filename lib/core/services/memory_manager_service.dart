import 'package:flutter/material.dart';

/// Centralized low-end mobile memory manager.
/// Optimizes Dart heap and image caches for devices with 2GB–3GB RAM:
/// - Enforces a 40MB image cache ceiling (down from Flutter's unbounded 100MB+ default).
/// - Caps cached entries at 100 images.
/// - Listens for OS memory pressure (`didHaveMemoryPressure`) and flushes image caches.
/// - Provides explicit `trimMemory()` to call on heavy screen transitions.
class MemoryManagerService with WidgetsBindingObserver {
  MemoryManagerService._();
  static final MemoryManagerService instance = MemoryManagerService._();

  bool _initialized = false;

  /// Initializes image cache constraints and memory pressure hooks.
  void init() {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Bounded image cache for budget/low-RAM mobile devices
    PaintingBinding.instance.imageCache.maximumSizeBytes = 40 * 1024 * 1024; // 40 MB max
    PaintingBinding.instance.imageCache.maximumSize = 100; // max 100 image decodes
  }

  @override
  void didHaveMemoryPressure() {
    debugPrint('[MemoryManagerService] Low memory pressure signal received from OS. Purging caches.');
    trimMemory();
  }

  /// Flushes non-visible decoded images and live references from the image cache.
  void trimMemory() {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      debugPrint('[MemoryManagerService] Error trimming image cache: $e');
    }
  }

  /// Disposes observer (primarily for tests).
  void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
  }
}
