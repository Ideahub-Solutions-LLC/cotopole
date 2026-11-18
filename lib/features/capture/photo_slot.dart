import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';

/// Asks camera vs. library, then returns the picked file path.
Future<String?> pickPhoto(BuildContext context, {required bool selfie}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selfie ? 'Client photo' : 'Business card', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              title: Text(selfie ? 'Take a photo' : 'Photograph the card'),
              subtitle: Text(selfie ? 'Ask for consent first' : 'Fill the frame, avoid glare'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.teal),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2400,
      maxHeight: 2400,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
    );
    return file?.path;
  } on PlatformException catch (e) {
    if (context.mounted) {
      showAppSnack(
        context,
        e.code.contains('access_denied') || e.code.contains('denied')
            ? 'Permission denied — enable ${source == ImageSource.camera ? 'Camera' : 'Photos'} access in Settings.'
            : 'Could not open ${source == ImageSource.camera ? 'the camera' : 'your photos'}.',
        icon: Icons.error_rounded,
        color: AppColors.danger,
      );
    }
    return null;
  }
}

/// The concept's capture slot: an accent-bordered card with a camera orb,
/// title/subtitle and a holographic illustration — or the picked photo.
class PhotoSlot extends StatelessWidget {
  const PhotoSlot({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.illustration,
    required this.onTap,
    this.file,
    this.onClear,
    this.badge,
    this.height = 132,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData illustration;
  final VoidCallback onTap;
  final File? file;
  final VoidCallback? onClear;
  final Widget? badge;
  final double height;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(AppRadii.lg);
    return Semantics(
      button: true,
      label: file == null ? title : '$title — photo added, tap to replace',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        height: height,
        decoration: BoxDecoration(
          borderRadius: br,
          border: Border.all(color: accent.withValues(alpha: file == null ? 0.55 : 0.9), width: 1.3),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.16), AppColors.background.withValues(alpha: 0.6)],
          ),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 24, spreadRadius: -8)],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: br,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: file != null ? _preview() : _empty(context),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          child: _Hologram(icon: illustration, color: accent),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background.withValues(alpha: 0.6),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.photo_camera_outlined, size: 26, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upload Photo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 90),
            ],
          ),
        ),
      ],
    );
  }

  Widget _preview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(file!, fit: BoxFit.cover, cacheWidth: 900),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
            ),
          ),
        ),
        Positioned(
          left: 14,
          bottom: 12,
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: accent, size: 18),
              const SizedBox(width: 6),
              const Text('Tap to retake', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        if (onClear != null)
          Positioned(
            right: 8,
            top: 8,
            child: IconButton.filled(
              tooltip: 'Remove photo',
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onClear,
            ),
          ),
      ],
    );
  }
}

/// Floating, softly glowing illustration standing in for the concept's 3D
/// renders (holographic card / face scan).
class _Hologram extends StatefulWidget {
  const _Hologram({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  State<_Hologram> createState() => _HologramState();
}

class _HologramState extends State<_Hologram> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return SizedBox(
          width: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 14,
                child: Container(
                  width: 70,
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    gradient: RadialGradient(
                      colors: [widget.color.withValues(alpha: 0.65), widget.color.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, -4 - 6 * t),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
                    ..rotateY(-0.35 + 0.15 * t),
                  child: ShaderMask(
                    shaderCallback: (r) => LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, widget.color],
                    ).createShader(r),
                    child: Icon(
                      widget.icon,
                      size: 64,
                      color: Colors.white,
                      shadows: [Shadow(color: widget.color, blurRadius: 18)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
