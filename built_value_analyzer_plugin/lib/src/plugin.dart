import 'dart:async';

// ignore: implementation_imports
import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/dart/analysis/driver_based_analysis_context.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:built_value_analyzer_plugin/src/checker.dart';

/// Analyzer plugin for built_value.
///
/// Surfaces the same errors as the generator at compile time, with fixes
/// where possible.
class BuiltValueAnalyzerPlugin extends ServerPlugin {
  final Checker checker = Checker();

  BuiltValueAnalyzerPlugin(ResourceProvider provider) : super(provider);

  @override
  AnalysisDriverGeneric createAnalysisDriver(plugin.ContextRoot contextRoot) {
    final rootPath = contextRoot.root;
    final locator =
    ContextLocator(resourceProvider: resourceProvider).locateRoots(
      includedPaths: [rootPath],
      excludedPaths: contextRoot.exclude,
      optionsFile: contextRoot.optionsFile,
    );

    if (locator.isEmpty) {
      final error = StateError('Unexpected empty context');
      channel.sendNotification(plugin.PluginErrorParams(
        true,
        error.message,
        error.stackTrace.toString(),
      ).toNotification());

      throw error;
    }

    final builder = ContextBuilder(resourceProvider: resourceProvider);
    final context = builder.createContext(contextRoot: locator.first)
    as DriverBasedAnalysisContext;
    final dartDriver = context.driver;
   // final config = _createConfig(dartDriver, rootPath);

 /*   if (config == null) {
      return dartDriver;
    }*/

    // Temporary disable deprecation check
    //
    // final deprecations = checkConfigDeprecatedOptions(
    //   config,
    //   deprecatedOptions,
    //   contextRoot.optionsFile!,
    // );
    // if (deprecations.isNotEmpty) {
    //   channel.sendNotification(plugin.AnalysisErrorsParams(
    //     contextRoot.optionsFile!,
    //     deprecations.map((deprecation) => deprecation.error).toList(),
    //   ).toNotification());
    // }

 /*   runZonedGuarded(
          () {
        dartDriver.results.listen((analysisResult) {
          if (analysisResult is ResolvedUnitResult) {
            _processResult(dartDriver, analysisResult);
          }
        });
      },
          (e, stackTrace) {
        channel.sendNotification(
          plugin.PluginErrorParams(false, e.toString(), stackTrace.toString())
              .toNotification(),
        );
      },
    );*/
    dartDriver.results.listen(_processResult);
    return dartDriver;

/*    var folder = resourceProvider.getFolder(contextRoot.root);
    var root = ContextRootImpl(resourceProvider, folder, contextRoot.exclude,
        pathContext: resourceProvider.pathContext)
      ..optionsFilePath = contextRoot.optionsFile;
    var contextBuilder = ContextBuilderImpl(resourceProvider: resourceProvider);
    contextBuilder.createContext(contextRoot: root,
      scheduler: analysisDriverScheduler,
      byteStore: byteStore,
      performanceLog: performanceLog);
    //  ..fileContentOverlay = fileContentOverlay;
    var result = contextBuilder.buildDriver(root);
    result.results.listen(_processResult);
    return result;*/
  }

  @override
  List<String> get fileGlobsToAnalyze => const ['*.dart'];

  @override
  String get name => 'Built Value';

  // This is the protocol version, not the plugin version. It must match the
  // version of the `analyzer_plugin` package.
  @override
  String get version => '1.0.0-alpha.0';

  @override
  String get contactInfo => 'https://github.com/google/built_value.dart/issues';

  /// Computes errors based on an analysis result and notifies the analyzer.
  // ignore: deprecated_member_use
  void _processResult(ResolvedUnitResult analysisResult) {
    try {
      // If there is no relevant analysis result, notify the analyzer of no errors.
      if (analysisResult.unit == null ||
          analysisResult.libraryElement == null) {
        channel.sendNotification(
            plugin.AnalysisErrorsParams(analysisResult.path, [])
                .toNotification());
      } else {
        // If there is something to analyze, do so and notify the analyzer.
        // Note that notifying with an empty set of errors is important as
        // this clears errors if they were fixed.
        final checkResult = checker.check(analysisResult.libraryElement);
        channel.sendNotification(plugin.AnalysisErrorsParams(
                analysisResult.path, checkResult.keys.toList())
            .toNotification());
      }
    } catch (e, stackTrace) {
      // Notify the analyzer that an exception happened.
      channel.sendNotification(
          plugin.PluginErrorParams(false, e.toString(), stackTrace.toString())
              .toNotification());
    }
  }

  @override
  void contentChanged(String path) {
    super.driverForPath(path).addFile(path);
  }

  @override
  Future<plugin.EditGetFixesResult> handleEditGetFixes(
      plugin.EditGetFixesParams parameters) async {
    try {
      final analysisResult =
          await (driverForPath(parameters.file) as AnalysisDriver)
              .getResult2(parameters.file);

      // Get errors and fixes for the file.
      final checkResult = checker.check((analysisResult as ResolvedUnitResult).libraryElement);

      // Return any fixes that are for the expected file.
      final fixes = <plugin.AnalysisErrorFixes>[];
      for (var error in checkResult.keys) {
        if (error.location.file == parameters.file &&
            checkResult[error].change.edits.single.edits.isNotEmpty) {
          fixes.add(
              plugin.AnalysisErrorFixes(error, fixes: [checkResult[error]]));
        }
      }

      return plugin.EditGetFixesResult(fixes);
    } catch (e, stackTrace) {
      // Notify the analyzer that an exception happened.
      channel.sendNotification(
          plugin.PluginErrorParams(false, e.toString(), stackTrace.toString())
              .toNotification());
      return plugin.EditGetFixesResult([]);
    }
  }
}
