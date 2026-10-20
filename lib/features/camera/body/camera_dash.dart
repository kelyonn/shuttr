import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shuttr/app/theme.dart';
import 'package:shuttr/core/ui/shuttr_ui.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';

/// The big-name / italic-sub pair shown for a camera on the dashboard and
/// review screen (DIGI + '03). Cosmetic only, so it lives with the UI
/// rather than in [LookSpec].
({String name, String sub}) cameraMark(LookSpec look) {
  return switch (look.id) {
    'digi03' => (name: 'DIGI', sub: "'03"),
    'disposable' => (name: 'DISPOSABLE', sub: ''),
    'instant' => (name: 'INSTANT', sub: ''),
    'point_and_shoot_35' => (name: 'P&S', sub: '35'),
    'mono_400' => (name: 'MONO', sub: '400'),
    'cine_800' => (name: 'CINE', sub: '800T'),
    'video_vhs' => (name: 'VHS', sub: ''),
    'video_hi8' => (name: 'HI8', sub: ''),
    'video_minidv' => (name: 'MINIDV', sub: ''),
    'video_digi03' => (name: 'DIGI', sub: "'03"),
    'video_super8' => (name: 'SUPER', sub: '8'),
    'video_flip' => (name: 'FLIP', sub: 'cam'),
    'video_webcam' => (name: 'WEBCAM', sub: "'06"),
    _ => (name: look.displayName.toUpperCase(), sub: ''),
  };
}

/// Short list-cell name; the full name doesn't fit a half-width cell.
String _cellName(LookSpec look) =>
    look.id == 'point_and_shoot_35' ? 'P&S 35' : look.displayName;

/// `CAMERA / 01` (or `VIDEO / 01`) — the camera's position in its picker.
String cameraKicker(LookSpec look, {List<LookSpec>? list}) {
  final all = list ?? looks;
  final n = all.indexWhere((l) => l.id == look.id) + 1;
  final kind = look.id.startsWith('video_') ? 'VIDEO' : 'CAMERA';
  return '$kind / ${n.toString().padLeft(2, '0')}';
}

/// The paper half of the camera screen: kicker, name + shutter, collapsible
/// CAMERAS index, and the four-cell foot (ROLL / FLASH / LENS / INDEX).
class CameraDash extends StatelessWidget {
  const new({
    required this.spec,
    required this.pickerOpen,
    required this.rollCount,
    required this.flashLabel,
    required this.flashOn,
    required this.lensLabel,
    required this.busy,
    required this.onTogglePicker,
    required this.onSelectLook,
    required this.onShutter,
    required this.onRoll,
    required this.onFlash,
    required this.onLens,
    required this.onIndex,
    this.onInfo,
    this.shutterLabel,
    this.footLocked = false,
    this.lookList,
    this.video = false,
    this.recording = false,
    this.onMode,
    this.onCycle,
    this.timerLabel = 'OFF',
    this.onTimer,
    this.latestPhotoPath,
    super.key,
  });

  /// Swipe the camera name left/right: next (+1) or previous (-1) camera.
  final ValueChanged<int>? onCycle;

  /// Self-timer state shown in the foot (`OFF` / `3S`); null [onTimer]
  /// hides the cell.
  final String timerLabel;
  final VoidCallback? onTimer;

  /// Newest kept photo, shown as the gallery thumbnail.
  final String? latestPhotoPath;
  final LookSpec spec;
  final bool pickerOpen;
  final int rollCount;
  final String flashLabel;
  final bool flashOn;
  final String lensLabel;
  final bool busy;
  final VoidCallback onTogglePicker;
  final ValueChanged<LookSpec> onSelectLook;
  final VoidCallback onShutter;
  final VoidCallback onRoll;
  final VoidCallback onFlash;
  final VoidCallback onLens;
  final VoidCallback onIndex;

  /// Overrides the shutter's label (e.g. CANCEL during the self-timer).
  final String? shutterLabel;

  /// Dims and disables the foot row (mid-recording or mid-capture).
  final bool footLocked;

  /// Opens a camera's card (tap the name, or long-press a picker cell).
  final ValueChanged<LookSpec>? onInfo;

  /// The cameras in the picker; defaults to the photo cameras.
  final List<LookSpec>? lookList;

  /// Video mode: the shutter is REC/STOP.
  final bool video;
  final bool recording;

  /// Switches photo ⇄ video; null hides the switch.
  final ValueChanged<bool>? onMode;

