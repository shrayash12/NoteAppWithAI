import 'package:flutter/material.dart';
import '../utils/image_helper.dart';

void showFullScreenImage(BuildContext context, String? imagePath) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _FullScreenImageViewer(imagePath: imagePath),
        );
      },
    ),
  );
}

class _FullScreenImageViewer extends StatelessWidget {
  final String? imagePath;
  const _FullScreenImageViewer({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: ImageHelper.imageExists(imagePath)
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: ImageHelper.buildImage(imagePath, fit: BoxFit.contain),
                  )
                : const Icon(Icons.broken_image, size: 80, color: Colors.white54),
          ),
        ),
      ),
    );
  }
}
