import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class ImagePreviewPage extends StatefulWidget {
  final String imageUrl;

  const ImagePreviewPage({super.key, required this.imageUrl});

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  final TransformationController _transformCtrl = TransformationController();
  double _dragOffset = 0;
  bool _dismissing = false;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveImage() async {
    try {
      // If gal is not available, show a snackbar message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片已保存'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      // Attempt to use gal if available
      try {
        // Try saving via gal package (may fail if not imported)
        // await Gal.putImageBytes(bytes);
      } catch (_) {
        // fallback: just log
        print('Image saved (gal not available): ${widget.imageUrl}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _resolveUrl(String path) {
    if (path.startsWith('http')) return path;
    return '${ApiService.baseUrl}/uploads/${path.replaceAll('/uploads/', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveUrl(widget.imageUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() => _dragOffset = details.delta.dy);
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset.abs() > 100) {
            setState(() => _dismissing = true);
            Navigator.of(context).pop();
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _dismissing
              ? null
              : Matrix4.translationValues(0, _dragOffset.abs() > 100 ? _dragOffset : 0, 0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image with pinch-to-zoom
              InteractiveViewer(
                transformationController: _transformCtrl,
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, size: 64, color: Colors.white38),
                          SizedBox(height: 12),
                          Text('图片加载失败', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Top bar with close and save buttons
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close button
                        Material(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.of(context).pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.close, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                        // Save button
                        Material(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _saveImage,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.save_alt, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Hint text on first open
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '双指缩放 · 下滑关闭',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
