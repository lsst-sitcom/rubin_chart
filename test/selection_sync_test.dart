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

import 'package:flutter_test/flutter_test.dart';
import 'package:rubin_chart/src/ui/selection_controller.dart';

import 'test_utils.dart';

void main() {
  group('SelectionController Tests', () {
    late SelectionController controller;

    const Object scatterChartId = 'scatter';
    const Object histogramChartId = 'histogram';

    final Set<Object> scatterSelection = {
      const TestDataId(1, 1),
      const TestDataId(2, 1),
      const TestDataId(3, 1),
    };

    final Set<Object> histogramSelection = {
      const TestDataId(3, 1),
      const TestDataId(4, 1),
      const TestDataId(5, 1),
    };

    setUp(() {
      controller = SelectionController();
    });

    test('Initial selections should be empty', () {
      expect(controller.selectedDataPoints, isEmpty);
    });

    test('Single chart selection update works', () {
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));
    });

    test('Selection update from second chart should replace first chart selection', () {
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));

      controller.updateSelection(histogramChartId, histogramSelection);
      expect(controller.selectedDataPoints, equals(histogramSelection));
    });

    test('Deselecting in one chart should clear all selections', () {
      // First select points in both charts
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));

      controller.updateSelection(histogramChartId, histogramSelection);
      expect(controller.selectedDataPoints, equals(histogramSelection));

      // Now deselect in scatter chart
      controller.updateSelection(scatterChartId, {});
      expect(controller.selectedDataPoints, isEmpty);
    });

    test('After deselection, new selection should work', () {
      // First select points
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));

      // Then deselect
      controller.updateSelection(scatterChartId, {});
      expect(controller.selectedDataPoints, isEmpty);

      // Now select new points
      controller.updateSelection(histogramChartId, histogramSelection);
      expect(controller.selectedDataPoints, equals(histogramSelection));
    });

    test('Deselect all charts and then reselect should work correctly', () {
      // First select in both charts
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));

      controller.updateSelection(histogramChartId, histogramSelection);
      expect(controller.selectedDataPoints, equals(histogramSelection));

      // Deselect in scatter chart
      controller.updateSelection(scatterChartId, {});
      expect(controller.selectedDataPoints, isEmpty);

      // Deselect in histogram chart too
      controller.updateSelection(histogramChartId, {});
      expect(controller.selectedDataPoints, isEmpty);

      // Now select in scatter chart again
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));

      // And select in histogram chart again
      controller.updateSelection(histogramChartId, histogramSelection);
      expect(controller.selectedDataPoints, equals(histogramSelection));
    });

    test('Internal selection state should properly track selections', () {
      // First select points in scatter chart
      controller.updateSelection(scatterChartId, scatterSelection);

      // Verify selection has correct points
      expect(controller.selectionSize, equals(3));
      expect(controller.containsDataPoint(const TestDataId(1, 1)), isTrue);
      expect(controller.containsDataPoint(const TestDataId(2, 1)), isTrue);
      expect(controller.containsDataPoint(const TestDataId(3, 1)), isTrue);

      // Now select in histogram chart
      controller.updateSelection(histogramChartId, histogramSelection);

      // Verify that histogram selection replaced scatter selection
      expect(controller.selectionSize, equals(3));
      expect(controller.containsDataPoint(const TestDataId(1, 1)), isFalse);
      expect(controller.containsDataPoint(const TestDataId(3, 1)), isTrue);
      expect(controller.containsDataPoint(const TestDataId(4, 1)), isTrue);
      expect(controller.containsDataPoint(const TestDataId(5, 1)), isTrue);

      // Deselect in scatter chart
      controller.updateSelection(scatterChartId, {});

      // Verify selection is cleared
      expect(controller.selectionSize, equals(0));
    });

    test('Should allow reselection in a chart after it has been cleared', () {
      // First select in the scatter chart
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));

      // Now clear the selection
      controller.updateSelection(scatterChartId, {});
      expect(controller.selectedDataPoints, isEmpty);

      // Try to select the same points again - this should work
      controller.updateSelection(scatterChartId, scatterSelection);

      // Verify the selection was properly updated
      expect(controller.selectionSize, equals(3));
      expect(controller.containsDataPoint(const TestDataId(1, 1)), isTrue);
      expect(controller.containsDataPoint(const TestDataId(2, 1)), isTrue);
      expect(controller.containsDataPoint(const TestDataId(3, 1)), isTrue);
    });

    test('Should handle empty selection sets correctly', () {
      // First add a non-empty selection for scatter chart
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));

      // Now add an empty selection for histogram chart (this should be treated as a deselection)
      controller.updateSelection(histogramChartId, {});
      expect(controller.selectedDataPoints, isEmpty);

      // Now add a non-empty selection for histogram chart
      controller.updateSelection(histogramChartId, histogramSelection);
      expect(controller.selectedDataPoints, equals(histogramSelection));

      // Add a non-empty selection for scatter chart too
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));
    });

    test('Observers should be notified when selection changes', () {
      bool scatterNotified = false;
      bool histogramNotified = false;

      controller.subscribe(scatterChartId, (originChartId, dataPoints) {
        // We should not get notified about our own selection change
        expect(originChartId, isNot(equals(scatterChartId)));
        scatterNotified = true;
      });

      controller.subscribe(histogramChartId, (originChartId, dataPoints) {
        // We should not get notified about our own selection change
        expect(originChartId, isNot(equals(histogramChartId)));
        histogramNotified = true;
      });

      // Make selection from scatter chart
      controller.updateSelection(scatterChartId, scatterSelection);

      // Only histogram should have been notified
      expect(scatterNotified, isFalse);
      expect(histogramNotified, isTrue);

      // Reset flags
      scatterNotified = false;
      histogramNotified = false;

      // Make selection from histogram chart
      controller.updateSelection(histogramChartId, histogramSelection);

      // Only scatter should have been notified
      expect(scatterNotified, isTrue);
      expect(histogramNotified, isFalse);
    });

    test('clearAllSelections should clear selections and notify observers', () {
      // First make a selection
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));

      bool observerNotified = false;
      controller.subscribe('observer', (originChartId, dataPoints) {
        expect(originChartId, isNull);
        expect(dataPoints, isEmpty);
        observerNotified = true;
      });

      // Clear all selections
      controller.clearAllSelections();

      // Verify the selection was cleared
      expect(controller.selectedDataPoints, isEmpty);
      expect(observerNotified, isTrue);
    });

    test('Unsubscribe should remove observer', () {
      bool observerNotified = false;
      controller.subscribe('observer', (originChartId, dataPoints) {
        observerNotified = true;
      });

      // Unsubscribe the observer
      controller.unsubscribe('observer');

      // Make a selection
      controller.updateSelection(scatterChartId, scatterSelection);

      // Observer should not be notified
      expect(observerNotified, isFalse);
    });

    test('Reset should clear all selections and observers', () {
      int notificationCount = 0;
      controller.subscribe('observer', (originChartId, dataPoints) {
        // Only count notifications that happen after reset
        notificationCount++;
      });

      // First make a selection (this will trigger a notification we don't care about)
      controller.updateSelection(scatterChartId, scatterSelection);
      expect(controller.selectedDataPoints, equals(scatterSelection));

      // Reset the controller and reset our counter
      controller.reset();
      notificationCount = 0;

      // Verify selection is cleared
      expect(controller.selectedDataPoints, isEmpty);

      // Make another selection
      controller.updateSelection(scatterChartId, scatterSelection);

      // Observer should not be notified because it was cleared by reset
      expect(notificationCount, equals(0));
    });
  });
}
