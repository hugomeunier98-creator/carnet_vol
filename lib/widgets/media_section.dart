import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/blob_opener.dart';
import '../services/media_service.dart';

class MediaSection extends StatefulWidget {
  final String flightId;

  const MediaSection({super.key, required this.flightId});

  @override
  State<MediaSection> createState() => _MediaSectionState();
}

class _MediaSectionState extends State<MediaSection> {
  final _mediaService = MediaService();
  List<MediaItem> _items = [];
  bool _loading = true;
  bool _adding = false;
  int _addProgress = 0;
  int _addTotal = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _mediaService.forFlight(widget.flightId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
    _backfillThumbnails(items);
  }

  Future<void> _backfillThumbnails(List<MediaItem> items) async {
    final missing = items.where((i) => i.isVideo && i.thumbnail == null);
    var changed = false;
    for (final item in missing) {
      if (await _mediaService.backfillThumbnail(item)) changed = true;
    }
    if (!changed || !mounted) return;
    final refreshed = await _mediaService.forFlight(widget.flightId);
    if (!mounted) return;
    setState(() => _items = refreshed);
  }

  Future<void> _addMedia() async {
    List<dynamic> files;
    try {
      files = await _mediaService.pickFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Impossible d'ouvrir la galerie : $e")));
      }
      return;
    }
    if (files.isEmpty) return;

    setState(() {
      _adding = true;
      _addProgress = 0;
      _addTotal = files.length;
    });
    var skipped = 0;
    for (final file in files) {
      try {
        final pending = await _mediaService.process(file);
        await _mediaService.saveForFlight(pending, widget.flightId);
      } catch (_) {
        skipped++;
      }
      if (mounted) setState(() => _addProgress++);
    }
    await _load();
    if (mounted) {
      setState(() => _adding = false);
      if (skipped > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$skipped fichier(s) ignoré(s) (trop volumineux ou illisible)')),
        );
      }
    }
  }

  Future<void> _deleteMedia(MediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce média ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _mediaService.delete(item.id);
    await _load();
  }

  void _openViewer(MediaItem item) {
    if (item.isVideo) {
      openBytesInNewTab(item.bytes, item.mimeType);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: Image.memory(item.bytes)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Médias', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: _adding ? null : _addMedia,
              icon: _adding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_adding ? 'Ajout $_addProgress/$_addTotal…' : 'Ajouter'),
            ),
          ],
        ),
        if (_adding) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _addTotal > 0 ? _addProgress / _addTotal : null,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucun média pour ce vol.'),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return _MediaTile(
                item: item,
                onTap: () => _openViewer(item),
                onDelete: () => _deleteMedia(item),
              );
            },
          ),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MediaTile({required this.item, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.isVideo
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      item.thumbnail != null
                          ? Image.memory(item.thumbnail!, fit: BoxFit.cover)
                          : Container(color: Colors.black87),
                      const Center(
                        child: Icon(Icons.play_circle_outline,
                            color: Colors.white, size: 32),
                      ),
                    ],
                  )
                : Image.memory(item.bytes, fit: BoxFit.cover),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
