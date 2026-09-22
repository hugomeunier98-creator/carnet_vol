import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/blob_url.dart';

Future<void> showVideoPreview(BuildContext context, Uint8List bytes, String mimeType) {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: _VideoPlayerView(bytes: bytes, mimeType: mimeType),
    ),
  );
}

class _VideoPlayerView extends StatefulWidget {
  final Uint8List bytes;
  final String mimeType;

  const _VideoPlayerView({required this.bytes, required this.mimeType});

  @override
  State<_VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<_VideoPlayerView> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final url = createObjectUrl(widget.bytes, widget.mimeType);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      controller.play();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return AspectRatio(
      aspectRatio: controller != null && controller.value.isInitialized
          ? controller.value.aspectRatio
          : 16 / 9,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (controller != null && controller.value.isInitialized)
            GestureDetector(
              onTap: () => setState(() {
                controller.value.isPlaying ? controller.pause() : controller.play();
              }),
              child: VideoPlayer(controller),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Impossible de lire la vidéo : $_error',
                  style: const TextStyle(color: Colors.white)),
            )
          else
            const CircularProgressIndicator(color: Colors.white),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
