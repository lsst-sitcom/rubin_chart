import 'package:rubin_chart/src/state/time_machine.dart';
import 'package:rubin_chart/src/state/workspace.dart';


/// Global State for the entire App.
///
/// Since rubin_chart uses the redux design pattern there is a single
/// state for the entire app, which is kept in a
/// flutter.redux [Store] and is used to update the entire
/// app as necessary on changes.
class AppState {
  /// The manipulated expressions
  final TimeMachine<Workspace> timeMachine;

  const AppState({
    required this.timeMachine,
  });

  /// Make a copy of the state with the specified terms updated
  AppState copyWith({
    TimeMachine<Workspace>? timeMachine,
  }) => AppState(
    timeMachine: timeMachine ?? this.timeMachine,
  );

  /// Make an exact copy of the state
  AppState copy() => copyWith();
}



/// Main reducer for the entire app
AppState appReducer(AppState state, action){
  TimeMachine<Workspace> workspaceState = workspaceReducer(state.timeMachine, action);
  if(workspaceState != state.timeMachine){
    return state.copyWith(timeMachine: workspaceState);
  }
  return state;
}
