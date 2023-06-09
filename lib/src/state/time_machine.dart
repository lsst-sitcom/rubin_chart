import 'package:rubin_chart/src/state/action.dart';

/// A function to apply a time machine update to a state of type [T].
typedef TimeMachineUpdateCallback<T> = T Function(T state, TimeMachineUpdate update, bool forward);


/// An update to a state that is stored in the history
class TimeMachineUpdate<T> {
  /// Any comment about the update, and what it is doing
  final String comment;
  /// The value of the state after the update.
  final T state;

  const TimeMachineUpdate({
    required this.comment,
    required this.state,
  });
}


/// Possible history actions
enum TimeMachineActions {
  first,
  rewind,
  previous,
  next,
  fastForward,
  last,
}


/// An action that updates the history
class TimeMachineAction extends UiAction {
  final TimeMachineActions action;

  const TimeMachineAction({
    required this.action,
  });
}


/// The history of all major state changes in the app.
class TimeMachine<T> {
  /// All of the updates in the history
  final List<TimeMachineUpdate<T>> updates;
  /// An index to the currently displayed update
  final int frame;
  /// Reset to the first state in the history
  final T firstState;
  /// The latest state in the history
  final T lastState;
  /// Current state
  final T currentState;

  const TimeMachine({
    required this.updates,
    this.frame=0,
    required this.firstState,
    required this.lastState,
    required this.currentState,
  });

  static TimeMachine<T> init<T>(T initialState) => TimeMachine(
    currentState: initialState,
    firstState: initialState,
    lastState: initialState,
    updates: [],
  );

  TimeMachine<T> copyWith({
    List<TimeMachineUpdate<T>>? updates,
    int? frame,
    T? firstState,
    T? lastState,
    T? currentState,
  }) => TimeMachine<T>(
    updates: updates ?? this.updates,
    frame: frame ?? this.frame,
    firstState: firstState ?? this.firstState,
    lastState: lastState ?? this.lastState,
    currentState: currentState ?? this.currentState,
  );

  /// Return a new time machine with the current state added
  TimeMachine<T> updated(TimeMachineUpdate<T> update){
    final List<TimeMachineUpdate<T>> newUpdates = [];
    newUpdates.addAll(updates.sublist(0, frame));

    // Add the new update
    newUpdates.add(update);
    // Update the state to the new value
    T state = update.state;

    return TimeMachine<T>(
      updates: newUpdates,
      frame: frame + 1,
      firstState: firstState,
      lastState: state,
      currentState: state,
    );
  }

  TimeMachine<T> addForgettable(T state) => copyWith(
    frame: frame,
    currentState: state,
    lastState: state,
  );

  /// Get the first state in the time machine
  TimeMachine<T> get first => copyWith(
    frame: 0,
    currentState: firstState,
  );

  /// Get the last state in the time machine
  TimeMachine<T> get last => copyWith(
    frame: updates.length,
    currentState: lastState,
  );

  /// Get the previous state in the time machine
  TimeMachine<T> get previous => frame > 0
      ? copyWith(
    frame: frame - 1,
    currentState: updates[frame-1].state,
  )
      : frame == 0
      ? copyWith(frame: 0, currentState: firstState)
      : this;

  /// Get the next state in the time machine
  TimeMachine<T> get next => frame < updates.length
      ? copyWith(
    frame: frame+1,
    currentState: updates[frame].state,
  )
      : this;
}
