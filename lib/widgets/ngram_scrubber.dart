import "package:material_ui/material_ui.dart";

import "../ngram.dart";
import "../theme.dart";

/// Left-edge page rail: n-gram labels for letter pages.
///
/// Large letters (≈max slots): marks stretch top-to-bottom.
/// Medium letters (fewer marks): same slot pitch as a full rail, block
/// centered on the vertical midline. Small letters (<2 marks) → hidden.
class NgramScrubber extends StatelessWidget {
  const NgramScrubber({
    super.key,
    required this.anchors,
    required this.activeAnchor,
    required this.onSelectAnchor,
    this.width = 64,
  });

  final List<NgramAnchor> anchors;
  final int activeAnchor;
  final ValueChanged<int> onSelectAnchor;
  final double width;

  static const _vPad = kNgramRailVerticalPadding / 2;

  @override
  Widget build(BuildContext context) {
    if (anchors.length < 2) return const SizedBox.shrink();
    final active = activeAnchor.clamp(0, anchors.length - 1);

    return SizedBox(
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final inner = (h - _vPad * 2).clamp(1.0, h);
          final maxSlots = maxLetterPagesForRailHeight(h);
          // Pitch of a "full" (large-letter) rail.
          final slotH = inner / maxSlots;
          final packCentered = anchors.length < maxSlots;
          final blockH = anchors.length * slotH;
          final topGap =
              packCentered ? ((inner - blockH) / 2).clamp(0.0, inner) : 0.0;

          int indexAt(Offset local) {
            if (h <= 0) return 0;
            final y = local.dy - _vPad - topGap;
            if (y < 0) return 0;
            if (y >= blockH) return anchors.length - 1;
            return (y / slotH).floor().clamp(0, anchors.length - 1);
          }

          return Material(
            color: const Color(0xFFF1F3F5),
            elevation: 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (d) =>
                  onSelectAnchor(indexAt(d.localPosition)),
              onTapDown: (d) => onSelectAnchor(indexAt(d.localPosition)),
              child: SizedBox(
                width: width,
                height: h,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: _vPad,
                    horizontal: 4,
                  ),
                  child: Column(
                    mainAxisAlignment: packCentered
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      for (var i = 0; i < anchors.length; i++)
                        if (packCentered)
                          SizedBox(
                            height: slotH,
                            child: Center(
                              child: _label(i, (i - active).abs()),
                            ),
                          )
                        else
                          Expanded(
                            child: Center(
                              child: _label(i, (i - active).abs()),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _label(int anchorIndex, int dist) {
    final label = anchors[anchorIndex].label;
    final fontSize = dist == 0
        ? 16.0
        : dist == 1
        ? 14.0
        : 13.0;
    final color = dist == 0
        ? PunzhColors.brandDark
        : dist <= 2
        ? PunzhColors.navbar
        : const Color(0xFF868E96);
    final weight = dist == 0 ? FontWeight.w700 : FontWeight.w600;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.1,
        fontWeight: weight,
        color: color,
      ),
    );
  }
}
