import 'dart:io';

import 'package:rubin_chart/src/core/unit.dart';
import 'package:rubin_chart/src/core/utils.dart';
import 'package:rubin_chart/src/chart/series.dart';

int _nextDataset = 0;


class DataAccessException implements IOException{
  DataAccessException(this.message);

  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}


class SchemaField {
  final String name;
  final String dataSetName;
  final Unit? unit;
  final String? description;

  const SchemaField({
    required this.name,
    required this.dataSetName,
    this.unit,
    this.description,
  });

  /// Return the [SchemaField] label to be shown (for example as a [PlotAxis] label.
  String get asLabel => unit == null
    ? name
    : "$name ($unit)";

  @override
  String toString() => "SchemaField<$unit>($name, $unit)";

  bool get isString => unit?.base == BaseUnit.string;
  bool get isDateTime => unit?.base == BaseUnit.date;
  bool get isNumber => !isString && !isDateTime;
}


typedef ExtremaCallback<T> = bool Function(T lhs, T rhs);


bool _numericalLessThan<T extends num>(T lhs, T rhs) => lhs < rhs;
bool _numericalGreaterThan<T extends num>(T lhs, T rhs) => lhs > rhs;
bool _dateTimeLessThan<T extends DateTime>(T lhs, T rhs) => lhs.isBefore(rhs);
bool _dateTimeGreaterThan<T extends DateTime>(T lhs, T rhs) => lhs.isAfter(rhs);
bool _stringLessThan<T extends String>(T lhs, T rhs) => lhs.compareTo(rhs) < 0;
bool _stringGreaterThan<T extends String>(T lhs, T rhs) => lhs.compareTo(rhs) > 0;


K _getExtremaArg<K, T>({
  required Map<K, Map<String, dynamic>> data,
  required String columnName,
  required ExtremaCallback<T> comparison,
}){
  K key = data.keys.first;
  T? result = data.values.first[columnName];

  for(MapEntry<K, Map<String, dynamic>> entry in data.entries){
    T? value = entry.value[columnName];
    if(result == null || (value != null && comparison(value, result))){
      result = value;
      key = entry.key;
    }
    //print("result: $result, value: $value");
  }
  return key;
}

class Schema {
  final Map<String, SchemaField> fields;
  const Schema(this.fields);

  static Schema fromFields(List<SchemaField> fields) =>
      Schema({for (SchemaField field in fields) field.name: field});
}


class DataSet<T> {
  final int id;
  final String name;
  final Schema schema;
  final Map<T, Map<String, dynamic>> data;

  DataSet._({
    required this.id,
    required this.name,
    required this.schema,
    required this.data,
  });

  static DataSet<T> init<T>({
    required String name,
    required Schema schema,
    required Map<T, Map<String, dynamic>> data,
  }) => DataSet._(
    id: _nextDataset++,
    name: name,
    schema: schema,
    data: data,
  );

  int get length => data.length;

  List<T> get index => data.keys.toList();

  @override
  String toString() => "DataSet<${data.length} entries>";

  T getArgMin(String columnName){
    SchemaField field = schema.fields[columnName]!;
    if(field.isNumber ){
      return _getExtremaArg(data: data, columnName: columnName, comparison: _numericalLessThan);
    } else if(field.isDateTime){
      return _getExtremaArg(data: data, columnName: columnName, comparison: _dateTimeLessThan);
    } else if(field.isString){
      return _getExtremaArg(data: data, columnName: columnName, comparison: _stringLessThan);
    }
    throw UnimplementedError("Field type ${field.unit} is not yet implemented");
  }

  dynamic getMin(String columnName) => data[getArgMin(columnName)]![columnName];

  T getArgMax(String columnName){
    SchemaField field = schema.fields[columnName]!;
    if(field.isNumber ){
      return _getExtremaArg(data: data, columnName: columnName, comparison: _numericalGreaterThan);
    } else if(field.isDateTime){
      return _getExtremaArg(data: data, columnName: columnName, comparison: _dateTimeGreaterThan);
    } else if(field.isString){
      return _getExtremaArg(data: data, columnName: columnName, comparison: _stringGreaterThan);
    }
    throw UnimplementedError("Field type ${field.unit} is not yet implemented");
  }

  dynamic getMax(String columnName) => data[getArgMax(columnName)]![columnName];

  Set<T> getValid(Series series){
    // Get all of the indices that pass the query
    final Set indices = {};
    if(series.query != null){
      indices.addAll(series.query!.getIndices(dataSet: this));
    } else {
      indices.addAll(data.keys.toSet());
    }

    // Check that those indices also have valid entries for the columns in the [Series].
    final Set<T> result = {};
    for(T index in indices){
      bool isValid = true;
      for(SchemaField field in series.fields){
        if(data[index]![field.name] == null){
          isValid = false;
        }
      }
      if(isValid){
        result.add(index);
      }
    }
    return result;
  }

  Bounds getBounds(String columnName) => Bounds(getMin(columnName).toDouble(), getMax(columnName).toDouble());
}


class DataCenterUpdate {}


class DataSetLoaded extends DataCenterUpdate {
  DataSet dataSet;
  DataSetLoaded({required this.dataSet});
}


class DataCenter {
  final Map<String, DataSet> _dataSets = {};

  DataCenter();

  Map<String, DataSet> get dataSets => {..._dataSets};

  void addDataSet(DataSet dataSet){
    _dataSets[dataSet.name] = dataSet;
  }

  Map<String, Bounds> getNumericalBounds(Series series){
    Map<String, Bounds> result = {};
    DataSet dataSet = dataSets[series.dataSetName]!;

    List<double> min = [];
    List<double> max = [];
    for(int i=0; i<series.fields.length; i++){
      min.add(double.infinity);
      max.add(-double.infinity);
    }

    for(Map<String, dynamic> record in dataSet.data.values){
      bool isValid = true;
      for(SchemaField field in series.fields) {
        if (record[field.name] == null) {
          isValid = false;
        }
      }
      if(isValid){
        for(int c=0; c<series.fields.length; c++){
          String columnName = series.fields[c].name;
          dynamic x = record[columnName];
          if(x.isFinite){
            if(x < min[c]){
              min[c] = x.toDouble();
            }
            if(x > max[c]){
              max[c] = x.toDouble();
            }
          }
        }
      }
    }

    for(int i =0; i<min.length; i++){
      String columnName = series.fields[i].name;
      result[columnName] = Bounds(min[i], max[i]);
    }
    return result;
  }

  /// Check if two [SchemaField]s are compatible
  bool isFieldCompatible(SchemaField field1, SchemaField field2) => field1.unit?.base == field2.unit?.base;

  @override
  String toString() => "DataCenter:[${dataSets.keys}]";
}
