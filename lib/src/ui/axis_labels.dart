import 'package:flutter/widgets.dart';
import 'package:rubin_chart/src/models/axes/ticks.dart';

/// A label on a plot axis.
class AxisLabel {
  final String label;
  final TextPainter painter;
  final Size size;
  final TickOrientation orientation;
  final double axisPosition;

  AxisLabel(this.label, this.painter, this.size, this.orientation, this.axisPosition);

  static AxisLabel fromText({
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

    return AxisLabel(text, painter, painter.size, orientation, position);
  }

  void paint(Canvas canvas, Offset offset) {
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
  AxisLabel rescaled(double scaleFactor) => AxisLabel.fromText(
      text: label,
      style: painter.text!.style!.copyWith(fontSize: painter.text!.style!.fontSize! * scaleFactor),
      orientation: orientation);
}

class AxisLabelPainter extends CustomPainter {
  final List<AxisLabel> labels;

  const AxisLabelPainter({required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    for (AxisLabel label in labels) {
      label.paint(canvas);
    }
  }

  @override
  bool shouldRepaint(AxisLabelPainter oldDelegate) {
    return labels != oldDelegate.labels;
  }
}
