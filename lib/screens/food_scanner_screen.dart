import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_food_analyzer_service.dart';
import 'package:iconsax/iconsax.dart';

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isDisposed = false;
  bool _isFocusing = false;
  bool _isAIAvailable = true;
  DateTime? _lastCaptureTime;
  static const Duration _minCaptureInterval = Duration(seconds: 2);
  final ImagePicker _picker = ImagePicker();
  final GeminiFoodAnalyzerService _analyzerService =
      GeminiFoodAnalyzerService();

  File? _selectedImage;
  Map<String, dynamic>? _analysisResult;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available';
        });
        return;
      }

      // Try to get the back camera first
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      try {
        await _controller!.initialize();

        if (!mounted) return;

        // Configure camera features with error handling
        try {
          // Set optimal capture settings
          await Future.wait([
            _controller!.setFocusMode(FocusMode.auto),
            _controller!.setExposureMode(ExposureMode.auto),
            _controller!.setFlashMode(FlashMode.off),
          ]);

          // Wait for camera to stabilize
          await Future.delayed(const Duration(milliseconds: 500));

          // Set exposure and focus points
          await Future.wait([
            _controller!.setExposurePoint(Offset(0.5, 0.5)),
            _controller!.setFocusPoint(Offset(0.5, 0.5)),
          ]);
        } catch (e) {
          print('Failed to configure camera features: $e');
        }

        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
        });
        _controller?.dispose();
        _controller = null;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _processImage() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing ||
        _isFocusing) {
      return;
    }

    // Check if enough time has passed since last capture
    if (_lastCaptureTime != null &&
        DateTime.now().difference(_lastCaptureTime!) < _minCaptureInterval) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _analysisResult = null;
    });

    try {
      // Focus before taking picture
      _isFocusing = true;
      try {
        // Lock focus and exposure
        await Future.wait([
          _controller!.setFocusPoint(Offset(0.5, 0.5)),
          _controller!.setExposurePoint(Offset(0.5, 0.5)),
        ]);
        await _controller!.setFocusMode(FocusMode.locked);

        // Wait for focus to lock
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        print('Error during focus: $e');
      }
      _isFocusing = false;

      if (_isDisposed) return;

      // Take picture with error handling
      XFile? image;
      try {
        // Ensure camera is ready
        if (!_controller!.value.isInitialized) {
          throw Exception('Camera not initialized');
        }

        // Take the picture
        image = await _controller!.takePicture();
        _lastCaptureTime = DateTime.now();
        print('Image saved at: ${image.path}');

        // Reset focus after capture
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (e) {
        print('Error taking picture: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to capture image. Please try again.';
            _isProcessing = false;
          });
        }
        return;
      }

      if (_isDisposed || image == null) return;

      // Process image using the new Gemini analyzer service
      print('Starting Gemini analysis for image: ${image.path}');

      if (mounted) {
        setState(() {
          _errorMessage = null; // Clear any previous errors
        });
      }

      final result = await _analyzerService.analyzeFoodImage(File(image.path));
      print('Gemini analysis completed: $result');

      if (_isDisposed) return;

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isProcessing = false;

          // Show user-friendly error messages
          if (!result['success']) {
            final String error = result['error'] ?? 'Unknown error occurred';
            final int attempts = result['attempts'] ?? 1;

            if (error.contains('TimeoutException') ||
                error.contains('timeout')) {
              _errorMessage =
                  'Analysis timed out after $attempts attempt${attempts > 1 ? 's' : ''}. Please check your internet connection and try again.';

              // Run diagnostic test to help identify the issue
              _runDiagnosticTest();
            } else if (error.contains('Rate limit') || error.contains('429')) {
              _errorMessage =
                  'Service is busy. Please wait a moment and try again.';
            } else if (error.contains('API key')) {
              _errorMessage = 'Configuration error. Please contact support.';
            } else if (error.contains('Could not recognize')) {
              _errorMessage =
                  'Could not identify the food item. Try taking a clearer photo or ensuring good lighting.';
            } else {
              _errorMessage =
                  attempts > 1
                      ? 'Failed after $attempts attempts: ${error.length > 100 ? '${error.substring(0, 100)}...' : error}'
                      : error.length > 100
                      ? '${error.substring(0, 100)}...'
                      : error;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error processing image: $e';
          _analysisResult = null;
          _isProcessing = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFocusing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Food Scanner')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeCamera,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Food Scanner')),
      body: Column(
        children: [
          Expanded(child: _buildCameraPreview()),
          if (_isProcessing || _isAnalyzing)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 16),
                      Text('Analyzing food image...'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This may take up to 30 seconds',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          if (_analysisResult != null) _buildAnalysisResult(),
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Iconsax.warning_2, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (_isProcessing || _isFocusing) ? null : _processImage,
        child:
            (_isProcessing || _isFocusing)
                ? const CircularProgressIndicator()
                : const Icon(Icons.camera),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: 1 / _controller!.value.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(
              _controller!,
              child: GestureDetector(
                onTapDown: (details) => _onTapDown(details),
                onTapUp: (_) => _onTapUp(),
                onTapCancel: () => _onTapUp(),
              ),
            ),
            if (_isFocusing)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTapDown(TapDownDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final CameraController cameraController = _controller!;
      final Offset offset = Offset(
        details.localPosition.dx / cameraController.value.previewSize!.height,
        details.localPosition.dy / cameraController.value.previewSize!.width,
      );

      setState(() {
        _isFocusing = true;
      });

      await cameraController.setFocusPoint(offset);
      await cameraController.setFocusMode(FocusMode.locked);

      // Reset focus after a delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await cameraController.setFocusMode(FocusMode.auto);
        setState(() {
          _isFocusing = false;
        });
      }
    } catch (e) {
      print('Error during focus: $e');
      if (mounted) {
        setState(() {
          _isFocusing = false;
        });
      }
    }
  }

  void _onTapUp() {
    if (mounted) {
      setState(() {
        _isFocusing = false;
      });
    }
  }

  Future<void> _runDiagnosticTest() async {
    print('Running diagnostic test due to timeout...');
    try {
      final testResult = await _analyzerService.testGeminiConnection();
      print('Diagnostic test result: $testResult');

      if (!testResult['success']) {
        print('Diagnostic Issue Found: ${testResult['error']}');
        if (testResult['suggestions'] != null) {
          print('Suggestions: ${testResult['suggestions']}');
        }
      }
    } catch (e) {
      print('Error running diagnostic test: $e');
    }
  }

  Widget _buildNutrientRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _analysisResult = null;
          _errorMessage = null;
        });

        await _analyzeFood();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking image: $e';
      });
    }
  }

  Future<void> _analyzeFood() async {
    if (_selectedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await _analyzerService.analyzeFoodImage(_selectedImage!);

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error analyzing food: $e';
        _isAnalyzing = false;
      });
    }
  }

  Widget _buildAnalysisResult() {
    if (_analysisResult == null) return const SizedBox.shrink();

    final success = _analysisResult!['success'] as bool;

    if (!success) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Iconsax.close_circle, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                'Analysis Failed',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _analysisResult!['error'] ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final foodData = _analysisResult!['food_data'] as Map<String, dynamic>;
    final nutriments = foodData['nutriments'] as Map<String, dynamic>;
    final confidence = _analysisResult!['confidence'] as double;
    final recognizedFood = _analysisResult!['recognized_food'] as String?;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    foodData['product_name'] ?? 'Unknown Food',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (recognizedFood != null) ...[
              Text(
                'Recognized as: $recognizedFood',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Nutritional Information (per 100g)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildNutritionRow(
              'Calories',
              '${nutriments['energy-kcal_100g']?.toStringAsFixed(1) ?? 'N/A'} kcal',
            ),
            _buildNutritionRow(
              'Protein',
              '${nutriments['proteins_100g']?.toStringAsFixed(1) ?? 'N/A'}g',
            ),
            _buildNutritionRow(
              'Carbohydrates',
              '${nutriments['carbohydrates_100g']?.toStringAsFixed(1) ?? 'N/A'}g',
            ),
            _buildNutritionRow(
              'Fat',
              '${nutriments['fat_100g']?.toStringAsFixed(1) ?? 'N/A'}g',
            ),
            _buildNutritionRow(
              'Fiber',
              '${nutriments['fiber_100g']?.toStringAsFixed(1) ?? 'N/A'}g',
            ),
            if (foodData['brands'] != null) ...[
              const SizedBox(height: 12),
              Text(
                'Brand: ${foodData['brands']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
