import 'package:flutter/material.dart';
import 'package:rubin_chart/src/chart/chart.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/chart/marker.dart';
import 'package:rubin_chart/src/core/workspace.dart';
import 'package:rubin_chart/src/query/query.dart';
import 'package:rubin_chart/src/query/widget.dart';
import 'package:rubin_chart/src/state/action.dart';
import 'package:rubin_chart/src/state/theme.dart';


/// Notify the [WorkspaceViewer] that the series has been updated
class SeriesUpdateAction extends UiAction {
  final Series series;
  final Chart chart;
  final DataCenter dataCenter;
  final String? groupByColumn;

  const SeriesUpdateAction({
    required this.series,
    required this.chart,
    required this.dataCenter,
    this.groupByColumn,
  });
}


typedef SeriesQueryCallback = void Function(Query? query);


class Series {
  final int id;
  final String name;
  final MarkerSettings? marker;
  final ErrorBarSettings? errorBarSettings;
  final List<SchemaField> fields;
  final Query? query;
  final String? _dataSetName;

  const Series({
    required this.id,
    required this.name,
    required this.fields,
    this.marker,
    this.errorBarSettings,
    this.query,
    String? dataSetName,
  }):_dataSetName=dataSetName;

  Series copyWith({
    int? id,
    String? name,
    List<SchemaField>? fields,
    MarkerSettings? marker,
    ErrorBarSettings? errorBarSettings,
    Query? query,
    String? dataSetName,
    int? axes,
  }) => Series(
    id: id ?? this.id,
    name: name ?? this.name,
    fields: fields ?? this.fields,
    marker: marker ?? this.marker,
    errorBarSettings: errorBarSettings ?? this.errorBarSettings,
    query: query ?? this.query,
    dataSetName: _dataSetName ?? this.dataSetName,
  );

  String get dataSetName => _dataSetName ?? fields.first.dataSetName;

  Series copy() => copyWith();

  @override
  String toString() => "Series<$id-$name>(schema: $fields)";
}


class SeriesEditor extends StatefulWidget {
  final ChartTheme theme;
  final Chart info;
  final Series series;
  final bool isNew;
  final DataCenter dataCenter;
  final DispatchAction dispatch;

  const SeriesEditor({
    super.key,
    required this.theme,
    required this.info,
    required this.series,
    required this.dataCenter,
    required this.dispatch,
    this.isNew = false,
  });

  @override
  SeriesEditorState createState() => SeriesEditorState();
}


class SeriesEditorState extends State<SeriesEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Chart get info => widget.info;

  ChartTheme get theme => widget.theme;
  late Series series;

  /// [TextEditingController] for the series name.
  TextEditingController nameController = TextEditingController();

  /// Create a collection of [Series] based on unique values of the [groupName] column.
  String? groupByColumn;


  @override
  void initState(){
    super.initState();
    series = widget.series.copy();
    nameController.text = series.name;
  }

  void updateQuery(Query? query){
    series = series.copyWith(query: query);
  }

  @override
  Widget build(BuildContext context){
    DataCenter dataCenter = widget.dataCenter;

    final List<DropdownMenuItem<String>> dataSetEntries = dataCenter.dataSets.keys.map((String name) =>
        DropdownMenuItem(value: name, child: Text(name))
    ).toList();

    DataSet dataSet = dataCenter.dataSets[series.dataSetName]!;

    final List<DropdownMenuItem<String>> groupNameEntries = [
      const DropdownMenuItem(value: null, child: Text("")),
      ...dataSet.schema.fields.keys.map((String name) => DropdownMenuItem(value: name, child: Text(name)))
    ];

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 400,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  onChanged: (String value){
                    series = series.copyWith(name: value);
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    label: Text("name"),
                  ),
                  validator: (String? value){
                    if(value == null || value.isEmpty){
                      return "The series must have a name";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: series.dataSetName,
                  items: dataSetEntries,
                  decoration: widget.theme.queryTextDecoration.copyWith(
                    labelText: "data set",
                  ),
                  onChanged: (String? dataSetName) {
                    setState(() {
                      List<SchemaField> fields = series.fields.map(
                              (field) => dataCenter.dataSets[dataSetName]!.schema.fields[field.name]!
                      ).toList();
                      series = series.copyWith(fields: fields);
                    });
                  },
                ),
                const SizedBox(height: 10),
                ColumnNameEditor(theme: theme, dataCenter: dataCenter, series: series, info: info),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: groupByColumn,
                  items: groupNameEntries,
                  decoration: widget.theme.queryTextDecoration.copyWith(
                    labelText: "group by",
                  ),
                  onChanged: (String? columnName) {
                    setState(() {
                      groupByColumn = columnName;
                    });
                  },
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: (){
                        showDialog(context: context, builder: (BuildContext context) => Dialog(
                          child: QueryEditor(
                            theme: theme,
                            expression: QueryExpression(
                              queries: series.query == null ? [] : [series.query!],
                              dataSetName: series.dataSetName,
                              dataCenter: dataCenter,
                            ),
                            info: info,
                            series: series,
                            onCompleted: updateQuery,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.query_stats),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: (){
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.cancel, color: Colors.red),
                    ),
                    IconButton(
                      onPressed: (){
                        if (_formKey.currentState!.validate()) {
                          widget.dispatch(SeriesUpdateAction(
                            chart: info,
                            series: series,
                            groupByColumn: groupByColumn,
                            dataCenter: dataCenter,
                          ));
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                  ],
                ),
              ]
          ),
        ),
      ),
    );
  }
}


class ColumnNameEditor extends StatefulWidget {
  final ChartTheme theme;
  final Series series;
  final DataCenter dataCenter;
  final Chart info;

  const ColumnNameEditor({
    super.key,
    required this.theme,
    required this.dataCenter,
    required this.series,
    required this.info,
  });

  @override
  ColumnNameEditorState createState() => ColumnNameEditorState();
}


class ColumnNameEditorState extends State<ColumnNameEditor> {
  ChartTheme get theme => widget.theme;
  Series get series => widget.series;
  DataCenter get dataCenter => widget.dataCenter;
  DataSet get dataSet => dataCenter.dataSets[series.dataSetName]!;
  Chart get info => widget.info;

  @override
  Widget build(BuildContext context){
    final List<Widget> children = [];
    for(int i=0; i<series.fields.length; i++){
      children.add(DropdownButtonFormField(
        value: series.fields[i].name,
        decoration: widget.theme.queryTextDecoration.copyWith(
          labelText: "column $i",
        ),
        items: dataSet.schema.fields.keys.map((String name) =>
            DropdownMenuItem(value: name, child: Text(name))
        ).toList(),
        onChanged: (String? value){
          series.fields[i] = dataSet.schema.fields[value]!;
        },
        validator: (String? value){
          List<int>? mismatched = info.canAddSeries(series: series, dataCenter: dataCenter);
          if(mismatched == null){
            return "Mismatch between columns and plot axes";
          }
          if(mismatched.contains(i)){
            return "Column is not compatible with plot axes";
          }
          return null;
        },
      ));
      children.add(const SizedBox(height: 10));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
