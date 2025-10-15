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
    developer.log(
        'SELECTION CONTROLLER - Notifying ${_observers.length} observers of selection change from chartId=$originChartId with ${_selectedDataPoints.length} points',
        name: 'rubin_chart');

    for (var entry in _observers.entries) {
      // Skip notifying the chart that originated this selection update
      if (entry.key == originChartId) {
        developer.log('SELECTION CONTROLLER - Skipping notification to originating chart $originChartId',
            name: 'rubin_chart');
        continue;
      }

      developer.log('SELECTION CONTROLLER - Notifying observer ${entry.key} of selection change',
          name: 'rubin_chart');
      // Pass along the originChartId so that observers know where the update came from.
      entry.value(originChartId, _selectedDataPoints);
    }

    developer.log('SELECTION CONTROLLER - Finished notifying observers', name: 'rubin_chart');
  }

  /// Update the selected datapoints.
  void updateSelection(Object chartId, Set<Object> dataPoints) {
    developer.log(
        'SELECTION CONTROLLER - BEFORE UPDATE: Selected points=${_selectedDataPoints.length}, Last origin=$_lastSelectionOrigin',
        name: 'rubin_chart');
    developer.log(
        'SELECTION CONTROLLER - Updating selection for chartId=$chartId with ${dataPoints.length} points',
        name: 'rubin_chart');

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
      developer.log('SELECTION CONTROLLER - No change in selection, skipping update', name: 'rubin_chart');
      return;
    }

    // Record the new selection and origin
    _selectedDataPoints = Set.from(dataPoints);
    _lastSelectionOrigin = chartId;

    if (dataPoints.isEmpty) {
      developer.log('SELECTION CONTROLLER - Chart $chartId cleared selection', name: 'rubin_chart');
    } else {
      developer.log('SELECTION CONTROLLER - Chart $chartId made selection with ${dataPoints.length} points',
          name: 'rubin_chart');
    }

    developer.log(
        'SELECTION CONTROLLER - AFTER UPDATE: Selected points=${_selectedDataPoints.length}, Origin=$chartId',
        name: 'rubin_chart');

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
}
