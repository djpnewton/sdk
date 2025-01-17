// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart2js.src.options;

import 'package:front_end/src/api_unstable/dart2js.dart' as fe;

import 'commandline_options.dart' show Flags;
import 'util/util.dart';

/// Options used for controlling diagnostic messages.
abstract class DiagnosticOptions {
  const DiagnosticOptions();

  /// If `true`, warnings cause the compilation to fail.
  bool get fatalWarnings;

  /// Emit terse diagnostics without howToFix.
  bool get terseDiagnostics;

  /// If `true`, warnings are not reported.
  bool get suppressWarnings;

  /// If `true`, hints are not reported.
  bool get suppressHints;

  /// Returns `true` if warnings and hints are shown for all packages.
  bool get showAllPackageWarnings;

  /// Returns `true` if warnings and hints are hidden for all packages.
  bool get hidePackageWarnings;

  /// Returns `true` if warnings should be should for [uri].
  bool showPackageWarningsFor(Uri uri);
}

/// Object for passing options to the compiler. Superclasses are used to select
/// subsets of these options, enabling each part of the compiler to depend on
/// as few as possible.
class CompilerOptions implements DiagnosticOptions {
  /// The entry point of the application that is being compiled.
  Uri entryPoint;

  /// Package root location.
  ///
  /// If not null then [packageConfig] should be null.
  Uri packageRoot;

  /// Location of the package configuration file.
  ///
  /// If not null then [packageRoot] should be null.
  Uri packageConfig;

  /// List of kernel files to load.
  ///
  /// When compiling modularly, this contains kernel files that are needed
  /// to compile a single module.
  ///
  /// When linking, this contains all kernel files that form part of the final
  /// program.
  ///
  /// At this time, this list points to full kernel files. In the future, we may
  /// use a list of outline files for modular compiles, and only use full kernel
  /// files for linking.
  List<Uri> dillDependencies;

  /// Location from which serialized inference data is read.
  ///
  /// If this is set, the [entryPoint] is expected to be a .dill file and the
  /// frontend work is skipped.
  Uri readDataUri;

  /// Location to which inference data is serialized.
  ///
  /// If this is set, the compilation stops after type inference.
  Uri writeDataUri;

  /// Location from which codegen data is read.
  ///
  /// If this is set, the compilation starts at codegen enqueueing.
  Uri readCodegenUri;

  /// Location to which codegen data is serialized.
  ///
  /// If this is set, the compilation stops after code generation.
  Uri writeCodegenUri;

  /// Whether to run only the CFE and emit the generated kernel file in
  /// [outputUri].
  bool cfeOnly = false;

  /// Flag only meant for dart2js developers to iterate on global inference
  /// changes.
  ///
  /// When working on large apps this flag allows to load serialized data for
  /// the app (via --read-data), reuse its closed world, and rerun the global
  /// inference phase (even though the serialized data already contains a global
  /// inference result).
  bool debugGlobalInference = false;

  /// Resolved constant "environment" values passed to the compiler via the `-D`
  /// flags.
  Map<String, String> environment = const <String, String>{};

  /// Flags enabling language experiments.
  Map<fe.ExperimentalFlag, bool> languageExperiments = {};

  /// `true` if CFE performs constant evaluation.
  bool get useCFEConstants =>
      languageExperiments[fe.ExperimentalFlag.constantUpdate2018];

  /// A possibly null state object for kernel compilation.
  fe.InitializedCompilerState kernelInitializedCompilerState;

  /// Whether we allow mocking compilation of libraries such as dart:io and
  /// dart:html for unit testing purposes.
  bool allowMockCompilation = false;

  /// Sets a combination of flags for benchmarking 'production' mode.
  bool benchmarkingProduction = false;

  /// Sets a combination of flags for benchmarking 'experiment' mode.
  bool benchmarkingExperiment = false;

  /// ID associated with this sdk build.
  String buildId = _UNDETERMINED_BUILD_ID;

  /// Whether there is a build-id available so we can use it on error messages
  /// and in the emitted output of the compiler.
  bool get hasBuildId => buildId != _UNDETERMINED_BUILD_ID;

  /// Whether to compile for the server category. This is used to compile to JS
  /// that is intended to be run on server-side VMs like nodejs.
  bool compileForServer = false;

  /// Location where to generate a map containing details of how deferred
  /// libraries are subdivided.
  Uri deferredMapUri;

