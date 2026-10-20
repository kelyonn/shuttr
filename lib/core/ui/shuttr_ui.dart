import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shuttr/app/theme.dart';

/// Small building blocks of the visual system: hard black rules, square
/// tags, tap cells with an inverted "on" state, the film-plate frame around
/// a photo, and the paper page header. No pills, no shadows — everything is
/// a rectangle with a 1px ink edge.

const _rule = BorderSide(color: Palette.ink);

/// A tappable rectangle that fills with ink when [on] (or while
/// pressed).
class TapCell extends StatefulWidget {
  const new({
    required this.child,
    required this.onTap,
    this.on = false,
    this.height,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.centerLeft,
    this.border,
    this.semanticLabel,
    this.background,
    this.onLongPress,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool on;
  final double? height;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;
  final Border? border;
  final String? semanticLabel;
  final Color? background;

  @override
  State<TapCell> createState() => _TapCellState();
}

class _TapCellState extends State<TapCell> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final inverted = widget.on || _down;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                unawaited(HapticFeedback.selectionClick());
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        // Ink and paper swap over a beat instead of snapping, so presses
        // and selections feel physical.
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: inverted ? 1 : 0),
          duration: Duration(milliseconds: inverted ? 60 : 160),
          curve: Curves.easeOut,
          builder: (context, t, child) {
            final fg = Color.lerp(Palette.ink, Palette.paper, t)!;
            return DefaultTextStyle.merge(
              style: TextStyle(color: fg),
              child: IconTheme(
                data: IconThemeData(color: fg),
                child: Container(
                  // A minimum, not a fixed height, so large text sizes grow
                  // the cell instead of clipping it.
                  constraints: widget.height == null
                      ? null
                      : BoxConstraints(minHeight: widget.height!),
                  padding: widget.padding,
                  alignment: widget.alignment,
                  decoration: BoxDecoration(
                    color: Color.lerp(widget.background, Palette.ink, t),
                    border: widget.border,
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Bottom-edge hairline used between rows.
const Border bottomRule = Border(bottom: _rule);
const BoxDecoration topRule = BoxDecoration(border: Border(top: _rule));

/// The 4px black rule between the photo plate and the dashboard.
class HeavyRule extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 4, child: ColoredBox(color: Palette.ink));
}

/// Square status tag: outlined (FREE) or solid (PREVIEW ONLY).
class StatusTag extends StatelessWidget {
  const new(this.text, {this.solid = false, super.key});

  final String text;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 3),
      decoration: BoxDecoration(
        color: solid ? Palette.ink : null,
        border: Border.all(color: Palette.ink),
      ),
      child: Text(
        text,
        style: Typo.micro.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: solid ? Palette.paper : Palette.ink,
        ),
      ),
    );
  }
}

/// The photograph's frame: a thin black running head (`SHUTTR · NO.018 ·
/// REAR`), the photo itself, and cream sprocket holes down the right edge.
/// No type is ever laid over the photograph itself.
class FilmPlate extends StatelessWidget {
  const new({
    required this.frameLabel,
    required this.rightLabel,
    required this.photo,
    super.key,
  });

  /// e.g. `NO.018`.
  final String frameLabel;

  /// e.g. `REAR`, `REAR · FLASH`, `REVIEW`.
  final String rightLabel;
  final Widget photo;

  @override
  Widget build(BuildContext context) {
    const headStyle = TextStyle(
      fontFamily: 'IBMPlexMono',
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.76,
      height: 1,
      color: Palette.cream,
    );
    return ColoredBox(
      color: Palette.stage,
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x24F3EBDD)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SHUTTR',
                        style: TextStyle(
                          fontFamily: 'IBMPlexMono',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.76,
                          color: Palette.cream,
                        ),
                      ),
                      Text(frameLabel, style: headStyle),
                      Text(rightLabel, style: headStyle),
                    ],
                  ),
                ),
                Expanded(child: ClipRect(child: photo)),
              ],
            ),
          ),
          const _Sprockets(),
        ],
      ),
    );
  }
}

class _Sprockets extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      padding: const EdgeInsets.only(top: 32),
      color: Palette.stage,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < 8; i++)
            Container(
              width: 8,
              height: 12,
              decoration: BoxDecoration(
                color: Palette.cream,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Orange date stamp laid on the photo (only when the stamp setting is on).
class LiveStamp extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 14,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'IBMPlexMono',
          fontSize: 10,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.6,
          height: 1,
          color: Color(0xB8E25A1C),
          shadows: [Shadow(color: Color(0x4DE25A1C), blurRadius: 3)],
        ),
      ),
    );
  }
}

/// Top of the paper pages (Roll, Settings): BACK, a huge Anton title, and a
/// one-line meta.
class PageHeader extends StatelessWidget {
  const new({
    required this.title,
    required this.meta,
    required this.onBack,
    super.key,
  });

  final String title;
  final String meta;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TapCell(
            onTap: onBack,
            height: 40,
            semanticLabel: 'Back',
            child: const Text('← BACK', style: Typo.label),
          ),
          const SizedBox(height: 4),
          Text(title, style: Typo.display),
          const SizedBox(height: 10),
          Text(meta, style: Typo.label.copyWith(letterSpacing: 1.3)),
        ],
      ),
    );
  }
}

/// Black group band: `01 / CAPTURE`.
class GroupBand extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      color: Palette.ink,
      child: Text(
        text,
        style: Typo.micro.copyWith(color: Palette.paper, letterSpacing: 2),
      ),
    );
  }
}

/// The camera/review page skeleton: the photo plate on top, the paper panel
/// under it (heavy rule between), and [footer] (the action row) pinned at the
/// bottom.
class PlateLayout extends StatelessWidget {
  const new({
    required this.plate,
    required this.panel,
    required this.paper,
    this.footer,
    this.fillPanel = false,
    super.key,
  });

  final Widget plate;
  final Widget panel;
  final Widget? footer;
  final Color paper;

  /// Kept for callers that lay their own panel out; the portrait panel is
  /// always its natural height.
  final bool fillPanel;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Column(
      children: [
        ColoredBox(
          color: Palette.stage,
          child: SizedBox(height: media.padding.top, width: double.infinity),
        ),
        Expanded(child: plate),
        const HeavyRule(),
        ColoredBox(
          color: paper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              panel,
              ?footer,
              SizedBox(height: media.padding.bottom),
            ],
          ),
        ),
      ],
    );
  }
}

/// How many quarter turns the phone is held from upright (0 upright, 1 left
/// side down...), provided by the camera so labels can face the user.
class PhoneTurn extends InheritedWidget {
  const new({required this.quarterTurns, required super.child, super.key});

  /// Clockwise quarter turns to apply to labels so they read upright.
  final int quarterTurns;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhoneTurn>()?.quarterTurns ??
      0;

  @override
  bool updateShouldNotify(PhoneTurn old) => old.quarterTurns != quarterTurns;
}

/// Turns [child] to face the user when the phone is held sideways. Layout
/// stays put; only the label spins.
class Turned extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final q = PhoneTurn.of(context);
    return AnimatedRotation(
      turns: q / 4,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}
