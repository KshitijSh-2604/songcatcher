import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import '../../../utils/responsive.dart';

class ImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const ImageCropDialog({super.key, required this.imageBytes});

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final _cropController = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD4D9E2), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.fw(360, max: 500),
          maxHeight: context.screenHeight * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.crop_rotate, color: Colors.black54),
                  const SizedBox(width: 12),
                  const Text(
                    'Crop Profile Picture',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Cropper Area
            Flexible(
              child: Container(
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.all(16),
                child: Crop(
                  image: widget.imageBytes,
                  controller: _cropController,
                  onCropped: (result) {
                    debugPrint('Cropping finished callback triggered.');
                    if (result is CropSuccess) {
                      debugPrint('Cropped bytes size: ${result.croppedImage.length}');
                      Navigator.pop(context, result.croppedImage);
                    } else {
                      debugPrint('Cropping failed or canceled.');
                      Navigator.pop(context);
                    }
                  },
                  aspectRatio: 1.0,
                  initialRectBuilder: InitialRectBuilder.withBuilder((viewportRect, imageRect) {
                    // Start with a centered square that is 80% of the smallest dimension
                    final side = (imageRect.width < imageRect.height ? imageRect.width : imageRect.height) * 0.8;
                    return Rect.fromCenter(
                      center: imageRect.center,
                      width: side,
                      height: side,
                    );
                  }),
                  interactive: true,
                  maskColor: Colors.white.withOpacity(0.6),
                  baseColor: const Color(0xFFF8FAFC),
                  cornerDotBuilder: (size, edgeAlignment) => const _DotControl(color: Color(0xFF007BFF)),
                ),
              ),
            ),

            const Divider(height: 1),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isCropping
                        ? null
                        : () {
                            debugPrint('Triggering crop...');
                            setState(() => _isCropping = true);
                            _cropController.crop();
                          },
                    child: _isCropping
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Crop & Upload'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotControl extends StatelessWidget {
  final Color color;

  const _DotControl({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