  /// Whether to apply the new deferred split fixes. The fixes improve on
  /// performance and fix a soundness issue with inferred types. The latter will
  /// move more code to the main output unit, because of that we are not
  /// enabling the feature by default right away.
  ///
  /// When [reportInvalidInferredDeferredTypes] shows no errors, we expect this
  /// flag to produce the same or better results than the current unsound
  /// implementation.
  bool newDeferredSplit = false;

  /// Show errors when a deferred type is inferred as a return type of a closure
  /// or in a type parameter. Those cases cause the compiler today to behave
  /// unsoundly by putting the code in a deferred output unit. In the future
  /// when [newDeferredSplit] is on by default, those cases will be treated
  /// soundly and will cause more code to be moved to the main output unit.
  ///
  /// This flag is presented to help developers find and fix the affected code.
  bool reportInvalidInferredDeferredTypes = false;

  /// Whether to disable inlining during the backend optimizations.
  // TODO(sigmund): negate, so all flags are positive
  bool disableInlining = false;

  /// Disable deferred loading, instead generate everything in one output unit.
  /// Note: the resulting program still correctly checks that loadLibrary &
  /// checkLibrary calls are correct.
  bool disableProgramSplit = false;

  /// Diagnostic option: If `true`, warnings cause the compilation to fail.
  @override
  bool fatalWarnings = false;

  /// Diagnostic option: Emit terse diagnostics without howToFix.
  @override
  bool terseDiagnostics = false;

  /// Diagnostic option: If `true`, warnings are not reported.
  @override
  bool suppressWarnings = false;

  /// Diagnostic option: If `true`, hints are not reported.
  @override
  bool suppressHints = false;

  /// Diagnostic option: List of packages for which warnings and hints are
  /// reported. If `null`, no package warnings or hints are reported. If
  /// empty, all warnings and hints are reported.
  List<String> shownPackageWarnings; // &&&&&

  /// Whether to disable global type inference.
  bool disableTypeInference = false;

  /// Whether to use the trivial abstract value domain.
  bool useTrivialAbstractValueDomain = false;

  /// Whether to disable optimization for need runtime type information.
  bool disableRtiOptimization = false;

  /// Whether to emit a summary of the information used by the compiler during
  /// optimization. This includes resolution details, dependencies between
  /// elements, results of type inference, and data about generated code.
  bool dumpInfo = false;

  /// Whether to use the new dump-info binary format. This will be the default
  /// after a transitional period.
  bool useDumpInfoBinaryFormat = false;

  /// Whether we allow passing an extra argument to `assert`, containing a
  /// reason for why an assertion fails. (experimental)
  ///
  /// This is only included so that tests can pass the --assert-message flag
  /// without causing dart2js to crash. The flag has no effect.
  bool enableAssertMessage = true;

  /// Whether to enable minification
  // TODO(sigmund): rename to minify
  bool enableMinification = false;

  /// Flag to turn off minification even if enabled elsewhere, e.g. via
  /// -O2. Both [enableMinification] and [_disableMinification] can be true, in
  /// which case [_disableMinification] wins.
  bool _disableMinification = false;

  /// Whether to model which native classes are live based on annotations on the
  /// core libraries. If false, all native classes will be included by default.
  bool enableNativeLiveTypeAnalysis = true;

  /// Whether to generate code containing user's `assert` statements.
  bool enableUserAssertions = false;

  /// Whether to generate a source-map file together with the output program.
  bool generateSourceMap = true;

  /// URI of the main output of the compiler.
  Uri outputUri;

  /// Location of the libraries specification file.
  Uri librariesSpecificationUri;

  /// Location of the kernel platform `.dill` files.
  Uri platformBinaries;

  /// URI where the compiler should generate the output source map file.
  Uri sourceMapUri;

  /// The compiler is run from the build bot.
  bool testMode = false;

  /// Whether to trust JS-interop annotations. (experimental)
  bool trustJSInteropTypeAnnotations = false;

  /// Whether to trust primitive types during inference and optimizations.
  bool trustPrimitives = false;

  /// Whether to omit implicit strong mode checks.
  bool omitImplicitChecks = false;

  /// Whether to omit as casts by default.
  bool defaultOmitAsCasts = false;

  /// Whether to omit class type arguments only needed for `toString` on
  /// `Object.runtimeType`.
  bool laxRuntimeTypeToString = false;

  /// What should the compiler do with parameter type assertions.
  ///
  /// This is an internal configuration option derived from other flags.
  CheckPolicy defaultParameterCheckPolicy;

  /// What should the compiler do with implicit downcasts.
  ///
  /// This is an internal configuration option derived from other flags.
  CheckPolicy defaultImplicitDowncastCheckPolicy;

