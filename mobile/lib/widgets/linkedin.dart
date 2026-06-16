import 'package:cv_exec_feed/theme.dart';
import 'package:flutter/material.dart';

/// Shared LinkedIn-style component set. Every screen composes these so the app
/// uses one consistent component vocabulary (avatars, pill buttons, cards,
/// filter pills, search field, entity tiles, section headers, action buttons).

/// Circular avatar with initials and a deterministic muted background,
/// mirroring LinkedIn's initial avatars. Optional ring decoration.
class LiAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool ring;
  final bool muted;

  const LiAvatar({
    super.key,
    required this.initials,
    this.size = 48,
    this.ring = false,
    this.muted = false,
  });

  // Muted avatar backgrounds — first palette uses Kifiya primary.
  static const _palettes = <List<Color>>[
    [Color(0xFF02404F), Color(0xFF013A47)],
    [Color(0xFF0E7C7B), Color(0xFF0A5C5B)],
    [Color(0xFF386FA4), Color(0xFF2A5580)],
    [Color(0xFF4A6741), Color(0xFF3A5233)],
    [Color(0xFF5E5A80), Color(0xFF46426A)],
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget avatar;
    if (muted) {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.brightness == Brightness.light
              ? const Color(0xFFE2E8F0)
              : scheme.surfaceContainerHighest,
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
          ),
        ),
      );
    } else {
      final code = initials.isEmpty ? 65 : initials.codeUnitAt(0);
      final palette = _palettes[code % _palettes.length];
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: palette,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36,
          ),
        ),
      );
    }
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
      child: avatar,
    );
  }
}

enum LiButtonVariant { primary, secondary, tertiary }

/// LinkedIn pill button — filled (primary), outlined (secondary), or text
/// (tertiary). Optional leading icon.
class LiButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final LiButtonVariant variant;
  final bool expand;
  final Color? color;

  const LiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = LiButtonVariant.primary,
    this.expand = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.blue;
    final child = icon != null
        ? _iconChild()
        : Text(label, overflow: TextOverflow.ellipsis);

    Widget button;
    switch (variant) {
      case LiButtonVariant.primary:
        button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(backgroundColor: c),
          child: child,
        );
        break;
      case LiButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: c,
            side: BorderSide(color: c, width: 1.4),
          ),
          child: child,
        );
        break;
      case LiButtonVariant.tertiary:
        button = TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: c,
            shape: const StadiumBorder(),
          ),
          child: child,
        );
        break;
    }
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _iconChild() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      );
}

/// White rounded surface — the LinkedIn module/card container.
class LiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const LiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Horizontal scrollable filter pills (LinkedIn "Recent / Top" style sort row).
class LiFilterBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  const LiFilterBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => LiFilterChip(
          label: labels[i],
          selected: i == selectedIndex,
          onTap: () => onSelected(i),
        ),
      ),
    );
  }
}

class LiFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  const LiFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? AppTheme.blue;
    final fg = selected ? Colors.white : scheme.onSurface;
    final bg = selected ? accent : scheme.surface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accent
                  : scheme.outlineVariant.withValues(alpha: 0.9),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill button that opens a dropdown menu — a LinkedIn-style "Sort / Filter"
/// control. Highlights when a non-default option is selected.
class LiDropdownButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const LiDropdownButton({
    super.key,
    required this.label,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.icon = Icons.tune_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = selectedIndex > 0;
    final fg = active ? scheme.onPrimary : scheme.onSurface;
    final bg = active ? AppTheme.blue : scheme.surface;
    return PopupMenuButton<int>(
      tooltip: 'Filter',
      offset: const Offset(0, 44),
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(
                  i == selectedIndex
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: i == selectedIndex
                      ? AppTheme.blue
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(options[i],
                    style: TextStyle(
                      fontWeight:
                          i == selectedIndex ? FontWeight.w700 : FontWeight.w500,
                    )),
              ],
            ),
          ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppTheme.blue
                : scheme.outlineVariant.withValues(alpha: 0.9),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
            Text(
              active ? options[selectedIndex] : label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: fg,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 20, color: fg),
          ],
        ),
      ),
    );
  }
}

/// Rounded gray search input (the LinkedIn top-bar search pill).
class LiSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const LiSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hint = 'Search',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = controller.text.isNotEmpty;
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: AppTheme.bg,
          prefixIcon:
              Icon(Icons.search_rounded, size: 20, color: scheme.onSurfaceVariant),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.blue, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// Section header: bold title + optional "See all" trailing action.
class LiSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const LiSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          LiButton(
            label: actionLabel!,
            onPressed: onAction,
            variant: LiButtonVariant.tertiary,
          ),
      ],
    );
  }
}

/// Entity row: avatar + title + subtitle + optional trailing widget.
/// Used for connection-style lists, leaderboard rows, and citations.
class LiEntityTile extends StatelessWidget {
  final String initials;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leadingOverride;
  final VoidCallback? onTap;
  final double avatarSize;

  const LiEntityTile({
    super.key,
    required this.initials,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leadingOverride,
    this.onTap,
    this.avatarSize = 44,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            leadingOverride ?? LiAvatar(initials: initials, size: avatarSize),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Single action in a LinkedIn action bar (icon + label, fills when active).
class LiActionButton extends StatelessWidget {
  final IconData filledIcon;
  final IconData outlineIcon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const LiActionButton({
    super.key,
    required this.filledIcon,
    required this.outlineIcon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = active ? color : scheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: active ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                child:
                    Icon(active ? filledIcon : outlineIcon, size: 20, color: fg),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small tinted pill badge (icon + label) — LinkedIn "Promoted / Top match /
/// streak / status" tag. Tinted background, colored label, full pill shape.
class LiTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;

  const LiTag({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left-accent quote / evidence card — LinkedIn-style cited snippet with a
/// colored leading rule, 8px radius, optional tap. Used for evidence and chat
/// citations so all cited content shares one look.
class LiQuoteCard extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final Color? background;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const LiQuoteCard({
    super.key,
    required this.child,
    this.accent,
    this.background,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = accent ?? scheme.primary;
    final bg =
        background ?? scheme.surfaceContainerHighest.withValues(alpha: 0.4);
    return Padding(
      padding: margin,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: a, width: 3)),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Round ghost icon button used in the app bar (notifications, messaging).
class LiIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool showBadge;

  const LiIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: scheme.onSurface),
          if (showBadge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
