import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rubin_chart/src/chart/chart.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/core/utils.dart';
import 'package:rubin_chart/src/query/query.dart';
import 'package:rubin_chart/src/query/update.dart';
import 'package:rubin_chart/src/chart/series.dart';
import 'package:rubin_chart/src/state/theme.dart';


/// Callback to update an [EqualityOperator] in an [EqualityQueryWidget].
typedef UpdateEqualityOperatorCallback = void Function(EqualityOperator? operator);

/// Callback to update a [QueryOperator] in an [EqualityQueryWidget].
typedef UpdateQueryOperatorCallback = void Function(QueryOperator? operator);


/// Widget to display an [EqualityOperator] in an [EqualityQueryWidget].
class EqualityOperatorWidget extends StatefulWidget {
  /// Theme for the app.
  final ChartTheme theme;
  /// Operator to display
  final EqualityOperator operator;
  /// Available operators to select from.
  /// This is different depending on whether this is a left or right operator,
  /// and the data type
  final Set<EqualityOperator> availableOperators;
  /// Callback to the [EqualityQueryWidget] to update the operator.
  final UpdateEqualityOperatorCallback updateEqualityOperatorCallback;

  const EqualityOperatorWidget({
    super.key,
    required this.theme,
    required this.operator,
    required this.availableOperators,
    required this.updateEqualityOperatorCallback,
  });

  @override
  EqualityOperatorWidgetState createState() => EqualityOperatorWidgetState();
}


/// [State] for an [EqualityOperatorWidget].
class EqualityOperatorWidgetState extends State<EqualityOperatorWidget> {
  EqualityOperator? selectedOperator = EqualityOperator.blank;

  @override
  Widget build(BuildContext context){
    return DropdownButton<EqualityOperator>(
      value: selectedOperator,
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      items: widget.availableOperators.map((EqualityOperator operator)=>
          DropdownMenuItem(
            value: operator,
            child: Container(
              constraints: const BoxConstraints(minWidth: kMinInteractiveDimension),
              child: Text(
                operator.symbol,
                style: widget.theme.queryOperatorStyle,
                textAlign: TextAlign.center,
              ),
            ),
          )
      ).toList(),
      onChanged: (EqualityOperator? value){
        setState(() {
          selectedOperator = value;
          widget.updateEqualityOperatorCallback(value);
        });
      },
      icon: Visibility(
          visible: selectedOperator == EqualityOperator.blank,
          child: const Icon(Icons.arrow_drop_down_outlined)
      ),
      iconEnabledColor: widget.theme.themeData.primaryColorDark,
    );
  }
}


/// [Widget] to display an [EqualityQuery]
class EqualityQueryWidget extends StatefulWidget {
  /// Theme for the app.
  final ChartTheme theme;
  /// The [EqualityQuery] to display.
  final EqualityQuery query;
  /// The dispatcher for query updates.
  final QueryUpdateCallback dispatch;

  const EqualityQueryWidget({
    super.key,
    required this.theme,
    required this.query,
    required this.dispatch,
  });

  @override
  EqualityQueryWidgetState createState() => EqualityQueryWidgetState();
}


/// [State] for am [EqualityQueryWidget].
class EqualityQueryWidgetState extends State<EqualityQueryWidget> {
  /// [TextEditingController] for the left value (if a left [EqualityOperator] exists.
  TextEditingController? leftController;
  /// [TextEditingController] for the right value (if a right [EqualityOperator] exists.
  TextEditingController? rightController;
  /// Shortcut to [EqualityQueryWidget.query].
  EqualityQuery get query => widget.query;
  /// Shortcut to [EqualityQueryWidget.theme].
  ChartTheme get theme => widget.theme;

  /// Update the [EqualityQuery.leftCondition].
  void addLeftCondition(EqualityOperator? operator){
    if(operator == null){
      query.leftCondition = null;
    } else {
      query.leftCondition = EqualityCondition(
          operator: operator,
          value: query.bounds == null ? 0 : query.bounds!.min,
      );
    }
    widget.dispatch(const QueryUpdate());
    setState(() {});
  }

  /// Update the [EqualityQuery.rightCondition].
  void addRightCondition(EqualityOperator? operator){
    if(operator == null){
      query.rightCondition = null;
    } else {
      query.rightCondition = EqualityCondition(
        operator: operator,
        value: query.bounds == null ? 0 : query.bounds!.max,
      );
    }
    widget.dispatch(const QueryUpdate());
    setState(() {});
  }

