import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/extensions.dart';

enum SelfViewCorner { topLeft, topRight, bottomLeft, bottomRight }

class DraggableSelfView extends StatefulWidget {
  const DraggableSelfView({
    super.key,
    required this.child,
    required this.corner,
    required this.bounds,
    required this.onCornerChanged,
    this.tileSize = const Size(110, 150),
    this.onTap,
  });

  final Widget child;
  final SelfViewCorner corner;
  final Rect bounds;
  final ValueChanged<SelfViewCorner> onCornerChanged;
  final Size tileSize;
  final VoidCallback? onTap;

  @override
  State<DraggableSelfView> createState() => _DraggableSelfViewState();
}

class _DraggableSelfViewState extends State<DraggableSelfView> {
  // region: STATE
  Offset? _dragOffset;
  bool _isDragging = false;
  // endregion

  // region: GEOMETRY
  Size get _effectiveSize {
    final maxWidth = math.max(64.0, widget.bounds.width);
    final maxHeight = math.max(64.0, widget.bounds.height);
    return Size(
      math.min(widget.tileSize.width, maxWidth),
      math.min(widget.tileSize.height, maxHeight),
    );
  }

  Offset _clampOffset(Offset raw, Size size) {
    final minX = widget.bounds.left;
    final maxX = math.max(minX, widget.bounds.right - size.width);
    final minY = widget.bounds.top;
    final maxY = math.max(minY, widget.bounds.bottom - size.height);
    return Offset(
      raw.dx.clamp(minX, maxX),
      raw.dy.clamp(minY, maxY),
    );
  }

  Offset _offsetForCorner(SelfViewCorner corner, Size size) {
    final minX = widget.bounds.left;
    final maxX = math.max(minX, widget.bounds.right - size.width);
    final minY = widget.bounds.top;
    final maxY = math.max(minY, widget.bounds.bottom - size.height);

    return switch (corner) {
      SelfViewCorner.topLeft => Offset(minX, minY),
      SelfViewCorner.topRight => Offset(maxX, minY),
      SelfViewCorner.bottomLeft => Offset(minX, maxY),
      SelfViewCorner.bottomRight => Offset(maxX, maxY),
    };
  }

  SelfViewCorner _nearestCorner(
    Offset offset,
    Offset velocity,
    Size size,
  ) {
    final projected = Offset(
      offset.dx + velocity.dx * 0.06,
      offset.dy + velocity.dy * 0.06,
    );
    final tileCenter = Offset(
      projected.dx + size.width / 2,
      projected.dy + size.height / 2,
    );
    final boundsCenter = widget.bounds.center;
    final isLeft = tileCenter.dx < boundsCenter.dx;
    final isTop = tileCenter.dy < boundsCenter.dy;

    if (isTop && isLeft) {
      return SelfViewCorner.topLeft;
    }
    if (isTop) {
      return SelfViewCorner.topRight;
    }
    if (isLeft) {
      return SelfViewCorner.bottomLeft;
    }
    return SelfViewCorner.bottomRight;
  }
  // endregion

  // region: BUILD
  @override
  Widget build(BuildContext context) {
    final size = _effectiveSize;
    final snappedOffset = _offsetForCorner(widget.corner, size);
    final currentOffset = _isDragging && _dragOffset != null
        ? _clampOffset(_dragOffset!, size)
        : snappedOffset;
    final colors = context.colors;
    final colorScheme = context.colorScheme;

    return AnimatedPositioned(
      duration: _isDragging
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: currentOffset.dx,
      top: currentOffset.dy,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
            _dragOffset = snappedOffset;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            final base = _dragOffset ?? snappedOffset;
            _dragOffset = _clampOffset(base + details.delta, size);
          });
        },
        onPanEnd: (details) {
          final releaseOffset = _dragOffset ?? snappedOffset;
          final targetCorner = _nearestCorner(
            releaseOffset,
            details.velocity.pixelsPerSecond,
            size,
          );
          setState(() {
            _isDragging = false;
            _dragOffset = null;
          });
          widget.onCornerChanged(targetCorner);
        },
        onPanCancel: () {
          setState(() {
            _isDragging = false;
            _dragOffset = null;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outline.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.scrim.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.child,
        ),
      ),
    );
  }
  // endregion
}
