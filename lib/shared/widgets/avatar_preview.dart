import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

const _avatarSaverChannel = MethodChannel('grow_together/avatar_saver');

Future<void> showAvatarPreview(
  BuildContext context, {
  required String title,
  String? imageUrl,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.text.withValues(alpha: 0.42),
    builder: (_) => _AvatarPreviewDialog(title: title, imageUrl: imageUrl),
  );
}

class _AvatarPreviewDialog extends StatefulWidget {
  const _AvatarPreviewDialog({required this.title, required this.imageUrl});

  final String title;
  final String? imageUrl;

  @override
  State<_AvatarPreviewDialog> createState() => _AvatarPreviewDialogState();
}

class _AvatarPreviewDialogState extends State<_AvatarPreviewDialog> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl?.trim();

    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F9),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.64)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.20),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.section.copyWith(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.72),
                    foregroundColor: AppColors.secondaryText,
                    fixedSize: const Size(38, 38),
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: ClipOval(
                      child: url == null || url.isEmpty
                          ? Image.asset(AppAssets.bearAvatar, fit: BoxFit.cover)
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                    AppAssets.bearAvatar,
                                    fit: BoxFit.cover,
                                  ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _saving ? null : _saveAvatar,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepPink,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.deepPink.withValues(
                  alpha: 0.42,
                ),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_saving ? '保存中...' : '保存到相册'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAvatar() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final imageData = await _loadAvatarBytes(widget.imageUrl);
      await _avatarSaverChannel.invokeMethod<String>('saveAvatar', {
        'bytes': imageData.bytes,
        'filename': _avatarFilename(widget.title, imageData.extension),
        'mimeType': imageData.mimeType,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('头像已保存到相册'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? '保存失败，请稍后再试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存失败，请稍后再试'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

Future<_AvatarBytes> _loadAvatarBytes(String? imageUrl) async {
  final url = imageUrl?.trim();
  if (url == null || url.isEmpty) {
    final data = await rootBundle.load(AppAssets.bearAvatar);
    return _AvatarBytes(
      bytes: data.buffer.asUint8List(),
      mimeType: 'image/png',
      extension: 'png',
    );
  }

  final uri = Uri.parse(url);
  final request = await HttpClient().getUrl(uri);
  final response = await request.close();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw const HttpException('Avatar download failed');
  }

  final bytes = await consolidateHttpClientResponseBytes(response);
  final contentType = response.headers.contentType?.mimeType;
  final mimeType = _safeImageMimeType(contentType, uri.path);
  return _AvatarBytes(
    bytes: bytes,
    mimeType: mimeType,
    extension: _extensionForMimeType(mimeType),
  );
}

String _safeImageMimeType(String? contentType, String path) {
  final normalized = contentType?.toLowerCase();
  if (normalized == 'image/png' ||
      normalized == 'image/webp' ||
      normalized == 'image/jpeg') {
    return normalized!;
  }

  final lowerPath = path.toLowerCase();
  if (lowerPath.endsWith('.png')) return 'image/png';
  if (lowerPath.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

String _extensionForMimeType(String mimeType) {
  return switch (mimeType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
}

String _avatarFilename(String title, String extension) {
  final safeTitle = title
      .replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'grow_together_${safeTitle.isEmpty ? 'avatar' : safeTitle}_$timestamp.$extension';
}

class _AvatarBytes {
  const _AvatarBytes({
    required this.bytes,
    required this.mimeType,
    required this.extension,
  });

  final Uint8List bytes;
  final String mimeType;
  final String extension;
}
