// lib/screens/full_screen_image_viewer.dart

import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String heroTag; // Used for a smooth animation

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // The default back button is fine
      ),
      body: Center(
        child: Hero(
          tag: heroTag, // This tag must match the one on the thumbnail
          child: InteractiveViewer(
            panEnabled: true, 
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => 
                  const Center(child: Icon(Icons.error, color: Colors.red, size: 50)),
            ),
          ),
        ),
      ),
    );
  }
}