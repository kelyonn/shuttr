import 'package:flutter/material.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';

/// The mode dial (S16): picks which [LookSpec] the live preview and next
/// capture use. Paid looks show a lock badge but are fully selectable and
/// previewable — gating happens at save, once M6 wires up entitlements
/// (CLAUDE.md rule 3).
class LookModeDial extends StatelessWidget {
  const new({
    required this.selected,
    required this.accentColor,
    required this.onSelect,
    super.key,
  });

  final LookSpec selected;
  final Color accentColor;
  final ValueChanged<LookSpec> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: looks.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final look = looks[index];
          return _LookChip(
            look: look,
            selected: look.id == selected.id,
            accentColor: accentColor,
            onTap: () => onSelect(look),
          );
        },
      ),
    );
  }
}

class _LookChip extends StatelessWidget {
  const new({
    required this.look,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final LookSpec look;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.black45,
          borderRadius: BorderRadius.circular(18),
          border: selected ? null : Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!look.isFree) ...[
              Icon(
                Icons.lock_outline,
                size: 14,
                color: selected ? Colors.black54 : Colors.white70,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              look.displayName,
              style: TextStyle(
                color: selected ? Colors.black87 : Colors.white,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
