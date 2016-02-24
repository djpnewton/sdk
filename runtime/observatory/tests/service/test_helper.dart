// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test_helper;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:observatory/service_io.dart';
import 'service_test_common.dart';

/// Will be set to the http address of the VM's service protocol before
/// any tests are invoked.
String serviceHttpAddress;
String serviceWebsocketAddress;

bool _isWebSocketDisconnect(e) {
  return e is NetworkRpcException;
}

const String _TESTEE_ENV_KEY = 'SERVICE_TEST_TESTEE';
const Map<String, String> _TESTEE_SPAWN_ENV = const {
  _TESTEE_ENV_KEY: 'true'
};
bool _isTestee() {
  return Platform.environment.containsKey(_TESTEE_ENV_KEY);
}

class _SerivceTesteeRunner {
  Future run({testeeBefore(): null,
              testeeConcurrent(): null,
              bool pause_on_start: false,
              bool pause_on_exit: false}) async {
    if (!pause_on_start) {
      if (testeeBefore != null) {
        var result = testeeBefore();
        if (result is Future) {
          await result;
        }
      }
      print(''); // Print blank line to signal that testeeBefore has run.
    }
    if (testeeConcurrent != null) {
      var result = testeeConcurrent();
      if (result is Future) {
        await result;
      }
    }
    if (!pause_on_exit) {
      // Wait around for the process to be killed.
      stdin.first.then((_) => exit(0));
    }
  }

  void runSync({void testeeBeforeSync(): null,
                void testeeConcurrentSync(): null,
                bool pause_on_start: false,
                bool pause_on_exit: false}) {
    if (!pause_on_start) {
      if (testeeBeforeSync != null) {
        testeeBeforeSync();
      }
      print(''); // Print blank line to signal that testeeBefore has run.
    }
    if (testeeConcurrentSync != null) {
      testeeConcurrentSync();
    }
    if (!pause_on_exit) {
      // Wait around for the process to be killed.
      stdin.first.then((_) => exit(0));
    }
  }
}

class _ServiceTesteeLauncher {
  Process process;
  final List<String> args;
  bool killedByTester = false;

  _ServiceTesteeLauncher() :
      args = ['--enable-vm-service:0',
              Platform.script.toFilePath()] {}

  String get executablePath => Platform.executable;

  // Spawn the testee process.
  Future<Process> _spawnProcess(bool pause_on_start,
                                bool pause_on_exit,
                                bool pause_on_unhandled_exceptions,
                                bool trace_service,
                                bool trace_compiler) {
    assert(pause_on_start != null);
    assert(pause_on_exit != null);
    assert(trace_service != null);
    // TODO(turnidge): I have temporarily turned on service tracing for
    // all tests to help diagnose flaky tests.
    trace_service = true;
    String dartExecutable = Platform.executable;
    var fullArgs = [];
    if (trace_service) {
      fullArgs.add('--trace-service');
      fullArgs.add('--trace-service-verbose');
    }
    if (trace_compiler) {
      fullArgs.add('--trace-compiler');
    }
    if (pause_on_start) {
      fullArgs.add('--pause-isolates-on-start');
    }
    if (pause_on_exit) {
      fullArgs.add('--pause-isolates-on-exit');
    }
    if (pause_on_unhandled_exceptions) {
      fullArgs.add('--pause-isolates-on-unhandled-exceptions');
    }
    fullArgs.addAll(Platform.executableArguments);
    fullArgs.addAll(args);
    print('** Launching $dartExecutable ${fullArgs.join(' ')}');
    return Process.start(dartExecutable,
                         fullArgs,
                         environment: _TESTEE_SPAWN_ENV);
  }

  Future<int> launch(bool pause_on_start,
                     bool pause_on_exit,
                     bool pause_on_unhandled_exceptions,
                     bool trace_service,
                     bool trace_compiler) {
    return _spawnProcess(pause_on_start,
                  pause_on_exit,
                  pause_on_unhandled_exceptions,
                  trace_service,
                  trace_compiler).then((p) {
      Completer completer = new Completer();
      process = p;
      var portNumber;
      var blank;
      var first = true;
      process.stdout.transform(UTF8.decoder)
                    .transform(new LineSplitter()).listen((line) {
        if (line.startsWith('Observatory listening on http://')) {
          RegExp portExp = new RegExp(r"\d+.\d+.\d+.\d+:(\d+)");
          var port = portExp.firstMatch(line).group(1);
          portNumber = int.parse(port);
        }
        if (pause_on_start || line == '') {
          // Received blank line.
          blank = true;
        }
        if (portNumber != null && blank == true && first == true) {
          completer.complete(portNumber);
          // Stop repeat completions.
          first = false;
          print('** Signaled to run test queries on $portNumber');
        }
        print(line);
      });
      process.stderr.transform(UTF8.decoder)
                    .transform(new LineSplitter()).listen((line) {
        print(line);
      });
      process.exitCode.then((exitCode) {
        if ((exitCode != 0) && !killedByTester) {
          throw "Testee exited with $exitCode";
        }
        print("** Process exited");
      });
      return completer.future;
    });
  }

  void requestExit() {
    print('** Killing script');
    if (process.kill()) {
      killedByTester = true;
    }
  }
}

