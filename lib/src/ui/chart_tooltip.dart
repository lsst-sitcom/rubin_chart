/// This file is part of the rubin_chart package.
///
/// Developed for the LSST Data Management System.
/// This product includes software developed by the LSST Project
/// (https://www.lsst.org).
/// See the COPYRIGHT file at the top-level directory of this distribution
/// for details of code ownership.
///
/// This program is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, either version 3 of the License, or
/// (at your option) any later version.
///
/// This program is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'dart:async';

/// Manager for chart tooltips that handles showing/hiding with proper cleanup.
class ChartTooltipManager {
  OverlayEntry? _hoverOverlay;
  Timer? _hoverTimer;
  bool _isHovering = false;
  bool _timerPending = false; // Track if timer is waiting
  final Duration hoverDelay;
  final OverlayState Function() getOverlay;

  // Store the pending tooltip info
  Offset? _pendingPosition;
  Widget? _pendingContent;

  ChartTooltipManager({
    required this.getOverlay,
    this.hoverDelay = const Duration(milliseconds: 500),
  });

  /// Show a tooltip at the given position with the provided content widget.
  void showTooltip({
    required Offset position,
    required Widget content,
    Offset offsetFromCursor = const Offset(15, 15),
  }) {
    // If timer is already pending, don't restart it - just update the position
    if (_timerPending) {
      _pendingPosition = position + offsetFromCursor;
      _pendingContent = content;
      return;
    }

    // Only start a new timer if one isn't pending
    _hoverTimer?.cancel();
    _pendingPosition = position + offsetFromCursor;
    _pendingContent = content;
    _timerPending = true;

    _hoverTimer = Timer(hoverDelay, () {
      _timerPending = false;
      if (_pendingPosition != null && _pendingContent != null) {
        _createAndShowOverlay(_pendingPosition!, _pendingContent!);
        _isHovering = true;
      }
    });
  }

  /// Create and insert the overlay entry for the tooltip.
  void _createAndShowOverlay(Offset position, Widget content) {
    // Clear any existing overlay
    _hoverOverlay?.remove();
    _hoverOverlay = null;

    _hoverOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            color: Colors.transparent,
            child: MouseRegion(
              onEnter: (_) {
                // Keep tooltip visible when mouse is over it
                developer.log("Mouse entered tooltip", name: "rubin_chart.chart_tooltip_manager");
                _hoverTimer?.cancel();
                _timerPending = false;
                _isHovering = true;
              },
              onExit: (_) {
                // Hide tooltip when mouse leaves
                developer.log("Mouse exited tooltip", name: "rubin_chart.chart_tooltip_manager");
                clearTooltip();
              },
              child: content,
            ),
          ),
        );
      },
    );

    try {
      getOverlay().insert(_hoverOverlay!);
    } catch (e) {
      developer.log("Failed to insert tooltip overlay: $e", name: "rubin_chart.chart_tooltip_manager");
      _hoverOverlay = null;
    }
  }

  /// Clear the tooltip and cancel any pending timers.
  void clearTooltip() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    _timerPending = false;
    _pendingPosition = null;
    _pendingContent = null;
    _hoverOverlay?.remove();
    _hoverOverlay = null;
    _isHovering = false;
  }

  /// Restart the hover timer (called when cursor moves while hovering)
  void restartHoverTimer() {
    // Only clear if tooltip is already shown (not pending)
    if (_isHovering && _hoverOverlay != null) {
      clearTooltip();
    }
  }

  /// Check if currently hovering over content
  bool get isHovering => _isHovering;

  /// Handle cursor entering a hoverable element
  void onHoverEnter() {
    _isHovering = true;
  }

  /// Handle cursor exiting a hoverable element
  void onHoverExit() {
    _isHovering = false;
    clearTooltip();
  }

  /// Check if tooltip is currently visible.
  bool get isVisible => _hoverOverlay != null && _isHovering;

  /// Dispose of the tooltip manager and clean up resources.
  void dispose() {
    clearTooltip();
  }
}

/// Standard tooltip widget for charts.
class ChartTooltip extends StatelessWidget {
  final String title;
  final List<TooltipEntry> entries;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;

  const ChartTooltip({
    Key? key,
    required this.title,
    required this.entries,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFE0E0E0),
    this.borderRadius = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: false,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor.withAlpha(250),
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ...entries.map((entry) => Text("${entry.label}: ${entry.value}")),
          ],
        ),
      ),
    );
  }
}

/// A single entry in a tooltip.
class TooltipEntry {
  final String label;
  final String value;

  TooltipEntry({required this.label, required this.value});
}