  dynamic textToValue(dynamic value){
    SchemaField field = query.columnField;
    if(field.isString){
      return value;
    }
    if(field.isDateTime){
      throw UnimplementedError("Dates have not yet been implemented");
    }
    return num.parse(value);
  }

  @override
  Widget build(BuildContext context){
    List<Widget> children = [];
    if(query.leftCondition != null){
      // Add a TextField for the left (<, <=) condition
      leftController ??= TextEditingController(text: query.leftCondition!.value.toString());
      EqualityCondition condition = EqualityCondition(
        operator: query.leftCondition!.operator,
        value: textToValue(leftController!.value.text),
      );
      children.add(SizedBox(
        width: 100,
        child: TextField(
          controller: leftController,
          decoration: theme.queryTextDecoration,
          onChanged: (String value){
            setState(() {
              query.leftCondition = condition;
            });
          },
        ),
      ));
      children.add(SizedBox(width: theme.querySpacerWidth));
    }

    if(!query.columnField.isString){
      // Numbers and dates can have a left condition, so add an operator here
      children.add(EqualityOperatorWidget(
        theme: theme,
        operator: EqualityOperator.blank,
        availableOperators: const {EqualityOperator.lt, EqualityOperator.lte, EqualityOperator.blank},
        updateEqualityOperatorCallback: addLeftCondition,
      ));
    }

    // Add the label for the column field
    children.add(SizedBox(width: theme.querySpacerWidth));
    children.add(Text(query.columnField.name, style: theme.queryStyle));
    children.add(SizedBox(width: theme.querySpacerWidth));

    if(!query.columnField.isString){
      // Numbers and dates can have <, <= operators
      children.add(EqualityOperatorWidget(
        theme: theme,
        operator: EqualityOperator.blank,
        availableOperators: const {
          EqualityOperator.eq, EqualityOperator.neq,
          EqualityOperator.lt, EqualityOperator.lte,
          EqualityOperator.blank}
        ,
        updateEqualityOperatorCallback: addRightCondition,
      ));
    } else {
      // Strings can only have = and != operators and string operators
      children.add(EqualityOperatorWidget(
        theme: theme,
        operator: EqualityOperator.blank,
        availableOperators: const {
          EqualityOperator.eq,
          EqualityOperator.neq,
          EqualityOperator.blank,
          EqualityOperator.startsWith,
          EqualityOperator.endsWith,
          EqualityOperator.contains,
        },
        updateEqualityOperatorCallback: addRightCondition,
      ));
    }
    children.add(SizedBox(width: theme.querySpacerWidth));

    if(query.rightCondition != null){
      // Create a TextField for the right condition value
      rightController ??= TextEditingController(text: query.rightCondition!.value.toString());
      EqualityCondition condition = EqualityCondition(
        operator: query.rightCondition!.operator,
        value: textToValue(rightController!.value.text),
      );
      children.add(SizedBox(
        width: 100,
        child: TextField(
          controller: rightController,
          decoration: theme.queryTextDecoration,
          onChanged: (String value){
            setState(() {
              query.rightCondition = condition;
            });
          },
        ),
      ));
    }

    // Add a trash can button to delete this query
    children.add(IconButton(
      icon: const Icon(Icons.delete, color: Colors.redAccent),
      onPressed: (){
        widget.dispatch(RemoveQuery(query: query));
      },
    ));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}


/// Widget to display an [EqualityOperator] in an [EqualityQueryWidget].
class QueryOperatorWidget extends StatefulWidget {
  /// Theme for the app.
  final ChartTheme theme;
  /// Operator to display
  final QueryOperator operator;
  /// Available operators to select from.
  /// This is different depending on whether this is a left or right operator,
  /// and the data type
  final Set<QueryOperator> availableOperators;
  /// Callback to the [EqualityQueryWidget] to update the operator.
  final UpdateQueryOperatorCallback updateQueryOperatorCallback;

  const QueryOperatorWidget({
    super.key,
    required this.theme,
    required this.operator,
    required this.availableOperators,
    required this.updateQueryOperatorCallback,
  });

  @override
  QueryOperatorWidgetState createState() => QueryOperatorWidgetState();
}


/// [State] for an [EqualityOperatorWidget].
class QueryOperatorWidgetState extends State<QueryOperatorWidget> {

