import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../services/food_api_service.dart';
import '../services/ai_recognition_service.dart';
import '../services/food_recognition_api_service.dart';

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final FoodApiService _foodApiService = FoodApiService();
  final AIRecognitionService _aiService = AIRecognitionService();
  final FoodRecognitionApiService _recognitionService =
      FoodRecognitionApiService();
  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _errorMessage;
  Map<String, dynamic>? _foodData;
  ImageLabeler? _imageLabeler;
  bool _isDisposed = false;
  bool _isFocusing = false;
  List<String> _recognizedLabels = [];
  bool _isAIAvailable = true;
  DateTime? _lastCaptureTime;
  static const Duration _minCaptureInterval = Duration(seconds: 2);
  List<dynamic> _rawLabels = [];
  double _confidence = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _initializeImageLabeler();
  }

  Future<void> _initializeImageLabeler() async {
    try {
      _imageLabeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.7),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to initialize image recognition: $e';
      });
    }
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
        _imageLabeler == null ||
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
      _recognizedLabels = [];
      _foodData = null;
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
        print('Image saved at: \\${image.path}');

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

      // Process image using the recognition service
      final result = await _recognitionService.recognizeFoodFromImage(
        File(image.path),
      );

      if (_isDisposed) return;

      if (!result['success']) {
        if (mounted) {
          setState(() {
            _errorMessage = result['error'];
            _foodData = null;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _foodData = result['food_data'];
          _recognizedLabels = List<String>.from(result['recognized_labels']);
          _rawLabels = result['raw_labels'] ?? [];
          _confidence = result['confidence'] ?? 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error processing image: $e';
          _foodData = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
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
    _imageLabeler?.close();
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
          if (_foodData != null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_confidence < 0.3)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Low confidence: The result may not be accurate.',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      if (_foodData!['image_url'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _foodData!['image_url'],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _foodData!['product_name'] ?? 'Unknown Food',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (_foodData!['brands'] != null)
                              Text(
                                _foodData!['brands'],
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            if (_foodData!['nutriscore_grade'] != null)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getNutriScoreColor(
                                    _foodData!['nutriscore_grade'],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Nutri-Score: ${_foodData!['nutriscore_grade']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_rawLabels.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'What the AI sees:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ..._rawLabels.map(
                          (r) => Text(
                            '${r['label']} (score: ${(r['score'] as double).toStringAsFixed(3)})',
                            style: TextStyle(
                              color:
                                  (r['score'] as double) >= 0.3
                                      ? Colors.black
                                      : Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nutritional Information (per 100g)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildNutrientRow(
                    'Calories',
                    '${_foodData!['nutriments']?['energy-kcal_100g']?.toString() ?? 'N/A'} kcal',
                  ),
                  _buildNutrientRow(
                    'Protein',
                    '${_foodData!['nutriments']?['proteins_100g']?.toString() ?? 'N/A'}g',
                  ),
                  _buildNutrientRow(
                    'Carbs',
                    '${_foodData!['nutriments']?['carbohydrates_100g']?.toString() ?? 'N/A'}g',
                  ),
                  _buildNutrientRow(
                    'Fat',
                    '${_foodData!['nutriments']?['fat_100g']?.toString() ?? 'N/A'}g',
                  ),
                  if (_foodData!['nutriments']?['fiber_100g'] != null)
                    _buildNutrientRow(
                      'Fiber',
                      '${_foodData!['nutriments']?['fiber_100g']?.toString() ?? 'N/A'}g',
                    ),
                  if (_foodData!['nutriments']?['sodium_100g'] != null)
                    _buildNutrientRow(
                      'Sodium',
                      '${_foodData!['nutriments']?['sodium_100g']?.toString() ?? 'N/A'}g',
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

  Color _getNutriScoreColor(String? grade) {
    switch (grade?.toLowerCase()) {
      case 'a':
        return Colors.green;
      case 'b':
        return Colors.lightGreen;
      case 'c':
        return Colors.yellow;
      case 'd':
        return Colors.orange;
      case 'e':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
