import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shuttr/app/theme.dart';

/// Whether [error] means the user hasn't allowed the camera.
bool isCameraPermissionError(Object error) =>
    error is CameraException &&
    (error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt' ||
        error.code == 'CameraAccessRestricted');

/// Shown in the photo area when the camera permission is missing: says why,
/// then offers to retry (re-prompts if it can) or open the app's settings.
class CameraPermissionView extends StatelessWidget {
  const new({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.stage,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'CAMERA\nOFF',
              textAlign: TextAlign.center,
              style: Typo.display.copyWith(color: Palette.cream),
            ),
            const SizedBox(height: 16),
            Text(
              'Shuttr needs the camera to take photos. Allow it in Settings, '
              'then come back.',
              textAlign: TextAlign.center,
              style: Typo.body.copyWith(color: Palette.cream),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _LightButton(label: 'TRY AGAIN', onTap: onRetry),
                const _LightButton(
                  label: 'OPEN SETTINGS',
                  onTap: openAppSettings,
                  solid: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LightButton extends StatelessWidget {
  const new({required this.label, required this.onTap, this.solid = false});

  final String label;
  final VoidCallback onTap;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: solid ? Palette.cream : null,
          border: Border.all(color: Palette.cream),
        ),
        child: Text(
          label,
          style: Typo.label.copyWith(
            color: solid ? Palette.stage : Palette.cream,
          ),
        ),
      ),
    );
  }
}
