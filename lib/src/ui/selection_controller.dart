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
  final Map<Object, SelectionUpdate> _observers = {};

  // Subscribe by providing a chartId and the callback
  void subscribe(Object chartId, SelectionUpdate observer) {
    _observers[chartId] = observer;
  }

  /// Unsubscribe from the selection controller.
  void unsubscribe(Object chartId) {
    _observers.remove(chartId);
  }

  /// Notify all observers that the selection has changed.
  void _notifyObservers(Object? originChartId) {
    for (var entry in _observers.entries) {
      // Skip notifying the chart that originated this selection update
      if (entry.key == originChartId) {
        continue;
      }
      // Pass along the originChartId so that observers know where the update came from.
      entry.value(originChartId, _selectedDataPoints);
    }
  }

  /// Update the selected datapoints.
  void updateSelection(Object chartId, Set<Object> dataPoints) {
    // Check if this is actually a change
    bool hasChanges = false;

    if (_selectedDataPoints.length != dataPoints.length) {
      hasChanges = true;
    } else if (_lastSelectionOrigin != chartId) {
      hasChanges = true;
    } else if (!dataPoints.every((element) => _selectedDataPoints.contains(element))) {
      hasChanges = true;
    }

    if (!hasChanges) {
      return;
    }

    // Record the new selection and origin
    _selectedDataPoints = Set.from(dataPoints);
    _lastSelectionOrigin = chartId;

    _notifyObservers(chartId);
  }

  /// Clear all selections
  void clearAllSelections() {
    _selectedDataPoints.clear();
    _lastSelectionOrigin = null;
    _notifyObservers(null);
  }

  void reset() {
    _selectedDataPoints.clear();
    _lastSelectionOrigin = null;
    _notifyObservers(null);
    _observers.clear();
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
    for (var entry in _observers.entries) {
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