  /// What the compiler should do with a boolean value in a condition context
  /// when the language specification says it is a runtime error for it to be
  /// null.
  ///
  /// This is an internal configuration option derived from other flags.
  CheckPolicy defaultConditionCheckPolicy;

  /// Whether to generate code compliant with content security policy (CSP).
  bool useContentSecurityPolicy = false;

  /// When obfuscating for minification, whether to use the frequency of a name
  /// as an heuristic to pick shorter names.
  bool useFrequencyNamer = true;

  /// Whether to generate source-information from both the old and the new
  /// source-information engines. (experimental)
  bool useMultiSourceInfo = false;

  /// Whether to use the new source-information implementation for source-maps.
  /// (experimental)
  bool useNewSourceInfo = false;

  /// Enable verbose printing during compilation. Includes a time-breakdown
  /// between phases at the end.
  bool verbose = false;

  /// On top of --verbose, enable more verbose printing, like progress messages
  /// during each phase of compilation.
  bool showInternalProgress = false;

  /// Track allocations in the JS output.
  ///
  /// This is an experimental feature.
  bool experimentalTrackAllocations = false;

  /// Experimental part file function generation.
  bool experimentStartupFunctions = false;

  /// Experimental reliance on JavaScript ToBoolean conversions.
  bool experimentToBoolean = false;

  /// Experimental instrumentation to investigate code bloat.
  ///
  /// If [true], the compiler will emit code that logs whenever a method is
  /// called.
  bool experimentCallInstrumentation = false;

  /// Experimental use of the new (Q2 2019) RTI system.
  bool experimentNewRti = false;

  /// The path to the file that contains the profiled allocations.
  ///
  /// The file must contain the Map that was produced by using
  /// [experimentalTrackAllocations] encoded as a JSON map.
  ///
  /// This is an experimental feature.
  String experimentalAllocationsPath;

  /// If specified, a bundle of optimizations to enable (or disable).
  int optimizationLevel = null;

  /// The shard to serialize when using [writeCodegenUri].
  int codegenShard;

  /// The number of shards to serialize when using [writeCodegenUri] or to
  /// deserialize when using [readCodegenUri].
  int codegenShards;

  // -------------------------------------------------
  // Options for deprecated features
  // -------------------------------------------------

