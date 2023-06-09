import 'package:rubin_chart/src/query/query.dart';

/// An update to a query
class QueryUpdate {
  const QueryUpdate();
}


/// Replace a [Query] in a full query expression
class RemoveQuery extends QueryUpdate {
  /// The query to remove
  final Query query;
  /// Whether to keep or remove children of this [Query].
  final bool keepChildren;

  const RemoveQuery({
    required this.query,
    this.keepChildren = false,
  });
}


/// Add a new [EqualityQuery] to the expression.
class AddNewQuery extends QueryUpdate {
  /// The name of the column for the query.
  final String columnName;

  const AddNewQuery({required this.columnName});
}


/// Connect two queries using a boolean operation
class ConnectQueries extends QueryUpdate {
  /// The target [Query].
  final Query target;
  /// The [Query] that is being dragged.
  final Query query;
  /// The operator to use while connecting them.
  final QueryOperator operator;

  ConnectQueries({
    required this.target,
    required this.query,
    this.operator = QueryOperator.and,
  });
}


/// A callback function to update a query
typedef QueryUpdateCallback = void Function(QueryUpdate update);
