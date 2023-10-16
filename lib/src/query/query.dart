import 'package:flutter/material.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/core/utils.dart';
import 'package:rubin_chart/src/query/update.dart';
import 'package:rubin_chart/src/query/widget.dart';
import 'package:rubin_chart/src/state/theme.dart';


/// Available operators to use to check for equality/inequality.
/// Note that there are no greater than operators, since the
/// [EqualityQueryWidget] is designed such that it doesn't need them.
enum EqualityOperator {
  eq("="),
  neq("\u2260"),
  lt("<"),
  lte("\u2264"),
  blank(" "),
  startsWith("starts with"),
  endsWith("ends with"),
  contains("contains");

  const EqualityOperator(this.symbol);

  /// The symbol representing the operator
  final String symbol;
}

/// A boolean operator in a query to combine two or more query terms.
enum QueryOperator {
  and("\u2227", "AND"),
  or("\u2228", "OR"),
  xor("\u2295", "XOR"),
  not("\u00AC", "NOT"),
  blank(" ", "");

  const QueryOperator(this.symbol, this.name);
  /// A symbol that represents the operator
  final String symbol;
  /// The name of the operator
  final String name;
}


/// An error in a query.
class QueryError implements Exception{
  QueryError(this.message);

  /// Message to be displayed when this [Exception] is thrown.
  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}


/// THe base class for queries.
abstract class Query<T> {
  Query({this.parent});

  ParentQuery? parent;

  /// The indices that pass the query.
  Set<T> getIndices({
    required DataSet<T> dataSet,
  });

  /// Create a [Widget] to display the current query.
  Widget createWidget({
    required ChartTheme theme,
    required QueryUpdateCallback dispatch,
    required int depth,
  }) => QueryWrapper(
    theme: theme,
    query: this,
    dispatch: dispatch,
    depth: depth,
    child: createInternalWidget(theme: theme, dispatch: dispatch, depth: depth),
  );

  /// Create a [Widget] to display the current query.
  Widget createInternalWidget({
    required ChartTheme theme,
    required QueryUpdateCallback dispatch,
    required int depth,
  });
}


/// An equality/inequality condition in an [EqualityQuery].
class EqualityCondition {
  /// The equality/inequality operator.
  final EqualityOperator operator;
  /// The value to check against.
  final dynamic value;

  EqualityCondition({
    required this.operator,
    required this.value,
  });

  /// Check to see if a [value] satisfies this [EqualityCondition].
  bool check(value, [isLeft=false]){
    if(value == null){
      // Sometimes an entry might not be present for a given row.
      return false;
    }
    late final bool result;
    if(isLeft){
      if(operator == EqualityOperator.lt){
        result = this.value < value;
      } else if(operator == EqualityOperator.lte){
        result = this.value <= value;
      } else {
        throw QueryError("$operator cannot be used on the left hand side");
      }
    } else {
      if(operator == EqualityOperator.eq){
        result = value == this.value;
      } else if(operator == EqualityOperator.neq){
        result = value != this.value;
      } else if(operator == EqualityOperator.lt){
        result = value < this.value;
      } else if(operator == EqualityOperator.lte){
        result = value <= this.value;
      } else if(operator == EqualityOperator.startsWith){
        result = value.startsWith(this.value);
      } else if(operator == EqualityOperator.endsWith){
        result = value.endsWith(this.value);
      } else if(operator == EqualityOperator.contains){
        result = value.contains(this.value);
      } else {
        throw QueryError("$operator cannot be used on the right hand side");
      }
    }
    return result;
  }
}


/// A query that checks that values satisfy a left or right [EqualityCondition].
class EqualityQuery<T> extends Query<T>{
  /// This is a condition to the left side of an equality/inequality.
  EqualityCondition? leftCondition;
  /// This is a condition to the right side of an equality/inequality.
  EqualityCondition? rightCondition;
  /// The [SchemaField] for the column that is being checked.
  final SchemaField columnField;
  /// Bounds of the column (for numerical types and dates).
  final Bounds? bounds;

  EqualityQuery({
    super.parent,
    this.leftCondition,
    this.rightCondition,
    required this.columnField,
    this.bounds,
  });