  /// Create an options object by parsing flags from [options].
  static CompilerOptions parse(List<String> options,
      {Uri librariesSpecificationUri, Uri platformBinaries}) {
    Map<fe.ExperimentalFlag, bool> languageExperiments =
        _extractExperiments(options);
    if (equalMaps(languageExperiments, fe.defaultExperimentalFlags)) {
      platformBinaries ??= fe.computePlatformBinariesLocation();
    }
    return new CompilerOptions()
      ..librariesSpecificationUri = librariesSpecificationUri
      ..allowMockCompilation = _hasOption(options, Flags.allowMockCompilation)
      ..benchmarkingProduction =
          _hasOption(options, Flags.benchmarkingProduction)
      ..benchmarkingExperiment =
          _hasOption(options, Flags.benchmarkingExperiment)
      ..buildId =
          _extractStringOption(options, '--build-id=', _UNDETERMINED_BUILD_ID)
      ..compileForServer = _hasOption(options, Flags.serverMode)
      ..deferredMapUri = _extractUriOption(options, '--deferred-map=')
      ..newDeferredSplit = _hasOption(options, Flags.newDeferredSplit)
      ..reportInvalidInferredDeferredTypes =
          _hasOption(options, Flags.reportInvalidInferredDeferredTypes)
      ..fatalWarnings = _hasOption(options, Flags.fatalWarnings)
      ..terseDiagnostics = _hasOption(options, Flags.terse)
      ..suppressWarnings = _hasOption(options, Flags.suppressWarnings)
      ..suppressHints = _hasOption(options, Flags.suppressHints)
      ..shownPackageWarnings =
          _extractOptionalCsvOption(options, Flags.showPackageWarnings)
      ..languageExperiments = languageExperiments
      ..disableInlining = _hasOption(options, Flags.disableInlining)
      ..disableProgramSplit = _hasOption(options, Flags.disableProgramSplit)
      ..disableTypeInference = _hasOption(options, Flags.disableTypeInference)
      ..useTrivialAbstractValueDomain =
          _hasOption(options, Flags.useTrivialAbstractValueDomain)
      ..disableRtiOptimization =
          _hasOption(options, Flags.disableRtiOptimization)
      ..dumpInfo = _hasOption(options, Flags.dumpInfo)
      ..useDumpInfoBinaryFormat =
          _hasOption(options, "${Flags.dumpInfo}=binary")
      ..enableMinification = _hasOption(options, Flags.minify)
      .._disableMinification = _hasOption(options, Flags.noMinify)
      ..enableNativeLiveTypeAnalysis =
          !_hasOption(options, Flags.disableNativeLiveTypeAnalysis)
      ..enableUserAssertions = _hasOption(options, Flags.enableCheckedMode) ||
          _hasOption(options, Flags.enableAsserts)
      ..experimentalTrackAllocations =
          _hasOption(options, Flags.experimentalTrackAllocations)
      ..experimentalAllocationsPath = _extractStringOption(
          options, "${Flags.experimentalAllocationsPath}=", null)
      ..experimentStartupFunctions =
          _hasOption(options, Flags.experimentStartupFunctions)
      ..experimentToBoolean = _hasOption(options, Flags.experimentToBoolean)
      ..experimentCallInstrumentation =
          _hasOption(options, Flags.experimentCallInstrumentation)
      ..experimentNewRti = _hasOption(options, Flags.experimentNewRti)
      ..generateSourceMap = !_hasOption(options, Flags.noSourceMaps)
      ..outputUri = _extractUriOption(options, '--out=')
      ..platformBinaries =
          platformBinaries ?? _extractUriOption(options, '--platform-binaries=')
      ..sourceMapUri = _extractUriOption(options, '--source-map=')
      ..omitImplicitChecks = _hasOption(options, Flags.omitImplicitChecks)
      ..defaultOmitAsCasts = _hasOption(options, Flags.omitAsCasts)
      ..laxRuntimeTypeToString =
          _hasOption(options, Flags.laxRuntimeTypeToString)
      ..testMode = _hasOption(options, Flags.testMode)
      ..trustJSInteropTypeAnnotations =
          _hasOption(options, Flags.trustJSInteropTypeAnnotations)
      ..trustPrimitives = _hasOption(options, Flags.trustPrimitives)
      ..useContentSecurityPolicy =
          _hasOption(options, Flags.useContentSecurityPolicy)
      ..useFrequencyNamer =
          !_hasOption(options, Flags.noFrequencyBasedMinification)
      ..useMultiSourceInfo = _hasOption(options, Flags.useMultiSourceInfo)
      ..useNewSourceInfo = _hasOption(options, Flags.useNewSourceInfo)
      ..verbose = _hasOption(options, Flags.verbose)
      ..showInternalProgress = _hasOption(options, Flags.progress)
      ..dillDependencies =
          _extractUriListOption(options, '${Flags.dillDependencies}')
      ..readDataUri = _extractUriOption(options, '${Flags.readData}=')
      ..writeDataUri = _extractUriOption(options, '${Flags.writeData}=')
      ..readCodegenUri = _extractUriOption(options, '${Flags.readCodegen}=')
      ..writeCodegenUri = _extractUriOption(options, '${Flags.writeCodegen}=')
      ..codegenShard = _extractIntOption(options, '${Flags.codegenShard}=')
      ..codegenShards = _extractIntOption(options, '${Flags.codegenShards}=')
      ..cfeOnly = _hasOption(options, Flags.cfeOnly)
      ..debugGlobalInference = _hasOption(options, Flags.debugGlobalInference);
  }

  void validate() {
    // TODO(sigmund): should entrypoint be here? should we validate it is not
    // null? In unittests we use the same compiler to analyze or build multiple
    // entrypoints.
    if (librariesSpecificationUri == null) {
      throw new ArgumentError("[librariesSpecificationUri] is null.");
    }
    if (librariesSpecificationUri.path.endsWith('/')) {
      throw new ArgumentError(
          "[librariesSpecificationUri] should be a file: $librariesSpecificationUri");
    }
    if (packageRoot != null && packageConfig != null) {
      throw new ArgumentError("Only one of [packageRoot] or [packageConfig] "
          "may be given.");
    }
    if (packageRoot != null && !packageRoot.path.endsWith("/")) {
      throw new ArgumentError("[packageRoot] must end with a /");
    }
    if (platformBinaries == null &&
        equalMaps(languageExperiments, fe.defaultExperimentalFlags)) {
      throw new ArgumentError("Missing required ${Flags.platformBinaries}");
    }
  }