  @override
  Widget build(BuildContext context) {
    final mark = cameraMark(spec);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onInfo == null ? null : () => onInfo!(spec),
                      // Swipe the name to flip through the cameras.
                      onHorizontalDragEnd: onCycle == null
                          ? null
                          : (d) {
                              final v = d.primaryVelocity ?? 0;
                              if (v.abs() > 120) onCycle!(v < 0 ? 1 : -1);
                            },
                      child: Semantics(
                        button: onInfo != null,
                        label: 'About ${spec.displayName}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                mark.name,
                                maxLines: 1,
                                style: Typo.display.copyWith(fontSize: 46),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (mark.sub.isNotEmpty) ...[
                                  Text(
                                    mark.sub,
                                    style: Typo.sub.copyWith(fontSize: 24),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (onInfo != null)
                                  const Opacity(
                                    opacity: 0.8,
                                    child: Text('ABOUT ›', style: Typo.micro),
                                  ),
                                if (spec.isLocked) ...[
                                  const SizedBox(width: 8),
                                  const StatusTag('PREVIEW ONLY', solid: true),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (onMode != null)
                    _ModeSwitch(
                      video: video,
                      enabled: !recording && !busy,
                      onMode: onMode!,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // The shutter is the thing you press most: a full-width key
              // right above the thumb.
              _ShutterKey(
                onPressed: busy && !recording ? null : onShutter,
                label:
                    shutterLabel ??
                    (video ? (recording ? 'STOP' : 'REC') : 'SHOOT'),
                live: recording,
                wide: true,
                height: 56,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        _CameraIndex(
          selected: spec,
          open: pickerOpen,
          onToggle: onTogglePicker,
          onSelect: onSelectLook,
          onInfo: onInfo,
          list: lookList ?? looks,
          locked: recording,
        ),
        _Foot(
          rollCount: rollCount,
          flashLabel: flashLabel,
          flashOn: flashOn,
          lensLabel: lensLabel,
          onRoll: onRoll,
          onFlash: onFlash,
          onLens: onLens,
          onIndex: onIndex,
          locked: footLocked,
          timerLabel: timerLabel,
          onTimer: onTimer,
          latestPhotoPath: latestPhotoPath,
        ),
      ],
    );
  }
}

class _ShutterKey extends StatefulWidget {
  const new({
    required this.onPressed,
    this.label = 'SHOOT',
    this.live = false,
    this.wide = false,
    this.height,
  });

  final VoidCallback? onPressed;

  /// Overrides the wide key's height.
  final double? height;
  final String label;

  /// A full-width bar (the sideways panel) instead of the square key.
  final bool wide;

  /// Recording: the key stays red.
  final bool live;

  @override
  State<_ShutterKey> createState() => _ShutterKeyState();
}

class _ShutterKeyState extends State<_ShutterKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final fill = _down || widget.live ? Palette.press : Palette.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        // Presses in like a real key: a small squash, colour easing to red.
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.5,
            duration: const Duration(milliseconds: 160),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: widget.wide ? double.infinity : 60,
              height: widget.wide ? (widget.height ?? 52) : 60,
              color: fill,
              padding: const EdgeInsets.all(4),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Palette.paper.withValues(alpha: 0.5),
                  ),
                ),
                child: Turned(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: Text(
                      widget.label,
                      key: ValueKey(widget.label),
                      style: Typo.micro.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                        color: Palette.paper,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraIndex extends StatelessWidget {
  const new({
    required this.selected,
    required this.open,
    required this.onToggle,
    required this.onSelect,
    required this.list,
    this.onInfo,
    this.locked = false,
  });

  final LookSpec selected;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<LookSpec> onSelect;
  final ValueChanged<LookSpec>? onInfo;
  final List<LookSpec> list;

  /// No switching cameras mid-recording.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: topRule,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TapCell(
            onTap: locked ? null : onToggle,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            border: bottomRule,
            semanticLabel: open ? 'Close cameras' : 'Open cameras',
            child: Row(
              children: [
                Text(
                  list.first.id.startsWith('video_')
                      ? 'CHANGE FORMAT'
                      : 'CHANGE CAMERA',
                  style: Typo.labelBold.copyWith(
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selected.displayName,
                    style: Typo.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(open ? 'CLOSE −' : 'OPEN +', style: Typo.micro),
              ],
            ),
          ),
          // Sideways (fill): two columns scrolling in the panel's remaining
          // height. Upright: two columns, three rows visible, so opening
          // the picker never squeezes the photo; it slides open and shut.
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? LayoutBuilder(
                    builder: (context, constraints) => ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 132),
                      child: _cells(constraints.maxWidth / 2),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _cells(double cellWidth) {
    return SingleChildScrollView(
      child: Wrap(
        children: [
          for (var i = 0; i < list.length; i++)
            SizedBox(
              width: cellWidth,
              child: GestureDetector(
                onLongPress: onInfo == null ? null : () => onInfo!(list[i]),
                child: _PickerCell(
                  index: i,
                  number: i,
                  look: list[i],
                  on: list[i].id == selected.id,
                  onTap: () => onSelect(list[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerCell extends StatelessWidget {
  const new({
    required this.index,
    required this.number,
    required this.look,
    required this.on,
    required this.onTap,
  });

  /// Position in the grid (odd = right column, no right border).
  final int index;

  /// The number shown in the cell.
  final int number;
  final LookSpec look;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapCell(
      onTap: onTap,
      on: on,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      border: Border(
        bottom: const BorderSide(color: Palette.ink),
        right: index.isEven
            ? const BorderSide(color: Palette.ink)
            : BorderSide.none,
      ),
      semanticLabel: look.displayName,
      child: Row(
        children: [
          Text(
            (number + 1).toString().padLeft(2, '0'),
            style: Typo.micro.copyWith(
              color: on ? Palette.paper.withValues(alpha: 0.6) : null,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _cellName(look),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Typo.body.copyWith(
                color: on ? Palette.paper : Palette.ink,
              ),
            ),
          ),
          if (look.isLocked)
            Container(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 1),
              decoration: BoxDecoration(
                border: Border.all(color: on ? Palette.paper : Palette.ink),
              ),
              child: Text(
                'LOCK',
                style: Typo.micro.copyWith(
                  fontSize: 9,
                  color: on ? Palette.paper : Palette.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  const new({
    required this.rollCount,
    required this.flashLabel,
    required this.flashOn,
    required this.lensLabel,
    required this.onRoll,
    required this.onFlash,
    required this.onLens,
    required this.onIndex,
    this.locked = false,
    this.timerLabel = 'OFF',
    this.onTimer,
    this.latestPhotoPath,
  });

  final bool locked;
  final int rollCount;
  final String flashLabel;
  final bool flashOn;
  final String lensLabel;
  final VoidCallback onRoll;
  final VoidCallback onFlash;
  final VoidCallback onLens;
  final VoidCallback onIndex;
  final String timerLabel;
  final VoidCallback? onTimer;
  final String? latestPhotoPath;

  @override
  Widget build(BuildContext context) {
    Widget cell(
      String label,
      Widget value,
      VoidCallback onTap, {
      bool on = false,
      bool first = false,
      bool lockable = true,
      String? semantics,
    }) {
      return Expanded(
        child: TapCell(
          onTap: locked && lockable ? null : onTap,
          on: on,
          height: 48,
          alignment: Alignment.center,
          border: first
              ? null
              : const Border(left: BorderSide(color: Palette.ink)),
          semanticLabel: semantics ?? label,
          child: Turned(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: 0.8,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: Typo.micro),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(height: 18, child: Center(child: value)),
              ],
            ),
          ),
        ),
      );
    }

    Widget text(String v) => Text(
      v,
      maxLines: 1,
      style: Typo.labelBold.copyWith(fontSize: 12, letterSpacing: 0.7),
    );

    final path = latestPhotoPath;
    final thumb = path == null
        ? const Icon(Icons.photo_library_outlined, size: 16)
        : SizedBox(
            width: 18,
            height: 18,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 64,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.photo_library_outlined, size: 16),
            ),
          );

    final roll = cell(
      'GALLERY',
      thumb,
      onRoll,
      first: true,
      semantics: 'Gallery, $rollCount photos',
    );
    final flash = cell(
      'FLASH',
      text(flashLabel),
      onFlash,
      on: flashOn,
      lockable: false,
      semantics: 'Flash $flashLabel',
    );
    final timer = onTimer == null
        ? null
        : cell(
            'TIMER',
            text(timerLabel),
            onTimer!,
            on: timerLabel != 'OFF',
            semantics: 'Self-timer $timerLabel',
          );
    final lens = cell(
      'LENS',
      text(lensLabel),
      onLens,
      semantics: 'Lens $lensLabel, tap to switch',
    );
    final settings = cell(
      'SETTINGS',
      const Icon(Icons.tune, size: 16),
      onIndex,
    );
    return Container(
      decoration: topRule,
      child: Row(children: [roll, flash, ?timer, lens, settings]),
    );
  }
}

/// PHOTO | VIDEO, two cells big enough for a thumb.
class _ModeSwitch extends StatelessWidget {
  const new({required this.video, required this.enabled, required this.onMode});

  final bool video;
  final bool enabled;
  final ValueChanged<bool> onMode;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, {required bool on, required bool value}) {
      return TapCell(
        onTap: enabled && !on ? () => onMode(value) : null,
        on: on,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        semanticLabel: label,
        child: Turned(
          child: Text(label, style: Typo.label.copyWith(letterSpacing: 1.2)),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: Palette.ink)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          cell('PHOTO', on: !video, value: false),
          cell('VIDEO', on: video, value: true),
        ],
      ),
    );
  }
}
