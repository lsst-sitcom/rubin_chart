import 'package:flutter/widgets.dart';

/// The location on the tick label where it attaches to the plot.
/// For cartesian plots, ticks on the x-axis attach to [TickOrientation.topCenter]
enum TickOrientation {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// A tick label on a plot axis.
class TickLabel {
  final String label;
  final TextPainter painter;
  final TickOrientation orientation;
  final double axisPosition;

  TickLabel(this.label, this.painter, this.orientation, this.axisPosition);

  static TickLabel fromText({
    required String text,
    required TextStyle style,
    required TickOrientation orientation,
    required double position,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    TextSpan textSpan = TextSpan(text: text, style: style);
    TextPainter painter = TextPainter(
      text: textSpan,
      maxLines: 1,
      textDirection: textDirection,
    )..layout();

    return TickLabel(text, painter, orientation, position);
  }

  Size get size => painter.size;

  void paint(Canvas canvas, [Offset offset = Offset.zero]) {
    offset += Offset(size.width / 2, size.height / 2);
    if (orientation == TickOrientation.topLeft) {
      offset += Offset(-size.width / 2, -size.height / 2);
    } else if (orientation == TickOrientation.topCenter) {
      offset += Offset(0, -size.height / 2);
    } else if (orientation == TickOrientation.topRight) {
      offset += Offset(size.width / 2, -size.height / 2);
    } else if (orientation == TickOrientation.centerLeft) {
      offset += Offset(-size.width / 2, 0);
    } else if (orientation == TickOrientation.centerRight) {
      offset += Offset(size.width / 2, 0);
    } else if (orientation == TickOrientation.bottomLeft) {
      offset += Offset(-size.width / 2, size.height / 2);
    } else if (orientation == TickOrientation.bottomCenter) {
      offset += Offset(0, size.height / 2);
    } else if (orientation == TickOrientation.bottomRight) {
      offset += Offset(size.width / 2, size.height / 2);
    } else {
      throw Exception("Invalid TickPosition");
    }
    painter.paint(canvas, offset);
  }

  /// Rescale the label by a factor.
  /// This is usually done when labels are too large to fit between tick marks.
  TickLabel rescaled(double scaleFactor) => TickLabel.fromText(
        text: label,
        style: painter.text!.style!.copyWith(fontSize: painter.text!.style!.fontSize! * scaleFactor),
        orientation: orientation,
        position: axisPosition,
      );
}

class TickLabelPainter extends CustomPainter {
  final List<TickLabel> labels;

  const TickLabelPainter({required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    for (TickLabel label in labels) {
      label.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(TickLabelPainter oldDelegate) {
    return labels != oldDelegate.labels;
  }
}
