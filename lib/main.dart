import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:rubin_chart/rubin_data.dart';
import 'package:rubin_chart/src/core/data.dart';
import 'package:rubin_chart/src/state/action.dart';
import 'package:rubin_chart/src/state/app.dart';
import 'package:rubin_chart/src/state/theme.dart';
import 'package:rubin_chart/src/core/workspace.dart';
import 'package:rubin_chart/src/state/time_machine.dart';
import 'package:rubin_chart/src/state/workspace.dart';


void main() {
  DataCenter dataCenter = DataCenter();
  runApp(DemoApp(dataCenter: dataCenter));
}


class DemoApp extends StatefulWidget {
  final DataCenter dataCenter;
  const DemoApp({super.key, required this.dataCenter});

  @override
  DemoAppState createState() => DemoAppState();
}


class DemoAppState extends State<DemoApp> {
  final StreamController<DataCenterUpdate> streamController = StreamController.broadcast();

  @override
  initState(){
    super.initState();
    loadNightlyData(DateTime(2023, 3, 15)).then((dataSet){
      widget.dataCenter.addDataSet(dataSet);
      developer.log("Nightly data loaded", name: "rubin_chart.io");
    });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    ThemeData themeData = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF058b8c)),
      useMaterial3: true,
    );
    themeData = themeData.copyWith(scaffoldBackgroundColor: themeData.colorScheme.secondaryContainer);

    ChartTheme theme = ChartTheme(
      themeData: themeData,
    );

    Workspace workspace = Workspace(theme: theme);

    // By default use scalar algebra over the complex field
    Store<AppState> store = Store<AppState>(
      appReducer,
      initialState: AppState(
        timeMachine: TimeMachine.init(workspace),
      ),
      distinct: true,
    );

    Size screenSize = MediaQuery.of(context).size;

    return StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        title: 'Rubin Chart Demo',
        theme: theme.themeData,
        home: Scaffold(
          body: StoreConnector<AppState, _WorkspaceViewModel>(
            distinct: true,
            converter: (store) => _WorkspaceViewModel(appState: store.state, dispatch: store.dispatch),
            builder: (BuildContext context, _WorkspaceViewModel model) => WorkspaceViewer(
              size: screenSize,
              workspace: model.info,
              dataCenter: widget.dataCenter,
              dispatch: model.dispatch,
            ),
          ),
        ),
      ),
    );
  }
}


class _WorkspaceViewModel {
  final AppState appState;
  final DispatchAction dispatch;

  const _WorkspaceViewModel({
    required this.appState,
    required this.dispatch,
  });
  /// The current state of the app
  AppState get state => appState;

  @override
  bool operator ==(dynamic other) => other is _WorkspaceViewModel && state == other.state;

  @override
  int get hashCode => state.hashCode;

  Workspace get info => appState.timeMachine.currentState;
}
