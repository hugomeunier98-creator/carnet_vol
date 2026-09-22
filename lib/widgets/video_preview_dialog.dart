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

String _formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
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
          if (controller != null && controller.value.isInitialized) ...[
            GestureDetector(
              onTap: () => controller.value.isPlaying ? controller.pause() : controller.play(),
              child: VideoPlayer(controller),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Controls(controller: controller),
            ),
          ] else if (_error != null)
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

class _Controls extends StatelessWidget {
  final VideoPlayerController controller;

  const _Controls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 16, 12, 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white),
                    onPressed: () => value.isPlaying ? controller.pause() : controller.play(),
                  ),
                  Text(
                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
