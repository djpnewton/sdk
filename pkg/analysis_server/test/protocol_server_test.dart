// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:mirrors';

import 'package:analysis_server/src/protocol_server.dart'
    hide DiagnosticMessage;
import 'package:analysis_server/src/services/search/search_engine.dart';
import 'package:analyzer/dart/ast/ast.dart' as engine;
import 'package:analyzer/dart/element/element.dart' as engine;
import 'package:analyzer/dart/element/type.dart' as engine;
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart' as engine;
import 'package:analyzer/src/dart/error/lint_codes.dart';
import 'package:analyzer/src/error/codes.dart' as engine;
import 'package:analyzer/src/generated/source.dart' as engine;
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'constants.dart';
import 'mocks.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AnalysisErrorTest);
    defineReflectiveTests(EnumTest);
  });
}

@reflectiveTest
class AnalysisErrorTest {
  MockSource source = new MockSource();
  engine.LineInfo lineInfo;
  MockAnalysisError engineError;

  void setUp() {
    // prepare Source
    source.fullName = 'foo.dart';
    // prepare LineInfo
    lineInfo = new engine.LineInfo([0, 5, 9, 20]);
    // prepare AnalysisError
    engineError = new MockAnalysisError(source,
        engine.CompileTimeErrorCode.AMBIGUOUS_EXPORT, 10, 20, 'my message');
  }

  void tearDown() {
    source = null;
    engineError = null;
  }

  void test_fromEngine_hasCorrection() {
    engineError.correction = 'my correction';
    AnalysisError error = newAnalysisError_fromEngine(lineInfo, engineError);
    expect(error.toJson(), {
      SEVERITY: 'ERROR',
      TYPE: 'COMPILE_TIME_ERROR',
      LOCATION: {
        FILE: 'foo.dart',
        OFFSET: 10,
        LENGTH: 20,
        START_LINE: 3,
        START_COLUMN: 2
      },
      MESSAGE: 'my message',
      CORRECTION: 'my correction',
      CODE: 'ambiguous_export',
      HAS_FIX: false
    });
  }

  void test_fromEngine_hasUrl() {
    engineError = new MockAnalysisError(
        source,
        new MockErrorCode(url: 'http://codes.dartlang.org/TEST_ERROR'),
        10,
        20,
        'my message');
    AnalysisError error = newAnalysisError_fromEngine(lineInfo, engineError);
    expect(error.toJson(), {
      SEVERITY: 'ERROR',
      TYPE: 'COMPILE_TIME_ERROR',
      LOCATION: {
        FILE: 'foo.dart',
        OFFSET: 10,
        LENGTH: 20,
        START_LINE: 3,
        START_COLUMN: 2
      },
      MESSAGE: 'my message',
      CODE: 'test_error',
      URL: 'http://codes.dartlang.org/TEST_ERROR',
      HAS_FIX: false
    });
  }

  void test_fromEngine_lint() {
    engineError = new MockAnalysisError(
        source,
        new LintCode('my_lint', 'my message', correction: 'correction'),
        10,
        20,
        'my message');
    AnalysisError error = newAnalysisError_fromEngine(lineInfo, engineError);
    expect(error.toJson(), {
      SEVERITY: 'INFO',
      TYPE: 'LINT',
      LOCATION: {
        FILE: 'foo.dart',
        OFFSET: 10,
        LENGTH: 20,
        START_LINE: 3,
        START_COLUMN: 2
      },
      MESSAGE: 'my message',
      CODE: 'my_lint',
      URL: 'https://dart-lang.github.io/linter/lints/my_lint.html',
      HAS_FIX: false
    });
  }

  void test_fromEngine_noCorrection() {
    engineError.correction = null;
    AnalysisError error = newAnalysisError_fromEngine(lineInfo, engineError);
    expect(error.toJson(), {
      SEVERITY: 'ERROR',
      TYPE: 'COMPILE_TIME_ERROR',
      LOCATION: {
        FILE: 'foo.dart',
        OFFSET: 10,
        LENGTH: 20,
        START_LINE: 3,
        START_COLUMN: 2
      },
      MESSAGE: 'my message',
      CODE: 'ambiguous_export',
      HAS_FIX: false
    });
  }

  void test_fromEngine_noLineInfo() {
    engineError.correction = null;
    AnalysisError error = newAnalysisError_fromEngine(null, engineError);
    expect(error.toJson(), {
      SEVERITY: 'ERROR',
      TYPE: 'COMPILE_TIME_ERROR',
      LOCATION: {
        FILE: 'foo.dart',
        OFFSET: 10,
        LENGTH: 20,
        START_LINE: -1,
        START_COLUMN: -1
      },
      MESSAGE: 'my message',
      CODE: 'ambiguous_export',
      HAS_FIX: false
    });
  }
}