  @override
  Widget build(BuildContext context){
    return DropdownButton<QueryOperator>(
      value: widget.operator,
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      items: widget.availableOperators.map((QueryOperator operator)=>
          DropdownMenuItem(
            value: operator,
            child: Container(
              constraints: const BoxConstraints(minWidth: kMinInteractiveDimension),
              child: Text(
                operator.symbol,
                style: widget.theme.queryOperatorStyle,
                textAlign: TextAlign.center,
              ),
            ),
          )
      ).toList(),
      onChanged: (QueryOperator? value){
        setState(() {
          widget.updateQueryOperatorCallback(value);
        });
      },
      icon: const Icon(Icons.arrow_drop_down_outlined),
      iconEnabledColor: widget.theme.themeData.primaryColorDark,
    );
  }
}


/// Widget to display a [ParentQuery] and all of its children.
class ParentQueryWidget extends StatefulWidget {
  /// Theme for the app.
  final ChartTheme theme;
  /// The [ParentQuery] instance that this [Widget] displays.
  final ParentQuery query;
  /// Callback to pass a [QueryUpdate].
  final QueryUpdateCallback dispatch;
  /// The depth of this query in the tree
  /// (used to alternate the [Container] [Color].
  final int depth;

  const ParentQueryWidget({
    super.key,
    required this.theme,
    required this.query,
    required this.dispatch,
    required this.depth,
  });

  @override
  ParentQueryWidgetState createState() => ParentQueryWidgetState();
}


class ParentQueryWidgetState extends State<ParentQueryWidget> {
  ChartTheme get theme => widget.theme;
  ParentQuery get query => widget.query;
  QueryUpdateCallback get dispatch => widget.dispatch;

  /// Update the operator for this query
  void updateOperator(QueryOperator? operator){
    if(operator == QueryOperator.blank){
      dispatch(RemoveQuery(query: query));
    }
    if(operator != query.operator){
      setState(() {
        query.operator = operator!;
      });
    }
  }

  /// To be used when the [Column] is changed changed to an [AnimatedList].
  Widget _buildItem(BuildContext context, int index, Animation<double> animation){
    return query.children[index].createWidget(theme: theme, dispatch: dispatch, depth: widget.depth + 1);
  }

  @override
  Widget build(BuildContext context){
    List<Widget> children = query.children.map((Query query) => query.createWidget(
        theme: theme, dispatch: dispatch, depth: widget.depth + 1)
    ).toList();

    return Row(
      children: [
        // allow the user to select an operator
        QueryOperatorWidget(
            theme: theme,
            operator: query.operator,
            availableOperators: const {QueryOperator.and, QueryOperator.or, QueryOperator.xor, QueryOperator.blank},
            updateQueryOperatorCallback: updateOperator
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        )
      ],
    );
  }
}


/// Allow the user to select available columns for a query
class NewQueryWidget extends StatefulWidget {
  /// The theme for the app.
  final ChartTheme theme;
  /// Available column names to choose from.
  final List<String> columns;
  /// Dispatcher to pass updates to the full expression.
  final QueryUpdateCallback dispatch;

  const NewQueryWidget({
    super.key,
    required this.theme,
    required this.columns,
    required this.dispatch,
  });

  @override
  NewQueryWidgetState createState() => NewQueryWidgetState();
}


/// [State] for teh [NewQueryWidget].
class NewQueryWidgetState extends State<NewQueryWidget> {
  /// [TextEditingController] for the column name.
  TextEditingController columnController = TextEditingController();

  @override
  Widget build(BuildContext context){
    // Populate a drop-down menu with the available columns
    final List<DropdownMenuEntry<String>> columnEntries = widget.columns.map((String column) =>
        DropdownMenuEntry(value: column, label: column)
    ).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        decoration: BoxDecoration(
          color: widget.theme.themeData.colorScheme.background,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownMenu<String>(
              controller: columnController,
              enableFilter: true,
              leadingIcon: const Icon(Icons.search),
              label: const Text("column"),
              dropdownMenuEntries: columnEntries,
              inputDecorationTheme: widget.theme.queryTextDecorationTheme,
              onSelected: (String? column) {
                setState(() {

                });
              },
            ),
            IconButton(
                icon: const Icon(Icons.clear, color: Colors.redAccent),
                tooltip: "Clear column",
                onPressed: (){
                  setState((){
                    columnController.clear();
                    columnController.clearComposing();
                  });
                }
            ),
            IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                tooltip: "Create query entry for '${columnController.value}'",
                onPressed: (){
                  widget.dispatch(AddNewQuery(columnName: columnController.text));
                  setState((){
                  });
                }
            ),
          ]
        )
      ),
    );
  }
}

