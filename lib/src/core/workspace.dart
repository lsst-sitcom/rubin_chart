import 'package:flutter/material.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/core/menu.dart';
import 'package:rubin_chart/src/core/toolbar.dart';
import 'package:rubin_chart/src/state/action.dart';
import 'package:rubin_chart/src/state/theme.dart';
import 'package:rubin_chart/src/state/workspace.dart';


/// Different sides that can be resized
enum WindowResizeDirections {
  left,
  right,
  down,
  downLeft,
  downRight,
}


/// A callback when a window has been updated
typedef WindowUpdateCallback = void Function(WindowUpdate update);


/// Information about window interactions
class WindowInteractionInfo {
  final int id;
  Offset offset;
  Size size;

  WindowInteractionInfo({
    required this.id,
    required this.offset,
    required this.size,
  });
}


class WindowDragInfo extends WindowInteractionInfo {
  final Offset pointerOffset;

  WindowDragInfo({
    required super.id,
    required this.pointerOffset,
    required super.offset,
    required super.size,
  });
}


class WindowResizeInfo extends WindowInteractionInfo {
  final Offset initialPointerOffset;
  final Size initialSize;
  final Offset initialOffset;

  WindowResizeInfo({
    required super.id,
    required this.initialPointerOffset,
    required this.initialSize,
    required this.initialOffset,
    required super.offset,
    required super.size,
  });
}


/// An update to the window (either a resize or translation).
class WindowUpdate {
  const WindowUpdate();
}


/// Update when a window is first being dragged.
class StartDragWindowUpdate extends WindowUpdate {
  final int windowId;
  final DragStartDetails details;

  const StartDragWindowUpdate({
    required this.windowId,
    required this.details,
  });
}


/// Update when a window is being dragged.
class UpdateDragWindowUpdate extends WindowUpdate {
  final int windowId;
  final DragUpdateDetails details;

  const UpdateDragWindowUpdate({
    required this.windowId,
    required this.details,
  });
}


/// Update when the drag pointer has been removed and the window is no longer being dragged.
class WindowDragEnd extends WindowUpdate {
  final int windowId;
  final DragEndDetails details;

  const WindowDragEnd({
    required this.windowId,
    required this.details,
  });
}


/// A window has started to be resized
class StartWindowResize extends WindowUpdate {
  final int windowId;
  final DragStartDetails details;

  StartWindowResize({
    required this.windowId,
    required this.details,
  });
}

/// [WindowUpdate] to update the size of a [Window] in the parent [WorkspaceViewer].
class UpdateWindowResize extends WindowUpdate {
  final int windowId;
  final DragUpdateDetails details;
  final WindowResizeDirections direction;

  const UpdateWindowResize({
    required this.windowId,
    required this.details,
    required this.direction,
  });
}


/// The window has finished resizing.
class EndWindowResize extends WindowUpdate {
  final int windowId;
  final DragEndDetails details;

  const EndWindowResize({
    required this.windowId,
    required this.details,
  });
}


/// Apply an update to a [Window] to the main [AppState].
class ApplyWindowUpdate extends UiAction {
  final int windowId;
  final Offset offset;
  final Size size;

  ApplyWindowUpdate({
    required this.windowId,
    required this.offset,
    required this.size,
  });
}


/// Draw the title (drag) bar above the window.
class WindowTitle extends StatelessWidget {
  /// The text to display in the title
  final String? text;
  /// The [ChartTheme] for the app.
  final ChartTheme theme;
  final Widget? toolbar;

  const WindowTitle({
    super.key,
    required this.text,
    required this.theme,
    this.toolbar,
  });

  @override
  Widget build(BuildContext context){
    if(toolbar != null){
      return Container(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          decoration: BoxDecoration(
            color: theme.themeData.colorScheme.primaryContainer,
          ),
          child: Row(
              children: [
                IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: theme.titleStyle.color,
                      size: kMinInteractiveDimension * .7,
                    ),
                    onPressed: (){
                      print("Open menu");
                    }
                ),
                Expanded(
                  child: Center(
                    child: Text(text ?? "", style: theme.titleStyle, textAlign: TextAlign.center),
                  ),
                ),
                toolbar!,
              ]
          )
      );
    }

    return Container(
      constraints: const BoxConstraints(
        minHeight: kMinInteractiveDimension,
      ),
      decoration: BoxDecoration(
        color: theme.themeData.colorScheme.primaryContainer,
      ),
      child: Row(
          children: [
            IconButton(
                icon: Icon(
                  Icons.menu,
                  color: theme.titleStyle.color,
                  size: kMinInteractiveDimension * .7,
                ),
                onPressed: (){
                  print("Open menu");
                }
            ),
            Expanded(
              child: Center(
                child: Text(text ?? "", style: theme.titleStyle, textAlign: TextAlign.center),
              ),
            ),
          ]
      ),
    );
  }
}