  void deriveOptions() {
    if (benchmarkingProduction) {
      trustPrimitives = true;
      omitImplicitChecks = true;
    }

    if (benchmarkingExperiment) {
      // TODO(sra): Set flags implied by '--benchmarking-x'. Initially this will
      // be --experiment-new-rti, and later NNBD.
    }

    if (optimizationLevel != null) {
      if (optimizationLevel == 0) {
        disableInlining = true;
        disableTypeInference = true;
        disableRtiOptimization = true;
      }
      if (optimizationLevel >= 2) {
        enableMinification = true;
        laxRuntimeTypeToString = true;
      }
      if (optimizationLevel >= 3) {
        omitImplicitChecks = true;
      }
      if (optimizationLevel == 4) {
        trustPrimitives = true;
      }
    }

    // Strong mode always trusts type annotations (inferred or explicit), so
    // assignments checks should be trusted.
    if (omitImplicitChecks) {
      defaultParameterCheckPolicy = CheckPolicy.trusted;
      defaultImplicitDowncastCheckPolicy = CheckPolicy.trusted;
      defaultConditionCheckPolicy = CheckPolicy.trusted;
    } else {
      defaultParameterCheckPolicy = CheckPolicy.checked;
      defaultImplicitDowncastCheckPolicy = CheckPolicy.checked;
      defaultConditionCheckPolicy = CheckPolicy.checked;
    }

    if (_disableMinification) {
      enableMinification = false;
    }
  }

  /// Returns `true` if warnings and hints are shown for all packages.
  @override
  bool get showAllPackageWarnings {
    return shownPackageWarnings != null && shownPackageWarnings.isEmpty;
  }

  /// Returns `true` if warnings and hints are hidden for all packages.
  @override
  bool get hidePackageWarnings => shownPackageWarnings == null;

  /// Returns `true` if warnings should be should for [uri].
  @override
  bool showPackageWarningsFor(Uri uri) {
    if (showAllPackageWarnings) {
      return true;
    }
    if (shownPackageWarnings != null) {
      return uri.scheme == 'package' &&
          shownPackageWarnings.contains(uri.pathSegments.first);
    }
    return false;
  }
}

/// Policy for what to do with a type assertion check.
///
/// This enum-like class is used to configure how the compiler treats type
/// assertions during global type inference and codegen.
class CheckPolicy {
  /// Whether the type assertion should be trusted.
  final bool isTrusted;

  /// Whether the type assertion should be emitted and checked.
  final bool isEmitted;

  const CheckPolicy({this.isTrusted: false, this.isEmitted: false});

  static const trusted = const CheckPolicy(isTrusted: true);
  static const checked = const CheckPolicy(isEmitted: true);

  @override
  String toString() => 'CheckPolicy(isTrusted=$isTrusted,'
      'isEmitted=$isEmitted)';
}

String _extractStringOption(
    List<String> options, String prefix, String defaultValue) {
  for (String option in options) {
    if (option.startsWith(prefix)) {
      return option.substring(prefix.length);
    }
  }
  return defaultValue;
}

Uri _extractUriOption(List<String> options, String prefix) {
  String option = _extractStringOption(options, prefix, null);
  return (option == null) ? null : Uri.parse(option);
}

int _extractIntOption(List<String> options, String prefix) {
  String option = _extractStringOption(options, prefix, null);
  return (option == null) ? null : int.parse(option);
}

bool _hasOption(List<String> options, String option) {
  return options.indexOf(option) >= 0;
}

/// Extract list of comma separated values provided for [flag]. Returns an
/// empty list if [option] contain [flag] without arguments. Returns `null` if
/// [option] doesn't contain [flag] with or without arguments.
List<String> _extractOptionalCsvOption(List<String> options, String flag) {
  String prefix = '$flag=';
  for (String option in options) {
    if (option == flag) {
      return const <String>[];
    }
    if (option.startsWith(flag)) {
      return option.substring(prefix.length).split(',');
    }
  }
  return null;
}

/// Extract list of comma separated Uris provided for [flag]. Returns an
/// empty list if [option] contain [flag] without arguments. Returns `null` if
/// [option] doesn't contain [flag] with or without arguments.
List<Uri> _extractUriListOption(List<String> options, String flag) {
  List<String> stringUris = _extractOptionalCsvOption(options, flag);
  if (stringUris == null) return null;
  return stringUris.map(Uri.parse).toList();
}

Map<fe.ExperimentalFlag, bool> _extractExperiments(List<String> options) {
  List<String> experiments =
      _extractOptionalCsvOption(options, Flags.enableLanguageExperiments);
  return fe.parseExperimentalFlags(
      experiments, (String error) => throw new ArgumentError(error));
}

const String _UNDETERMINED_BUILD_ID = "build number could not be determined";