@reflectiveTest
class EnumTest {
  void test_AnalysisErrorSeverity() {
    new EnumTester<engine.ErrorSeverity, AnalysisErrorSeverity>().run(
        (engine.ErrorSeverity engineErrorSeverity) =>
            new AnalysisErrorSeverity(engineErrorSeverity.name),
        exceptions: {engine.ErrorSeverity.NONE: null});
  }

  void test_AnalysisErrorType() {
    new EnumTester<engine.ErrorType, AnalysisErrorType>().run(
        (engine.ErrorType engineErrorType) =>
            new AnalysisErrorType(engineErrorType.name));
  }

  void test_ElementKind() {
    new EnumTester<engine.ElementKind, ElementKind>()
        .run(convertElementKind, exceptions: {
      // TODO(paulberry): do any of the exceptions below constitute bugs?
      engine.ElementKind.DYNAMIC: ElementKind.UNKNOWN,
      engine.ElementKind.ERROR: ElementKind.UNKNOWN,
      engine.ElementKind.EXPORT: ElementKind.UNKNOWN,
      engine.ElementKind.EXTENSION: ElementKind.UNKNOWN,
      engine.ElementKind.GENERIC_FUNCTION_TYPE: ElementKind.FUNCTION_TYPE_ALIAS,
      engine.ElementKind.IMPORT: ElementKind.UNKNOWN,
      engine.ElementKind.NAME: ElementKind.UNKNOWN,
      engine.ElementKind.NEVER: ElementKind.UNKNOWN,
      engine.ElementKind.UNIVERSE: ElementKind.UNKNOWN
    });
  }

  void test_SearchResultKind() {
    // TODO(paulberry): why does the MatchKind class exist at all?  Can't we
    // use SearchResultKind inside the analysis server?
    new EnumTester<MatchKind, SearchResultKind>()
        .run(newSearchResultKind_fromEngine);
  }
}

/**
 * Helper class for testing the correspondence between an analysis engine enum
 * and an analysis server API enum.
 */
class EnumTester<EngineEnum, ApiEnum> {
  /**
   * Test that the function [convert] properly converts all possible values of
   * [EngineEnum] to an [ApiEnum] with the same name, with the exceptions noted
   * in [exceptions].  For each key in [exceptions], if the corresponding value
   * is null, then we check that converting the given key results in an error.
   * If the corresponding value is an [ApiEnum], then we check that converting
   * the given key results in the given value.
   */
  void run(ApiEnum convert(EngineEnum value),
      {Map<EngineEnum, ApiEnum> exceptions = const {}}) {
    ClassMirror engineClass = reflectClass(EngineEnum);
    engineClass.staticMembers.forEach((Symbol symbol, MethodMirror method) {
      if (symbol == #values) {
        return;
      }
      if (!method.isGetter) {
        return;
      }
      String enumName = MirrorSystem.getName(symbol);
      EngineEnum engineValue =
          engineClass.getField(symbol).reflectee as EngineEnum;
      expect(engineValue, new TypeMatcher<EngineEnum>());
      if (exceptions.containsKey(engineValue)) {
        ApiEnum expectedResult = exceptions[engineValue];
        if (expectedResult == null) {
          expect(() {
            convert(engineValue);
          }, throwsException);
        } else {
          ApiEnum apiValue = convert(engineValue);
          expect(apiValue, equals(expectedResult));
        }
      } else {
        ApiEnum apiValue = convert(engineValue);
        expect((apiValue as dynamic).name, equals(enumName));
      }
    });
  }
}

class MockAnalysisError implements engine.AnalysisError {
  @override
  MockSource source;

  @override
  engine.ErrorCode errorCode;

  @override
  int offset;

  @override
  String message;

  @override
  String correction = null;

  @override
  int length;

  MockAnalysisError(
      this.source, this.errorCode, this.offset, this.length, this.message);

  @override
  List<DiagnosticMessage> get contextMessages => null;

  @override
  String get correctionMessage => null;

  @override
  DiagnosticMessage get problemMessage => null;

  @override
  Severity get severity => null;
}

class MockErrorCode implements engine.ErrorCode {
  @override
  engine.ErrorType type;

  @override
  engine.ErrorSeverity errorSeverity;

  @override
  String name;

  @override
  String url;

  MockErrorCode(
      {this.type = engine.ErrorType.COMPILE_TIME_ERROR,
      this.errorSeverity = engine.ErrorSeverity.ERROR,
      this.name = 'TEST_ERROR',
      this.url});

  @override
  String get correction {
    throw new StateError('Unexpected invocation of correction');
  }

  @override
  bool get hasPublishedDocs => false;

  @override
  bool get isUnresolvedIdentifier => false;

  @override
  String get message {
    throw new StateError('Unexpected invocation of message');
  }

  @override
  String get uniqueName {
    throw new StateError('Unexpected invocation of uniqueName');
  }
}