class ResizableWindow extends StatelessWidget {
  /// The child [Widget] to display in the window.
  final Widget child;
  /// The title to display in the window
  final String? title;
  /// The full size of the window, including the [WindowTitle].
  /// If [size] is null then the window will layout the child first and expand to the child size.
  final Size size;
  /// The [ChartTheme] for the app.
  final ChartTheme theme;
  /// Information about the widget
  final Window info;
  /// Callback to notify the [WorkspaceViewer] that this [Window] has been updated.
  final WindowUpdateCallback dispatch;
  /// Toolbar associated with the window
  final Widget? toolbar;

  const ResizableWindow({
    super.key,
    required this.child,
    required this.title,
    required this.theme,
    required this.info,
    required this.size,
    required this.dispatch,
    required this.toolbar,
  });

  void _onResizeStart(DragStartDetails details){
    dispatch(StartWindowResize(windowId: info.id, details: details));
  }

  DragUpdateCallback _onResizeUpdate(WindowResizeDirections direction) {
    return (DragUpdateDetails details){
      dispatch(UpdateWindowResize(
        windowId: info.id,
        details: details,
        direction: direction,
      ));
    };
  }

  void _onResizeEnd(DragEndDetails details){
    dispatch(EndWindowResize(windowId: info.id, details: details));
  }

  @override
  Widget build(BuildContext context){
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: theme.themeData.colorScheme.background,
        child: IntrinsicWidth(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onPanStart: (DragStartDetails details){
                      dispatch(StartDragWindowUpdate(windowId: info.id, details: details));
                    },
                    onPanUpdate: (DragUpdateDetails details){
                      dispatch(UpdateDragWindowUpdate(windowId: info.id, details: details));
                    },
                    onPanEnd: (DragEndDetails details){
                      dispatch(WindowDragEnd(windowId: info.id, details: details));
                    },
                    child: WindowTitle(
                      text: title,
                      theme: theme,
                      toolbar: toolbar,
                    ),
                  ),
                  SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.all(5),
                            child: child,
                          ),

                          // Left resize
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onHorizontalDragStart: _onResizeStart,
                              onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.left),
                              onHorizontalDragEnd: _onResizeEnd,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeLeftRight,
                                child: SizedBox(
                                  height: size.height,
                                  width: theme.resizeInteractionWidth,
                                ),
                              ),
                            ),
                          ),

                          // right resize
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onHorizontalDragStart: _onResizeStart,
                              onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.right),
                              onHorizontalDragEnd: _onResizeEnd,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeLeftRight,
                                child: SizedBox(
                                  height: size.height,
                                  width: theme.resizeInteractionWidth,
                                ),
                              ),
                            ),
                          ),

                          // bottom resize
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onHorizontalDragStart: _onResizeStart,
                              onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.down),
                              onHorizontalDragEnd: _onResizeEnd,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeUpDown,
                                child: SizedBox(
                                  height: theme.resizeInteractionWidth,
                                  width: size.width,
                                ),
                              ),
                            ),
                          ),

                          // bottom-left resize
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onHorizontalDragStart: _onResizeStart,
                              onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.downLeft),
                              onHorizontalDragEnd: _onResizeEnd,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeDownLeft,
                                child: SizedBox(
                                  height: theme.resizeInteractionWidth,
                                  width: theme.resizeInteractionWidth,
                                ),
                              ),
                            ),
                          ),

                          // bottom-right resize
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onHorizontalDragStart: _onResizeStart,
                              onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.downRight),
                              onHorizontalDragEnd: _onResizeEnd,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeDownRight,
                                child: SizedBox(
                                  height: theme.resizeInteractionWidth,
                                  width: theme.resizeInteractionWidth,
                                ),
                              ),
                            ),
                          ),
                        ]
                    ),
                  ),
                ]
            )
        ),
      ),
    );
  }
}


/// A [Widget] used to display a set of re-sizable and translatable [Window] widgets in a container.
class WorkspaceViewer extends StatefulWidget {
  final Size size;
  final Workspace workspace;
  final DataCenter dataCenter;
  final DispatchAction dispatch;

  const WorkspaceViewer({
    super.key,
    required this.size,
    required this.workspace,
    required this.dataCenter,
    required this.dispatch,
  });

  @override
  WorkspaceViewerState createState() => WorkspaceViewerState();

  /// Implement the [WorkspaceViewer.of] method to allow children
  /// to find this container based on their [BuildContext].
  static WorkspaceViewerState of(BuildContext context){
    final WorkspaceViewerState? result = context.findAncestorStateOfType<WorkspaceViewerState>();
    assert((){
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'WorkspaceViewer.of() called with a context that does not '
                  'contain a WorkspaceViewer.'
          ),
          ErrorDescription(
              'No WorkspaceViewer ancestor could be found starting from the context '
                  'that was passed to WorkspaceViewer.of().'
          ),
          ErrorHint(
              'This probably happened when an interactive child was created '
                  'outside of an WorkspaceViewer'
          ),
          context.describeElement('The context used was')
        ]);
      }
      return true;
    }());
    return result!;
  }
}


