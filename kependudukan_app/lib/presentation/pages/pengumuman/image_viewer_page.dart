import 'package:flutter/material.dart';

class ImageViewerPage extends StatefulWidget {
  final String imageUrl;
  const ImageViewerPage({Key? key, required this.imageUrl}) : super(key: key);

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_controller.value != Matrix4.identity()) {
      _controller.value = Matrix4.identity();
      return;
    }
    final tapPosition = _doubleTapDetails?.localPosition;
    if (tapPosition == null) return;
    const double zoomScale = 2.5;

    // Hitung translasi agar titik tap menjadi pusat zoom
    final double translateX = -tapPosition.dx * (zoomScale - 1);
    final double translateY = -tapPosition.dy * (zoomScale - 1);

    _controller.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(zoomScale);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: GestureDetector(
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const CircularProgressIndicator(
                          color: Colors.white);
                    },
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white70,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Tutup',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
