import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ladimas/core/utils/image_utils.dart';
import 'package:ladimas/presentation/widgets/camera_ktp_overlay.dart';
import 'package:image_cropper/image_cropper.dart';

/// Custom camera page for document capture with overlay guidance
class DocumentCameraPage extends StatefulWidget {
  final String documentType;
  final String documentTitle;

  const DocumentCameraPage({
    Key? key,
    required this.documentType,
    required this.documentTitle,
  }) : super(key: key);

  @override
  State<DocumentCameraPage> createState() => _DocumentCameraPageState();
}

class _DocumentCameraPageState extends State<DocumentCameraPage> {
  CameraController? _controller;
  late List<CameraDescription> _cameras;
  bool _isInitialized = false;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(
          _cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first,
          ),
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menginisialisasi kamera: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    try {
      final image = await _controller!.takePicture();
      final imageFile = File(image.path);

      File? finalFile = imageFile;

      // Auto-crop for KTP photos
      if (widget.documentType == 'foto_ktp') {
        try {
          final croppedFile = await _cropKtpImage(imageFile);
          if (croppedFile != null) {
            finalFile = croppedFile;
            // Clean up original file
            if (await imageFile.exists()) {
              await imageFile.delete();
            }
          }
        } catch (cropError) {
          // If cropping fails, use original image
          // This allows the app to work even if cropping has issues
          finalFile = imageFile;
        }
      }

      // Process image: compress and convert to WebP
      final processedFile = await ImageUtils.processImage(
        finalFile,
        quality: 80,
        convertToWebP: true,
      );

      // Clean up intermediate file
      if (await finalFile.exists() && finalFile.path != processedFile.path) {
        await finalFile.delete();
      }

      if (mounted) {
        Navigator.pop(context, processedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  Future<File?> _cropKtpImage(File imageFile) async {
    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1.6, ratioY: 1.0), // KTP aspect ratio
        compressQuality: 100, // Keep original quality for cropping
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Sesuaikan Foto KTP',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: true, // Hide bottom controls for cleaner UI
          ),
          IOSUiSettings(
            title: 'Sesuaikan Foto KTP',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      return croppedFile != null ? File(croppedFile.path) : imageFile;
    } catch (e) {
      // If cropping fails, return original file
      return imageFile;
    }
  }


  Widget _buildCameraPreview() {
    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        // Camera preview filling the entire space
        Positioned.fill(
          child: AspectRatio( // Added AspectRatio to maintain camera feed proportions
            aspectRatio: _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),
        ),

        // Conditional overlay
        if (widget.documentType == 'foto_ktp')
          const KtpCameraOverlay()
        else // For non-KTP documents, add a subtle dark overlay with a guide
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.2), // Subtle dark overlay
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description, color: Colors.white.withOpacity(0.7), size: 100),
                  SizedBox(height: 16),
                  Text(
                    widget.documentTitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Posisikan dokumen di area ini',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

        // Capture button
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isTakingPicture ? null : _takePicture,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isTakingPicture ? Colors.grey : Colors.white,
                  border: Border.all(
                    color: _isTakingPicture ? Colors.grey : Colors.black,
                    width: 4,
                  ),
                ),
                child: _isTakingPicture
                  ? const CircularProgressIndicator(
                      color: Colors.black,
                    )
                  : Container(),
              ),
            ),
          ),
        ),

        // Close button
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 10,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 30,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCameraPreview(),
    );
  }
}

