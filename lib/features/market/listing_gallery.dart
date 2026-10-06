import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/config/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../account/data/account_actions.dart';
import '../account/presentation/account_sheets.dart';
import '../tabs/data/tabs_data.dart';

/// Supplier listing photos (website js/catalog.js): the photo card in the
/// marketplace grid, the swipeable gallery on a listing, the full-screen
/// viewer, and the supplier's photo manager. Photos live in the public
/// listing-images bucket; a listing keeps up to [maxListingPhotos].

const maxListingPhotos = 6;

List<String> listingImages(Json i) => [for (final u in (i['images'] ?? i['image_urls'] ?? const []) as List) if ('$u'.isNotEmpty) '$u'];

Widget _photo(String url, {BoxFit fit = BoxFit.cover}) => Image.network(
  url,
  fit: fit,
  errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF161616)),
  loadingBuilder: (c, w, p) => p == null ? w : const ColoredBox(color: Color(0xFF161616)),
);

Widget _placeholder(bool equipment, double size) => DecoratedBox(
  decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.2), radius: .8, colors: [Color(0xFF262626), Color(0xFF121212)])),
  child: Center(child: Icon(equipment ? Icons.construction_outlined : Icons.inventory_2_outlined, size: size, color: const Color(0xFF5C5C5C))),
);

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.label, {this.green = false});
  final IconData icon;
  final String label;
  final bool green;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: green ? const Color(0xE634D399) : const Color(0x8C000000), borderRadius: BorderRadius.circular(99)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: green ? const Color(0xFF04210F) : Colors.white),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: green ? const Color(0xFF04210F) : Colors.white)),
    ]),
  );
}

/// A marketplace tile: square cover photo, photo count, verified badge, name, price and supplier.
class ListingCard extends StatelessWidget {
  const ListingCard({required this.item, required this.equipment, required this.price, required this.per, required this.onTap, super.key});
  final Json item;
  final bool equipment;
  final String price, per;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imgs = listingImages(item);
    final place = '${item['town'] ?? item['region'] ?? ''}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1FFFFFFF), Color(0x08FFFFFF), Color(0x730E0E0E)], stops: [0, .55, 1]),
            border: Border.all(color: const Color(0x33FFFFFF), width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(fit: StackFit.expand, children: [
                if (imgs.isEmpty) _placeholder(equipment, 34) else _photo(imgs.first),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment(0, .1), end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x73000000)]))),
                if (item['verified'] == true) const Positioned(left: 8, top: 8, child: _Badge(Icons.verified_outlined, 'Verified', green: true)),
                if (imgs.length > 1) Positioned(right: 8, bottom: 8, child: _Badge(Icons.photo_library_outlined, '${imgs.length}')),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${item['name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: price),
                    if (per.isNotEmpty) TextSpan(text: per, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFBDBDBD))),
                  ]),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -.2),
                ),
                const SizedBox(height: 2),
                Text('${item['business'] ?? ''}${place.isEmpty ? '' : ' · $place'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The swipeable gallery at the top of a listing: count, dots and thumbnails; tap for full screen.
class ListingGallery extends StatefulWidget {
  const ListingGallery({required this.images, required this.equipment, required this.title, super.key});
  final List<String> images;
  final bool equipment;
  final String title;
  @override
  State<ListingGallery> createState() => _ListingGalleryState();
}

class _ListingGalleryState extends State<ListingGallery> {
  final _pc = PageController();
  var _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    if (imgs.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(fit: StackFit.expand, children: [
            _placeholder(widget.equipment, 48),
            const Align(alignment: Alignment(0, .45), child: Text('No photos yet', style: TextStyle(fontSize: 12.5, color: AppColors.muted))),
          ]),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(children: [
            PageView.builder(
              controller: _pc,
              itemCount: imgs.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => openPhotoViewer(context, imgs, i, widget.title),
                child: Semantics(label: 'Photo ${i + 1} of ${imgs.length}', button: true, child: _photo(imgs[i])),
              ),
            ),
            if (imgs.length > 1) ...[
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(99)),
                  child: Text('${_i + 1} / ${imgs.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var k = 0; k < imgs.length; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: k == _i ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(color: k == _i ? Colors.white : const Color(0x73FFFFFF), borderRadius: BorderRadius.circular(99)),
                    ),
                ]),
              ),
            ],
          ]),
        ),
      ),
      if (imgs.length > 1) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imgs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, k) => GestureDetector(
              onTap: () => _pc.animateToPage(k, duration: const Duration(milliseconds: 260), curve: Curves.easeOut),
              child: Opacity(
                opacity: k == _i ? 1 : .6,
                child: Container(
                  width: 56,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: k == _i ? Colors.white : Colors.transparent, width: 2)),
                  child: _photo(imgs[k]),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Full-screen photos with pinch to zoom and swipe between them.
Future<void> openPhotoViewer(BuildContext context, List<String> images, int start, String title) => Navigator.of(context).push(
  PageRouteBuilder<void>(
    opaque: true,
    barrierColor: Colors.black,
    pageBuilder: (_, _, _) => _PhotoViewer(images: images, start: start, title: title),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ),
);

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.images, required this.start, required this.title});
  final List<String> images;
  final int start;
  final String title;
  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _pc = PageController(initialPage: widget.start);
  late var _i = widget.start;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(children: [
            Expanded(child: Text('${_i + 1} / ${widget.images.length}', style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: 'Close',
              style: IconButton.styleFrom(backgroundColor: const Color(0x14FFFFFF), side: const BorderSide(color: Color(0x40FFFFFF))),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ]),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pc,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (context, i) => InteractiveViewer(maxScale: 4, child: Center(child: Semantics(label: widget.title, image: true, child: _photo(widget.images[i], fit: BoxFit.contain)))),
          ),
        ),
      ]),
    ),
  );
}

