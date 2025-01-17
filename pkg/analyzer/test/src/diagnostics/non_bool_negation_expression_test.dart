// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/dart/analysis/experiments.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NonBoolNegationExpressionTest_NNBD);
  });
}

@reflectiveTest
class NonBoolNegationExpressionTest_NNBD extends DriverResolutionTest {
  @override
  AnalysisOptionsImpl get analysisOptions =>
      AnalysisOptionsImpl()..enabledExperiments = [EnableString.non_nullable];

  test_null() async {
    await assertErrorCodesInCode(r'''
m() {
  Null x;
  !x;
}
''', [StaticTypeWarningCode.NON_BOOL_NEGATION_EXPRESSION]);
  }
}
