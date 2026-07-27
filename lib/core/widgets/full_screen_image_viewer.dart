import 'package:flutter/material.dart';

/// A bare full-screen, pinch-zoomable image viewer - used wherever an
/// attachment's "View" action opens an image (transaction entry form,
/// transaction detail screen).
class FullScreenImageViewer extends StatelessWidget {
  final ImageProvider imageProvider;

  const FullScreenImageViewer({super.key, required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(child: Image(image: imageProvider)),
      ),
    );
  }
}
