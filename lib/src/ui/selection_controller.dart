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

import 'package:flutter/material.dart';
import 'dart:developer' as developer;

/// Callback when a data point is, or set of data points are, selected.
typedef SelectionUpdate = void Function(Object? originChartId, Set<Object> dataPoints);

/// A controller to manage the selection of data points across multiple charts.
///
/// This implementation uses a "last writer wins" approach where the most recent selection
/// becomes the active selection for all charts. This simplifies the synchronization model
/// and avoids complex intersection logic that can lead to unexpected behavior.
class SelectionController {
  /// The shared selection across all charts.
  Set<Object> _selectedDataPoints = {};

  /// The chart that originated the last selection.
  Object? _lastSelectionOrigin;

  SelectionController();

  /// Get the currently selected data points.
  Set<Object> get selectedDataPoints => Set.from(_selectedDataPoints);

  /// List of observers that are notified when the selection changes.
  final Map<Object, SelectionUpdate> observers = {};

  // Subscribe by providing a chartId and the callback
  void subscribe(Object chartId, SelectionUpdate observer) {
    developer.log("=== SUBSCRIBING TO SELECTION ===", name: "rubin_chart.selection_controller");
    developer.log("Chart $chartId subscribing to selection updates",
        name: "rubin_chart.selection_controller");
    developer.log("Subscribers before: ${observers.keys}", name: "rubin_chart.selection_controller");
    observers[chartId] = observer;
    developer.log("Subscribers after: ${observers.keys}", name: "rubin_chart.selection_controller");
  }

  /// Unsubscribe from the selection controller.
  void unsubscribe(Object chartId) {
    developer.log("=== UNSUBSCRIBING FROM SELECTION ===", name: "rubin_chart.selection_controller");
    developer.log("Chart $chartId unsubscribing from selection updates",
        name: "rubin_chart.selection_controller");
    developer.log("Subscribers before: ${observers.keys}", name: "rubin_chart.selection_controller");
    observers.remove(chartId);
    developer.log("Subscribers after: ${observers.keys}", name: "rubin_chart.selection_controller");
  }

  /// Notify all observers that the selection has changed.
  void _notifyObservers(Object? originChartId) {
    developer.log("=== NOTIFYING SELECTION OBSERVERS ===", name: "rubin_chart.selection_controller");
    developer.log("Origin: $originChartId, Selection size: ${_selectedDataPoints.length}",
        name: "rubin_chart.selection_controller");
    developer.log("Total observers: ${observers.length}", name: "rubin_chart.selection_controller");
    developer.log("Observer chart IDs: ${observers.keys}", name: "rubin_chart.selection_controller");

    for (var entry in observers.entries) {
      // Skip notifying the chart that originated this selection update
      if (entry.key == originChartId) {
        developer.log("Skipping notification to origin chart ${entry.key}",
            name: "rubin_chart.selection_controller");
        continue;
      }
      developer.log("Notifying chart ${entry.key} of selection update",
          name: "rubin_chart.selection_controller");
      // Pass along the originChartId so that observers know where the update came from.
      entry.value(originChartId, _selectedDataPoints);
    }
    developer.log("All observers notified", name: "rubin_chart.selection_controller");
  }

  /// Update the selected datapoints.
  void updateSelection(Object chartId, Set<Object> dataPoints) {
    developer.log("=== UPDATING SELECTION DATA ===", name: "rubin_chart.selection_controller");
    developer.log("Chart $chartId updating selection: ${dataPoints.length} points",
        name: "rubin_chart.selection_controller");
    developer.log("Current selection size: ${_selectedDataPoints.length}",
        name: "rubin_chart.selection_controller");
    developer.log("Last selection origin: $_lastSelectionOrigin", name: "rubin_chart.selection_controller");

    // Check if this is actually a change
    bool hasChanges = false;

    if (_selectedDataPoints.length != dataPoints.length) {
      developer.log("Selection size changed: ${_selectedDataPoints.length} -> ${dataPoints.length}",
          name: "rubin_chart.selection_controller");
      hasChanges = true;
    } else if (_lastSelectionOrigin != chartId) {
      developer.log("Selection origin changed: $_lastSelectionOrigin -> $chartId",
          name: "rubin_chart.selection_controller");
      hasChanges = true;
    } else if (!dataPoints.every((element) => _selectedDataPoints.contains(element))) {
      developer.log("Selection content changed", name: "rubin_chart.selection_controller");
      hasChanges = true;
    }

    if (!hasChanges) {
      developer.log("No changes detected, skipping update", name: "rubin_chart.selection_controller");
      return;
    }

    // Record the new selection and origin
    _selectedDataPoints = Set.from(dataPoints);
    _lastSelectionOrigin = chartId;
    developer.log("Selection updated successfully", name: "rubin_chart.selection_controller");

    _notifyObservers(chartId);
  }

  /// Clear all selections
  void clearAllSelections() {
    _selectedDataPoints.clear();
    _lastSelectionOrigin = null;
    _notifyObservers(null);
  }

  void reset() {
    developer.log("=== RESETTING SELECTION CONTROLLER ===", name: "rubin_chart.selection_controller");
    developer.log("Clearing ${_selectedDataPoints.length} selected points",
        name: "rubin_chart.selection_controller");
    developer.log("Clearing ${observers.length} observers", name: "rubin_chart.selection_controller");
    _selectedDataPoints.clear();
    _lastSelectionOrigin = null;
    _notifyObservers(null);
    observers.clear();
    developer.log("Selection controller reset complete", name: "rubin_chart.selection_controller");
  }

  /// Clear all of the observers on dispose.
  void dispose() {
    reset();
  }

  // Add helper method to check if we have any active selections
  bool get hasActiveSelections {
    return _selectedDataPoints.isNotEmpty;
  }

  /// For testing purposes only - returns the number of points in the selection
  @visibleForTesting
  int get selectionSize {
    return _selectedDataPoints.length;
  }

  /// For testing purposes only - checks if the selection contains specific data points
  @visibleForTesting
  bool containsDataPoint(Object dataPoint) {
    return _selectedDataPoints.contains(dataPoint);
  }

  /// Update with a temporary selection during drag operations.
  /// This differs from a normal selection update in that it marks the selection
  /// as temporary, allowing charts to decide how to visualize it.
  ///
  /// @param chartId The ID of the chart that originated the drag selection
  /// @param dataPoints The set of data points that are temporarily selected during drag
  void updateTemporarySelection(Object chartId, Set<Object> dataPoints) {
    // Record the last origin but DON'T update _selectedDataPoints since this is temporary
    _lastSelectionOrigin = chartId;

    // Notify observers about the temporary selection
    for (var entry in observers.entries) {
      // Skip notifying the chart that originated this drag selection
      if (entry.key == chartId) {
        continue;
      }

      // Pass the chartId and temporary data points to the observer
      // Other charts can then decide how to visualize this temporary selection
      entry.value(chartId, dataPoints);
    }
  }
}
