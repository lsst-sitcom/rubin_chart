/// An action performed by the UI that will update the global state
class UiAction {
  const UiAction();
}

/// Function to update the full app state in the [Store].
typedef DispatchAction = void Function(dynamic action);