class _ServiceTesterRunner {
  void run({List<String> mainArgs,
            List<VMTest> vmTests,
            List<IsolateTest> isolateTests,
            bool pause_on_start: false,
            bool pause_on_exit: false,
            bool trace_service: false,
            bool trace_compiler: false,
            bool verbose_vm: false,
            bool pause_on_unhandled_exceptions: false}) {
    var process = new _ServiceTesteeLauncher();
    process.launch(pause_on_start, pause_on_exit,
                   pause_on_unhandled_exceptions,
                   trace_service, trace_compiler).then((port) async {
      if (mainArgs.contains("--gdb")) {
        port = 8181;
      }
      serviceWebsocketAddress = 'ws://localhost:$port/ws';
      serviceHttpAddress = 'http://localhost:$port';
      var name = Platform.script.pathSegments.last;
      runZoned(() {
        new WebSocketVM(new WebSocketVMTarget(serviceWebsocketAddress)).load()
            .then((VM vm) async {

              // Run vm tests.
              if (vmTests != null) {
                var testIndex = 1;
                var totalTests = vmTests.length;
                for (var test in vmTests) {
                  vm.verbose = verbose_vm;
                  print('Running $name [$testIndex/$totalTests]');
                  testIndex++;
                  await test(vm);
                }
              }

              // Run isolate tests.
              if (isolateTests != null) {
                var isolate = await vm.isolates.first.load();
                var testIndex = 1;
                var totalTests = isolateTests.length;
                for (var test in isolateTests) {
                  vm.verbose = verbose_vm;
                  print('Running $name [$testIndex/$totalTests]');
                  testIndex++;
                  await test(isolate);
                }
              }

              await process.requestExit();
            });
      }, onError: (e, st) {
        process.requestExit();
        if (!_isWebSocketDisconnect(e)) {
          print('Unexpected exception in service tests: $e $st');
          throw e;
        }
      });
    });
  }
}

/// Runs [tests] in sequence, each of which should take an [Isolate] and
/// return a [Future]. Code for setting up state can run before and/or
/// concurrently with the tests. Uses [mainArgs] to determine whether
/// to run tests or testee in this invokation of the script.
Future runIsolateTests(List<String> mainArgs,
                       List<IsolateTest> tests,
                       {testeeBefore(),
                        testeeConcurrent(),
                        bool pause_on_start: false,
                        bool pause_on_exit: false,
                        bool trace_service: false,
                        bool trace_compiler: false,
                        bool verbose_vm: false,
                        bool pause_on_unhandled_exceptions: false}) async {
  assert(!pause_on_start || testeeBefore == null);
  if (_isTestee()) {
    new _SerivceTesteeRunner().run(testeeBefore: testeeBefore,
                                   testeeConcurrent: testeeConcurrent,
                                   pause_on_start: pause_on_start,
                                   pause_on_exit: pause_on_exit);
  } else {
    new _ServiceTesterRunner().run(
        mainArgs: mainArgs,
        isolateTests: tests,
        pause_on_start: pause_on_start,
        pause_on_exit: pause_on_exit,
        trace_service: trace_service,
        trace_compiler: trace_compiler,
        verbose_vm: verbose_vm,
        pause_on_unhandled_exceptions: pause_on_unhandled_exceptions);
  }
}

/// Runs [tests] in sequence, each of which should take an [Isolate] and
/// return a [Future]. Code for setting up state can run before and/or
/// concurrently with the tests. Uses [mainArgs] to determine whether
/// to run tests or testee in this invokation of the script.
///
/// This is a special version of this test harness specifically for the
/// pause_on_unhandled_exceptions_test, which cannot properly function
/// in an async context (because exceptions are *always* handled in async
/// functions).
void runIsolateTestsSynchronous(List<String> mainArgs,
                                List<IsolateTest> tests,
                                {void testeeBefore(),
                                 void testeeConcurrent(),
                                 bool pause_on_start: false,
                                 bool pause_on_exit: false,
                                 bool trace_service: false,
                                 bool trace_compiler: false,
                                 bool verbose_vm: false,
                                 bool pause_on_unhandled_exceptions: false}) {
  assert(!pause_on_start || testeeBefore == null);
  if (_isTestee()) {
    new _SerivceTesteeRunner().runSync(testeeBeforeSync: testeeBefore,
                                       testeeConcurrentSync: testeeConcurrent,
                                       pause_on_start: pause_on_start,
                                       pause_on_exit: pause_on_exit);
  } else {
    new _ServiceTesterRunner().run(
        mainArgs: mainArgs,
        isolateTests: tests,
        pause_on_start: pause_on_start,
        pause_on_exit: pause_on_exit,
        trace_service: trace_service,
        trace_compiler: trace_compiler,
        verbose_vm: verbose_vm,
        pause_on_unhandled_exceptions: pause_on_unhandled_exceptions);
  }
}


/// Runs [tests] in sequence, each of which should take an [Isolate] and
/// return a [Future]. Code for setting up state can run before and/or
/// concurrently with the tests. Uses [mainArgs] to determine whether
/// to run tests or testee in this invokation of the script.
Future runVMTests(List<String> mainArgs,
                  List<VMTest> tests,
                  {testeeBefore(),
                   testeeConcurrent(),
                   bool pause_on_start: false,
                   bool pause_on_exit: false,
                   bool trace_service: false,
                   bool trace_compiler: false,
                   bool verbose_vm: false,
                   bool pause_on_unhandled_exceptions: false}) async {
  if (_isTestee()) {
    new _SerivceTesteeRunner().run(testeeBefore: testeeBefore,
                                   testeeConcurrent: testeeConcurrent,
                                   pause_on_start: pause_on_start,
                                   pause_on_exit: pause_on_exit);
  } else {
    new _ServiceTesterRunner().run(
        mainArgs: mainArgs,
        vmTests: tests,
        pause_on_start: pause_on_start,
        pause_on_exit: pause_on_exit,
        trace_service: trace_service,
        trace_compiler: trace_compiler,
        verbose_vm: verbose_vm,
        pause_on_unhandled_exceptions: pause_on_unhandled_exceptions);
  }
}
