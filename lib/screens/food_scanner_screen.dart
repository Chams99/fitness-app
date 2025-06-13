import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../services/food_api_service.dart';
import '../services/ai_recognition_service.dart';

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
  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _errorMessage;
  Map<String, dynamic>? _foodData;
  ImageLabeler? _imageLabeler;
  bool _isDisposed = false;
  bool _isFocusing = false;
  List<String> _recognizedLabels = [];
  bool _isAIAvailable = true;

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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      try {
        await _controller!.initialize();

        if (!mounted) return;

        // Configure camera features with error handling
        try {
          await _controller!.setFocusMode(FocusMode.auto);
        } catch (e) {
          print('Failed to set focus mode: $e');
        }

        try {
          await _controller!.setExposureMode(ExposureMode.auto);
        } catch (e) {
          print('Failed to set exposure mode: $e');
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
        _imageLabeler == null)
      return;
    if (_isProcessing || _isFocusing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _recognizedLabels = [];
    });

    try {
      // Focus before taking picture
      _isFocusing = true;
      try {
        await _controller!.setFocusPoint(Offset(0.5, 0.5));
        await _controller!.setFocusMode(FocusMode.locked);
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('Error during focus: $e');
      }
      _isFocusing = false;

      if (_isDisposed) return;

      // Take picture with error handling
      XFile? image;
      try {
        image = await _controller!.takePicture();
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

      // Reset focus after capture
      try {
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (e) {
        print('Error resetting focus: $e');
      }

      // Try AI recognition first
      if (_isAIAvailable) {
        try {
          final labels = await _aiService.recognizeFood(File(image.path));
          if (labels.isNotEmpty) {
            setState(() {
              _recognizedLabels = labels;
            });

            final bestMatch = await _aiService.getBestFoodMatch(labels);
            if (bestMatch != null) {
              final foodData = await _foodApiService.searchFood(bestMatch);
              if (foodData != null) {
                if (mounted) {
                  setState(() {
                    _foodData = foodData;
                  });
                }
                return;
              }
            }
          }
        } catch (e) {
          print('AI recognition failed: $e');
          _isAIAvailable = false;
        }
      }

      // Fallback to ML Kit if AI fails
      try {
        final inputImage = InputImage.fromFilePath(image.path);
        final labels = await _imageLabeler!.processImage(inputImage);

        if (_isDisposed) return;

        if (labels.isEmpty) {
          setState(() {
            _errorMessage = 'No food items detected in the image';
          });
          return;
        }

        // Get the most confident label
        final topLabel = labels.first;
        final foodData = await _foodApiService.searchFood(topLabel.label);

        if (_isDisposed) return;

        if (foodData == null) {
          setState(() {
            _errorMessage =
                'Could not find nutritional information for ${topLabel.label}';
          });
          return;
        }

        if (mounted) {
          setState(() {
            _foodData = foodData;
          });
        }
      } catch (e) {
        print('Error processing image with ML Kit: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Error processing image. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error processing image: $e';
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