/// [Widget] to edit a full [Query] expression
class QueryEditor extends StatefulWidget {
  final ChartTheme theme;
  final QueryExpression expression;
  final Chart info;
  final Series series;
  final SeriesQueryCallback onCompleted;

  const QueryEditor({
    super.key,
    required this.theme,
    required this.expression,
    required this.info,
    required this.series,
    required this.onCompleted,
  });

  @override
  QueryEditorState createState() => QueryEditorState();
}


/// [State] for a [QueryEditor]/
class QueryEditorState extends State<QueryEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Shortcut to the [ChartTheme]/
  ChartTheme get theme => widget.theme;
  /// Shorcut to the [DataSet].
  DataSet? get dataSet => widget.expression.dataSet;
  /// Shortcut to the [QueryExpression].
  QueryExpression get expression => widget.expression;

  /// Remove a query term from the expression
  void removeQuery({
    required Query query,
    required bool keepChildren,
  }){
    if(query.parent != null){
      if(keepChildren && query is ParentQuery){
        query.parent!.children.addAll(query.children);
      }
      query.parent!.children.remove(query);
      if(query.parent!.children.length == 1){
        removeQuery(query: query.parent!, keepChildren: true);
      }
    } else if(expression.queries.contains(query)){
      if(keepChildren && query is ParentQuery){
        expression.queries.addAll(query.children);
      }
      expression.queries.remove(query);
      if(query is ParentQuery){
        expression.queries.addAll(query.children);
      }
    } else {
      throw QueryError("Cannot find query '$query' in expression");
    }
    setState(() {});
  }

  /// Add a new [EqualityQuery] to the expression
  void addNewQuery(String columnName){
    if(dataSet!.schema.fields.keys.contains(columnName)){
      SchemaField field = dataSet!.schema.fields[columnName]!;
      Bounds? bounds;
      if(!field.isString){
        bounds = Bounds(
          dataSet!.getMin(columnName),
          dataSet!.getMax(columnName),
        );
      }
      expression.queries.add(EqualityQuery(
        columnField: field,
        bounds: bounds,
      ));
    }
    setState(() {});
  }

  void connectQueries(ConnectQueries update){
    Query target = update.target;
    Query query = update.query;
    if(target.parent != null){
      if(query.parent != null){
        query.parent!.children.remove(query);
      }
      target.parent!.children.add(query);
      query.parent = target.parent;
      expression.queries.remove(query);
    } else if(query.parent != null){
      query.parent!.children.add(target);
      target.parent = query.parent;
      expression.queries.remove(target);
    }
    else {
      int targetIndex = expression.queries.indexOf(target);
      int queryIndex =  expression.queries.indexOf(query);
      if(targetIndex <0 || queryIndex < 0){
        throw QueryError("Could not find $target and $query in unattached queries");
      }
      expression.queries.remove(target);
      expression.queries.remove(query);
      Query query1 = target;
      Query query2 = query;
      if(queryIndex < targetIndex){
        query1 = query;
        query2 = target;
      }

      ParentQuery newQuery = ParentQuery(
        children: [query1, query2],
        operator: update.operator,
      );
      query1.parent = newQuery;
      query2.parent = newQuery;

      expression.queries.add(newQuery);
    }
  }

  /// Catch [QueryUpdate] actions.
  void dispatcher(QueryUpdate update){
    if(update is RemoveQuery){
      removeQuery(query: update.query, keepChildren: update.keepChildren);
    } else if(update is AddNewQuery){
      addNewQuery(update.columnName);
    } else if(update is ConnectQueries){
      connectQueries(update);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context){
    List<Widget> children = expression.queries.map((Query query) =>
        query.createWidget(theme: theme, dispatch: dispatcher, depth: 0)
    ).toList();

    if(dataSet != null){
      children.add(NewQueryWidget(
        theme: widget.theme,
        columns: dataSet!.schema.fields.keys.toList(),
        dispatch: dispatcher,
      ));
      children.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: (){
              Navigator.pop(context);
            },
            icon: const Icon(Icons.cancel, color: Colors.red),
          ),
          IconButton(
            onPressed: (){
              if (_formKey.currentState!.validate()) {
                widget.onCompleted(
                  expression.queries.length == 1 ? expression.queries[0] : null
                );
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check_circle, color: Colors.green),
          ),
        ],
      ));
    }

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}


