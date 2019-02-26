// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/error/codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../generated/resolver_test_case.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UnusedLabelTest);
  });
}

@reflectiveTest
class UnusedLabelTest extends ResolverTestCase {
  @override
  bool get enableNewAnalysisDriver => true;

  test_unused_inSwitch() async {
    await assertErrorsInCode(r'''
f(x) {
  switch (x) {
    label: case 0:
      break;
    default:
      break;
  }
}
''', [HintCode.UNUSED_LABEL]);
  }

  test_unused_onWhile() async {
    await assertErrorsInCode(r'''
f(condition()) {
  label: while (condition()) {
    break;
  }
}
''', [HintCode.UNUSED_LABEL]);
  }

  test_used_inSwitch() async {
    await assertNoErrorsInCode(r'''
f(x) {
  switch (x) {
    label: case 0:
      break;
    default:
      continue label;
  }
}
''');
  }

  test_used_onWhile() async {
    await assertNoErrorsInCode(r'''
f(condition()) {
  label: while (condition()) {
    break label;
  }
}
''');
  }
}
