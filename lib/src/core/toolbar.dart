import 'package:flutter/material.dart';
import 'package:rubin_chart/src/chart/chart.dart';
import 'package:rubin_chart/src/core/workspace.dart';
import 'package:rubin_chart/src/state/action.dart';


class ToolbarAction extends UiAction {
  const ToolbarAction();
}


class UpdateMultiSelect extends ToolbarAction {
  final MultiSelectionTool tool;

  UpdateMultiSelect(this.tool);
}


class Toolbar extends StatefulWidget {
  final MultiSelectionTool tool;

  const Toolbar({
    super.key,
    required this.tool,
  });

  @override
  ToolbarState createState() => ToolbarState();
}


class ToolbarState extends State<Toolbar> {
  late MultiSelectionTool tool;

  @override
  void initState(){
    super.initState();
    tool = widget.tool;
  }

  @override
  Widget build(BuildContext context){
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);

    return Container(
      width: workspace.size.width,
      height: kToolbarHeight,
      decoration: BoxDecoration(
        color: workspace.theme.themeData.colorScheme.primaryContainer,
      ),
      child: Row(
        children: [
          const Spacer(),
          SegmentedButton<MultiSelectionTool>(
            selected: {tool},
            segments: [
              ButtonSegment(
                value: MultiSelectionTool.select,
                icon: Icon(Icons.touch_app, color: workspace.theme.themeData.primaryColor),
              ),
              ButtonSegment(
                value: MultiSelectionTool.zoom,
                icon: Icon(Icons.zoom_in, color: workspace.theme.themeData.primaryColor),
              ),
              ButtonSegment(
                value: MultiSelectionTool.drill,
                icon: Icon(Icons.query_stats, color: workspace.theme.themeData.primaryColor),
              ),
              ButtonSegment(
                value: MultiSelectionTool.pan,
                icon: Icon(Icons.pan_tool, color: workspace.theme.themeData.primaryColor),
              ),
            ],
            onSelectionChanged: (Set<MultiSelectionTool> selection){
              tool = selection.first;
              workspace.dispatch(UpdateMultiSelect(selection.first));
            },
          ),
        ],
      ),
    );
  }
}