  /// Select all of the indices from [dataSet] that match the [leftCondition] and [rightCondition].
  @override
  Set<T> getIndices({
    required DataSet<T> dataSet,
  }) {
    Set<T> result = {};
    for(MapEntry<T, Map<String, dynamic>> entry in dataSet.data.entries){
      dynamic value = entry.value[columnField.name];
      if((leftCondition == null || leftCondition!.check(value, true)) &&
          (rightCondition == null || rightCondition!.check(value, false))
      ){
        result.add(entry.key);
      }
    }
    return result;
  }

  @override
  Widget createInternalWidget({
    required ChartTheme theme,
    required QueryUpdateCallback dispatch,
    required int depth,
  }) => EqualityQueryWidget(
    theme: theme,
    query: this,
    dispatch: dispatch,
  );

  @override
  String toString(){
    if(leftCondition == null && rightCondition == null){
      return "true";
    }
    String result = "";
    if(leftCondition != null){
      result += "${leftCondition!.value}${leftCondition!.operator.symbol}";
    }
    result += columnField.name;
    if(rightCondition != null){
      result += "${rightCondition!.operator.symbol}${rightCondition!.value}";
    }
    return result;
  }
}


/// Apply a boolean negation to a set of indices.
Set<T> _notOperation<T>({
  required DataSet<T> dataSet,
  required List<Query<T>> children,
}) => dataSet.index.toSet().difference(children[0].getIndices(dataSet: dataSet));


/// Apply a boolean AND operation to a set of indices
Set<T> _andOperation<T>({
  required DataSet<T> dataSet,
  required List<Query<T>> children,
}){
  Set<T> result = children[0].getIndices(dataSet: dataSet);
  for(Query<T> child in children.sublist(1)){
    result = result.intersection(child.getIndices(dataSet: dataSet));
  }
  return result;
}


/// Apply a boolean OR operation to a set of indices
Set<T> _orOperation<T>({
  required DataSet<T> dataSet,
  required List<Query<T>> children,
}){
  Set<T> result = children[0].getIndices(dataSet: dataSet);
  for(Query<T> child in children.sublist(1)){
    result = result.union(child.getIndices(dataSet: dataSet));
  }
  return result;
}


/// Apply a boolean XOR operation to a set of indices
Set<T> _xorOperation<T>({
  required DataSet<T> dataSet,
  required List<Query<T>> children,
}){
  Set<T> result = children[0].getIndices(dataSet: dataSet);
  for(Query<T> child in children.sublist(1)){
    Set<T> childIndices = child.getIndices(dataSet: dataSet);
    result = result.union(childIndices).difference(result.intersection(childIndices));
  }
  return result;
}


/// A query that combines multiple child [Query] instances.
/// These can either be other [ParentQuery] instances or
/// [EqualityQuery]s.
class ParentQuery<T> extends Query<T> {
  /// The queries combined using the operator of the parent query.
  final List<Query<T>> children;
  QueryOperator operator;

  ParentQuery({
    super.parent,
    required this.children,
    required this.operator,
  }){
    for(Query<T> child in children){
      child.parent = this;
    }
  }

  @override
  Widget createInternalWidget({
    required ChartTheme theme,
    required QueryUpdateCallback dispatch,
    required int depth,
  }) => ParentQueryWidget(
    theme: theme,
    query: this,
    dispatch: dispatch,
    depth: depth,
  );

  @override
  Set<T> getIndices({
    required DataSet<T> dataSet,
  }) {
    if(operator == QueryOperator.not){
      return _notOperation(dataSet: dataSet, children: children);
    } else if(operator == QueryOperator.and){
      return _andOperation(dataSet: dataSet, children: children);
    } else if(operator == QueryOperator.or){
      return _orOperation(dataSet: dataSet, children: children);
    } else if(operator == QueryOperator.xor){
      return _xorOperation(dataSet: dataSet, children: children);
    }
    throw QueryError("Unexpected query operator $operator");
  }

  @override
  String toString(){
    String result = "${operator.symbol}(";
    for(Query child in children){
      result += "$child";
      if(child != children.last){
        result += ",";
      }
    }
    result += ")";
    return result;
  }
}


class QueryExpression<T> {
  List<Query<T>> queries;
  final DataCenter dataCenter;
  final String dataSetName;

  QueryExpression({
    required this.queries,
    required this.dataCenter,
    required this.dataSetName,
  });

  DataSet<T>? get dataSet => dataCenter.dataSets[dataSetName] as DataSet<T>?;
}