class WorkspaceViewerState extends State<WorkspaceViewer> {
  ChartTheme get theme => widget.workspace.theme;
  Size get size => widget.size;
  Workspace get info => widget.workspace;
  DataCenter get dataCenter => widget.dataCenter;
  DispatchAction get dispatch => widget.dispatch;
  Map<String, Set<dynamic>> get selected => widget.workspace.selected;

  WindowInteractionInfo? interactionInfo;

  @override
  Widget build(BuildContext context){

    return AppMenu(
      theme: theme,
      dispatch: dispatch,
      dataCenter: dataCenter,
      child: Column(
          children: [
            Toolbar(tool: widget.workspace.multiSelectionTool),
            SizedBox(
              width: size.width,
              height: size.height - 2*kToolbarHeight,
              child: Builder(
                builder: (BuildContext context){
                  List<Widget> children = [];
                  for(Window window in info.windows.values){
                    Offset offset = window.offset;
                    Size size = window.size;
                    if(interactionInfo != null && window.id == interactionInfo!.id){
                      offset = interactionInfo!.offset;
                      size = interactionInfo!.size;
                    }

                    children.add(Positioned(
                      left: offset.dx,
                      top: offset.dy,
                      child: ResizableWindow(
                        info: window,
                        theme: theme,
                        title: window.title,
                        dispatch: _updateWindow,
                        size: size,
                        toolbar: window.createToolbar(context),
                        child: window.createWidget(context),
                      ),
                    ));
                  }

                  return Stack(
                    children: children,
                  );
                },
              ),
            ),
          ]
      ),
    );
  }

  void _updateWindow(WindowUpdate update){
    // Translation updates
    if(update is StartDragWindowUpdate){
      return startWindowDrag(update);
    }
    if(update is UpdateDragWindowUpdate){
      return updateWindowDrag(update);
    }
    if(update is WindowDragEnd){
      return dragEnd();
    }
    // Resize updates
    if(update is StartWindowResize){
      return startWindowResize(update);
    }
    if(update is UpdateWindowResize){
      return updateWindowReSize(update);
    }
    if(update is EndWindowResize){
      return dragEnd();
    }
    throw ArgumentError("Unrecognized WindowUpdate $update");
  }

  /// Keep track of the starting drag position
  void startWindowDrag(StartDragWindowUpdate update){
    if(interactionInfo != null){
      dragEnd();
    }
    Window window = info.windows[update.windowId]!;
    interactionInfo = WindowDragInfo(
      id: update.windowId,
      pointerOffset: window.offset - update.details.localPosition,
      offset: window.offset,
      size: window.size,
    );
    setState(() {});
  }

  void updateWindowDrag(UpdateDragWindowUpdate update){
    if(interactionInfo is! WindowDragInfo){
      dragEnd();
      throw Exception("Mismatched interactionInfo, got $interactionInfo");
    }
    setState(() {
      WindowDragInfo interaction = interactionInfo as WindowDragInfo;
      interaction.offset = update.details.localPosition + (interactionInfo as WindowDragInfo).pointerOffset;
    });
  }

  void dragEnd(){
    if(interactionInfo != null){
      dispatch(ApplyWindowUpdate(
        windowId: interactionInfo!.id,
        offset: interactionInfo!.offset,
        size: interactionInfo!.size,
      ));
      interactionInfo = null;
      setState(() {});
    }
  }

  void startWindowResize(StartWindowResize update){
    if(interactionInfo != null){
      dragEnd();
    }
    Window window = info.windows[update.windowId]!;

    interactionInfo = WindowResizeInfo(
      id: update.windowId,
      initialPointerOffset: update.details.globalPosition,
      initialSize: window.size,
      initialOffset: window.offset,
      offset: window.offset,
      size: window.size,
    );
    setState(() {});
  }

  void updateWindowReSize(UpdateWindowResize update){
    if(interactionInfo is! WindowResizeInfo){
      dragEnd();
      throw Exception("Mismatched interactionInfo, got $interactionInfo");
    }
    WindowResizeInfo interaction = interactionInfo as WindowResizeInfo;
    Offset deltaPosition = update.details.globalPosition - interaction.initialPointerOffset;

    double left = interaction.initialOffset.dx;
    double top = interaction.initialOffset.dy;
    double width = interaction.initialSize.width;
    double height = interaction.initialSize.height;

    // Update the width and x-offset
    if(update.direction == WindowResizeDirections.right || update.direction == WindowResizeDirections.downRight){
      width = interaction.initialSize.width + deltaPosition.dx;
    } else if(update.direction == WindowResizeDirections.left || update.direction == WindowResizeDirections.downLeft){
      left = interaction.initialOffset.dx + deltaPosition.dx;
      width = interaction.initialSize.width - deltaPosition.dx;
    }

    // Update the height and y-offset
    if(update.direction == WindowResizeDirections.down
        || update.direction == WindowResizeDirections.downLeft
        || update.direction == WindowResizeDirections.downRight
    ){
      height = interaction.initialSize.height + deltaPosition.dy;
    }

    interaction.offset = Offset(left, top);
    interaction.size = Size(width, height);
    setState(() {});
  }
}