/// The supplier's photo manager for one listing: cover first, remove, make cover, add up to the limit.
class ListingPhotosSheet extends StatefulWidget {
  const ListingPhotosSheet({required this.table, required this.id, required this.initial, required this.onChanged, super.key});
  final String table, id;
  final List<String> initial;
  final VoidCallback onChanged;
  @override
  State<ListingPhotosSheet> createState() => _ListingPhotosSheetState();
}

class _ListingPhotosSheetState extends State<ListingPhotosSheet> {
  late var _imgs = [...widget.initial];
  var _busy = false;

  Future<void> _save(List<String> next, String ok) async {
    setState(() => _busy = true);
    try {
      final c = SupabaseConfig.client!;
      await c.from(widget.table).update({'image_urls': next}).eq('id', widget.id).eq('business_id', c.auth.currentUser!.id);
      setState(() => _imgs = next);
      widget.onChanged();
      if (mounted) toast(context, ok);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _add() async {
    final room = maxListingPhotos - _imgs.length;
    if (room <= 0) return;
    final picked = (await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'])).take(room).toList();
    if (picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final urls = await uploadListingPhotos([for (final f in picked) (await f.readAsBytes(), f.name)]);
      await _save([..._imgs, ...urls], '${urls.length} photo${urls.length == 1 ? '' : 's'} added.');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
    const Text('Buyers see these on your listing, first photo first. Clear, well-lit photos from a few angles sell faster. Up to $maxListingPhotos.', style: TextStyle(fontSize: 13.5, height: 1.45)),
    const SizedBox(height: 12),
    LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 16) / 3;
        Widget tile(Widget child) => SizedBox(width: w, height: w, child: child);
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (n, u) in _imgs.indexed)
            tile(
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(fit: StackFit.expand, children: [
                  _photo(u),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Material(
                      color: const Color(0xA6000000),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _busy ? null : () => _save([for (final (k, x) in _imgs.indexed) if (k != n) x], 'Photo removed.'),
                        child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.close_rounded, size: 16, semanticLabel: 'Remove photo')),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: n == 0
                        ? Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)), child: const Text('Cover', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.black)))
                        : GestureDetector(
                            onTap: _busy ? null : () => _save([u, for (final (k, x) in _imgs.indexed) if (k != n) x], 'Cover photo set.'),
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xA6000000), borderRadius: BorderRadius.circular(99)), child: const Text('Make cover', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                          ),
                  ),
                ]),
              ),
            ),
          if (_imgs.length < maxListingPhotos)
            tile(
              Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x4DFFFFFF))),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _busy ? null : _add,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (_busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) else const Icon(Icons.add_rounded),
                    const SizedBox(height: 4),
                    const Text('Add photos', style: TextStyle(fontSize: 11.5, color: Color(0xFFBDBDBD))),
                  ]),
                ),
              ),
            ),
        ]);
      },
    ),
  ]);
}

/// Uploads listing photos to listing-images and returns their public links.
Future<List<String>> uploadListingPhotos(List<(Uint8List, String)> files) async {
  final a = AccountActions(), urls = <String>[];
  for (final (i, (bytes, name)) in files.take(maxListingPhotos).indexed) {
    final path = await a.upload('listing-images', bytes, name, 'item-$i');
    urls.add(a.publicUrl('listing-images', path));
  }
  return urls;
}