class QueryWrapper extends StatefulWidget{
  final Widget child;
  final Query query;
  final ChartTheme theme;
  final QueryUpdateCallback dispatch;
  final int depth;

  const QueryWrapper({
    super.key,
    required this.child,
    required this.query,
    required this.theme,
    required this.dispatch,
    required this.depth,
  });

  @override
  QueryWrapperState createState() => QueryWrapperState();
}


class QueryWrapperState extends State<QueryWrapper> {
  ChartTheme get theme => widget.theme;
  OverlayEntry? wireWidget;
  late Offset initialPosition;
  late Offset currentPosition;

  Color get color => widget.query is EqualityQuery
      ? theme.themeData.colorScheme.primaryContainer
      : theme.operatorQueryColor(widget.depth);

  @override
  Widget build(BuildContext context){
    return DragTarget<Query>(
      onWillAccept: (Query? query) => query != null && query != widget.query,
      onAccept: (Query? query){
        if(query != null){
          widget.dispatch(ConnectQueries(
            target: widget.query,
            query: query,
          ));
        }
      },
      builder: (
          BuildContext context,
          List<dynamic> accepted,
          List<dynamic> rejected,
      ) => AnimatedContainer(
        margin: EdgeInsets.all(theme.querySpacerWidth/2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        duration: theme.animationSpeed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Draggable<Query>(
              data: widget.query,
              feedback: Center(
                  child: Container(
                    width: kMinInteractiveDimension,
                    height: kMinInteractiveDimension,
                    decoration: BoxDecoration(
                      color: theme.themeData.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                  )
              ),
              childWhenDragging: Center(
                child: Container(
                  width: kMinInteractiveDimension,
                  height: kMinInteractiveDimension,
                  decoration: BoxDecoration(
                    color: theme.themeData.colorScheme.secondary.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              child: Center(
                child: Container(
                  width: kMinInteractiveDimension,
                  height: kMinInteractiveDimension,
                  decoration: BoxDecoration(
                    color:accepted.isEmpty ? theme.themeData.colorScheme.secondary : theme.wireColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            SizedBox(width: theme.querySpacerWidth),
            widget.child,
          ],
        ),
      ),
    );
  }
}


class WirePainter extends CustomPainter {
  final ChartTheme theme;
  final Offset initialPosition;
  final Offset currentPosition;

  WirePainter({
    required this.theme,
    required this.initialPosition,
    required this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size){
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.majorTickWidth
      ..color = theme.wireColor;

    canvas.drawLine(initialPosition, currentPosition, paint);
  }

  @override
  bool shouldRepaint(WirePainter oldDelegate) =>
      initialPosition != oldDelegate.initialPosition
          || currentPosition != oldDelegate.currentPosition
          || theme != oldDelegate.theme;
}


class WireWidget extends StatelessWidget {
  final ChartTheme theme;
  final Offset initialPosition;
  final Offset currentPosition;

  const WireWidget({
    super.key,
    required this.theme,
    required this.initialPosition,
    required this.currentPosition,
  });

  @override
  Widget build(BuildContext context){
    Offset topLeft = Offset(
      math.min(initialPosition.dx, currentPosition.dx),
      math.min(initialPosition.dy, currentPosition.dy),
    );
    Offset bottomRight = Offset(
      math.max(initialPosition.dx, currentPosition.dx),
      math.max(initialPosition.dy, currentPosition.dy),
    );
    return Positioned(
      left: math.min(initialPosition.dx, currentPosition.dx),
      top: math.min(initialPosition.dy, currentPosition.dy),
      child: SizedBox(
          width: bottomRight.dx - topLeft.dx,
          height: bottomRight.dy - topLeft.dy,
          child: CustomPaint(
            painter: WirePainter(
              theme: theme,
              initialPosition: initialPosition-topLeft,
              currentPosition: currentPosition-topLeft,
            ),
          )
      ),
    );
  }
}
