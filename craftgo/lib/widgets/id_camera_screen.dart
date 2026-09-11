import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class IDCameraScreen extends StatefulWidget {
  final bool isArabic;

  const IDCameraScreen({super.key, required this.isArabic});

  @override
  State<IDCameraScreen> createState() => _IDCameraScreenState();
}

class _IDCameraScreenState extends State<IDCameraScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;
  Uint8List? _capturedImageBytes;
  String? _errorMessage;
  bool _isProcessingCapture = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _controller = CameraController(
          cameras[0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }
      } else {
        if (mounted) {
          setState(() => _errorMessage = widget.isArabic ? 'لم يتم العثور على كاميرا' : 'No camera found');
        }
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
      if (mounted) {
        setState(() => _errorMessage = widget.isArabic ? 'تعذر الوصول للكاميرا. تأكد من منح الصلاحيات.' : 'Camera access denied or unavailable. Please grant permissions.');
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture || _isProcessingCapture) return;

    setState(() => _isProcessingCapture = true);

    try {
      final originalFile = await _controller!.takePicture();
      final originalBytes = await originalFile.readAsBytes();

      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) {
        throw Exception('Unable to decode captured image');
      }

      final oriented = img.bakeOrientation(decoded);

      if (!mounted) return;

      final screenSize = MediaQuery.sizeOf(context);

      final frameWidth = screenSize.width * 0.85;
      final frameHeight = frameWidth / 1.585;
      final frameLeft = (screenSize.width - frameWidth) / 2;
      final frameTop = (screenSize.height - frameHeight) / 2;

      final scaleX = screenSize.width / oriented.width;
      final scaleY = screenSize.height / oriented.height;
      final coverScale = scaleX > scaleY ? scaleX : scaleY;

      final displayedWidth = oriented.width * coverScale;
      final displayedHeight = oriented.height * coverScale;
      final horizontalCropOnScreen =
          (displayedWidth - screenSize.width) / 2;
      final verticalCropOnScreen =
          (displayedHeight - screenSize.height) / 2;

      int cropX =
      ((frameLeft + horizontalCropOnScreen) / coverScale).round();
      int cropY =
      ((frameTop + verticalCropOnScreen) / coverScale).round();
      int cropWidth = (frameWidth / coverScale).round();
      int cropHeight = (frameHeight / coverScale).round();

      cropX = cropX.clamp(0, oriented.width - 1);
      cropY = cropY.clamp(0, oriented.height - 1);
      cropWidth = cropWidth.clamp(1, oriented.width - cropX);
      cropHeight = cropHeight.clamp(1, oriented.height - cropY);

      final cropped = img.copyCrop(
        oriented,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      final croppedBytes = Uint8List.fromList(
        img.encodeJpg(cropped, quality: 92),
      );

      final croppedFile = XFile.fromData(
        croppedBytes,
        mimeType: 'image/jpeg',
        name: 'craftgo_id_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (!mounted) return;
      setState(() {
        _capturedImage = croppedFile;
        _capturedImageBytes = croppedBytes;
      });
    } catch (e, stackTrace) {
      debugPrint('Error capturing/cropping image: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isArabic
                  ? 'تعذر قص الصورة. حاولي التصوير مرة أخرى.'
                  : 'Could not crop the image. Please retake it.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingCapture = false);
      }
    }
  }

  void _retake() {
    setState(() {
      _capturedImage = null;
      _capturedImageBytes = null;
      _isProcessingCapture = false;
    });
  }

  void _usePhoto() {
    Navigator.of(context).pop(_capturedImage);
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedImage != null && _capturedImageBytes != null) {
      return _buildPreviewScreen();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFD4A017)),
        ),
      );
    }

    return _buildCameraScreen();
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 80),
              const SizedBox(height: 24),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: Text(widget.isArabic ? 'العودة' : 'Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      if (!mounted) return;
                      Navigator.of(context).pop(image);
                    }
                  } catch (e) {
                    debugPrint('Gallery error: $e');
                  }
                },
                icon: const Icon(Icons.photo_library),
                label: Text(widget.isArabic ? 'اختيار من المعرض' : 'Choose from Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4A017),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera feed
          CameraPreview(_controller!),

          // Dark overlay with ID frame cutout
          CustomPaint(
            painter: _IDOverlayPainter(),
            size: Size.infinite,
          ),

          // Instructions at top
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    widget.isArabic
                        ? 'ضع الهوية كاملة داخل الإطار'
                        : 'Fit the ID card inside the frame',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isArabic
                        ? 'تأكد من وضوح الصورة • تجنب الانعكاس والإضاءة القوية'
                        : 'Ensure clarity • Avoid glare and harsh lighting',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Close button
          Positioned(
            top: 50,
            right: 16,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Capture button at bottom
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _takePicture,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: Container(
                      height: 64,
                      width: 64,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: _isProcessingCapture
                          ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFFD4A017),
                        ),
                      )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              widget.isArabic ? 'معاينة الصورة' : 'Preview',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _capturedImageBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  // Retake button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _retake,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        widget.isArabic ? 'إعادة التصوير' : 'Retake',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white60),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Use Photo button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _usePhoto,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        widget.isArabic ? 'استخدام الصورة' : 'Use Photo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A017),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that draws a dark vignette with a clear rectangular cutout
/// in the center representing the ID card frame.
class _IDOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Derive ID card dimensions (standard ratio ~85.6mm × 53.98mm ≈ 1.585)
    final cardWidth = size.width * 0.85;
    final cardHeight = cardWidth / 1.585;
    final dx = (size.width - cardWidth) / 2;
    final dy = (size.height - cardHeight) / 2;

    final rrect = RRect.fromLTRBR(
      dx,
      dy,
      dx + cardWidth,
      dy + cardHeight,
      const Radius.circular(14),
    );

    // Punch out the ID area from the dark overlay
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    // Draw golden border around the cutout
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFFD4A017)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Draw corner accent marks
    final cornerPaint = Paint()
      ..color = const Color(0xFFD4A017)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLen = 20.0;
    final corners = [
      [Offset(dx, dy + cornerLen), Offset(dx, dy), Offset(dx + cornerLen, dy)],
      [Offset(dx + cardWidth - cornerLen, dy), Offset(dx + cardWidth, dy), Offset(dx + cardWidth, dy + cornerLen)],
      [Offset(dx, dy + cardHeight - cornerLen), Offset(dx, dy + cardHeight), Offset(dx + cornerLen, dy + cardHeight)],
      [Offset(dx + cardWidth - cornerLen, dy + cardHeight), Offset(dx + cardWidth, dy + cardHeight), Offset(dx + cardWidth, dy + cardHeight - cornerLen)],
    ];

    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
