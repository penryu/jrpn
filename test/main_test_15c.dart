// ignore_for_file: avoid_print

/*
Copyright (c) 2021-2024 William Foote

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

You should have received a copy of the GNU General Public License along with
this program; if not, see https://www.gnu.org/licenses/ .
*/

import 'dart:async';
import 'dart:math' as dart;
import 'dart:math';

import 'package:jrpn/jrpn15/more_math.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:jrpn/c/controller.dart';
import 'package:jrpn/v/buttons.dart';
import 'package:vector_math/vector_math_64.dart' as dart_mat;
import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';

import 'package:jrpn/c/operations.dart';
import 'package:jrpn/m/model.dart';

import 'package:jrpn/v/main_screen.dart';
import 'package:jrpn/jrpn15/main.dart';
import 'package:jrpn/jrpn15/matrix.dart';
import 'package:jrpn/jrpn15/model15c.dart';
import 'package:jrpn/jrpn15/tests15c.dart';
import 'package:jrpn/generic_main.dart' show ScreenConfiguration;
import 'hyperbolic.dart';
import 'opcodes15c.dart';
import 'program_test_15c.dart';
import 'programs.dart';
import 'package:jrpn/jrpn15/linear_algebra.dart' as linalg;

Future<void> main() async {
  runStaticInitialization15();
  test('Decimal complex', decimalComplex);
  test('Decimal multiplication', decimalMultiplyAndDivide);
  test('Decimal addition/subtraction', decimalAddSubtract);

  // Note that passing Jrpn into testWidgets actually tests very little, because
  // the deferred initialization doesn't happen.  I think it stalls on a plugin
  // waiting for the system, maybe related to receiving links.  Anyway, we
  // don't do it here.

  bool done = false;
  testWidgets('15C Buttons', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = Controller15(createModel15());
    controller.screenConfig = await ScreenConfiguration.fromPersistentStorage(
      'foo',
    );
    final ScreenPositioner positioner = ScreenPositioner(12.7, 8);
    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) {
          final factory = LandscapeButtonFactory15(
            context,
            positioner,
            controller,
          );
          final layout = ButtonLayout15(factory, 10, 0.1);

          TrigInputTests(controller, layout).run();
          MiscTests(controller, layout).run();
          unawaited(() async {
            try {
              await AdvancedFunctionTests(
                TestCalculator(for15C: true),
                layout,
              ).run();
            } finally {
              done = true;
            }
          }());

          return Container(); // placeholder
        },
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 10000));
    expect(done, true);
  });
  test('Built-in self tests 15C', () async {
    await SelfTests15(inCalculator: false).runAll();
  });
  test('15C opcode test', opcodeTest15C);
  test('15C lastX test', lastX15C);
  test('Value exponent test', valueExponentTest);
  test('Value frac op test', valueFracOpTest);
  test('Value int op test', valueIntOpTest);
  test('DecimalFP int op test', decimalFPIntOpTest);
  test('Trig test', trigTest);
  test15cPrograms();
}

class MiscTests {
  final Controller15 controller;
  final ButtonLayout15 layout;
  final Model15 model;

  MiscTests(this.controller, this.layout) : model = controller.model;

  void _userModeStackLift() {
    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.enter);
    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.rcl); // USER
    expect(model.userMode, true);
    controller.buttonWidgetDown(layout.n3);
    expect(model.x, Value.fromDouble(3));
    expect(model.y, Value.fromDouble(2));
    expect(model.z, Value.fromDouble(1));
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.rcl); // USER
    expect(model.userMode, false);
    expect(model.x, Value.fromDouble(3));
    expect(model.y, Value.fromDouble(2));
    expect(model.z, Value.fromDouble(1));
  }

  void _toPolar(Value Function() getY) {
    controller.buttonDown(Operations15.deg);

    model.yF = 5;
    model.xF = 4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(51.34019175));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(3.999999999));
    expect(getY(), Value.fromDouble(5));

    model.yF = 5;
    model.xF = -4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(128.6598083));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(-4.000000004));
    expect(getY(), Value.fromDouble(4.999999996));

    model.yF = -5;
    model.xF = 4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(-51.34019175));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(3.999999999));
    expect(getY(), Value.fromDouble(-5));

    model.yF = -5;
    model.xF = -4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(-128.6598083));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(-4.000000004));
    expect(getY(), Value.fromDouble(-4.999999996));

    controller.buttonDown(Operations15.rad);
    model.yF = 5;
    model.xF = 4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(0.8960553846));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(4));
    expect(getY(), Value.fromDouble(5));

    controller.buttonDown(Operations15.grd);
    model.yF = 5;
    model.xF = 4;
    if (model.isComplexMode) {
      controller.buttonDown(Operations.xy);
      controller.buttonDown(Operations15.I15);
    }
    controller.buttonDown(Operations15.toP);
    expect(model.x, Value.fromDouble(6.403124237));
    expect(getY(), Value.fromDouble(57.04465750));
    controller.buttonDown(Operations15.toR);
    expect(model.x, Value.fromDouble(3.999999999));
    expect(getY(), Value.fromDouble(5));

    controller.buttonDown(Operations15.deg);
  }

  void run() {
    model.isComplexMode = false;
    _userModeStackLift();
    _toPolar(() => model.y);
    model.isComplexMode = true;
    _toPolar(() => model.xImaginary);
    model.isComplexMode = false;
  }
}

class AdvancedFunctionTests {
  final TestCalculator calculator;
  final Controller15 controller;
  final ButtonLayout15 layout;
  final Model15 model;
  final StreamIterator<ProgramEvent> out;

  AdvancedFunctionTests(this.calculator, this.layout)
    : controller = calculator.controller as Controller15,
      model = calculator.controller.model as Model15,
      out = StreamIterator<ProgramEvent>(calculator.output.stream);

  Future<void> _statistics() async {
    final l = layout;
    final m = model;
    final regs = model.memory.registers;
    final badValue = Value.fromDouble(0xdeadbeef.toDouble());
    for (int i = 0; i < 9; i++) {
      regs[i] = badValue;
    }
    _play([l.fShift, l.gsb]); // Clear sigma
    for (int i = 2; i <= 7; i++) {
      expect(regs[i], Value.zero);
    }
    _play([l.n4, l.dot, l.n6, l.n3, l.enter, l.n0]);
    expect(m.xF, 0);
    _play([l.sum]);
    expect(m.xF, 1);
    expect(m.yF, 4.63);
    _play([l.n4, l.dot, l.n7, l.n8]);
    expect(m.xF, 4.78);
    expect(m.yF, 4.63);
    _play([l.enter, l.n2, l.n0, l.sum]);
    expect(m.xF, 2);
    expect(m.yF, 4.78);
    _play([l.n6, l.dot, l.n6, l.n1, l.enter]);
    _play([l.n4, l.n0, l.sum]);
    expect(m.xF, 3);
    _play([l.n7, l.dot, l.n2, l.n1, l.enter]);
    _play([l.n6, l.n0, l.sum]);
    expect(m.xF, 4);
    _play([l.n7, l.dot, l.n7, l.n8, l.enter]);
    _play([l.n8, l.n0, l.sum]);
    expect(m.xF, 5);
    _play([l.rcl, l.sum]);
    expect(m.x, Value.fromDouble(200));
    expect(m.y, Value.fromDouble(31.01));
    expect(m.z, Value.fromDouble(7.78));
    expect(m.t, Value.fromDouble(7.21));
    _play([l.rcl, l.sum]); // Check stack lift behavior
    expect(m.x, Value.fromDouble(200));
    expect(m.y, Value.fromDouble(31.01));
    expect(m.z, Value.fromDouble(200));
    expect(m.t, Value.fromDouble(31.01));
    expect(m.memory.registers[2], Value.fromDouble(5));
    expect(m.memory.registers[3], Value.fromDouble(200));
    expect(m.memory.registers[4], Value.fromDouble(12000));
    expect(m.memory.registers[5], Value.fromDouble(31.01));
    expect(m.memory.registers[6], Value.fromDouble(200.4899));
    expect(m.memory.registers[7], Value.fromDouble(1415));
    _play([l.n4, l.dot, l.n7, l.n8, l.enter]);
    _play([l.n2, l.n0, l.gShift, l.sum]); // sigma-minus
    expect(m.xF, 4);
    _play([l.n5, l.dot, l.n7, l.n8, l.enter]);
    _play([l.n2, l.n0, l.sum]);
    expect(m.xF, 5);
    for (final enterOrNot in [
      <CalculatorButton>[],
      [l.enter],
    ]) {
      _play([l.n9, l.enter, l.n8]); // Test stack lift
      _play(enterOrNot); // Test stack lift
      _play([l.gShift, l.n0]); // average
      expect(m.xF, 40);
      expect(m.y, Value.fromDouble(6.402));
      expect(m.z, Value.fromDouble(8));
      expect(m.t, Value.fromDouble(9));

      _play([l.n9, l.enter, l.n8]); // Test stack lift
      _play(enterOrNot); // Test stack lift
      _play([l.gShift, l.dot]); // standard deviation
      expect(m.x, Value.fromDouble(31.62277660));
      expect(m.y, Value.fromDouble(1.237121659));
      expect(m.z, Value.fromDouble(8));
      expect(m.t, Value.fromDouble(9));

      _play([l.n9, l.enter, l.n8]); // Test stack lift
      _play(enterOrNot); // Test stack lift
      _play([l.fShift, l.sum]); // linear regression
      expect(m.x, Value.fromDouble(4.856));
      expect(m.y, Value.fromDouble(0.03865));
      expect(m.z, Value.fromDouble(8));
      expect(m.t, Value.fromDouble(9));

      _play([l.n9, l.enter, l.n8, l.enter, l.n7, l.n0]);
      _play(enterOrNot); // Test stack lift
      _play([l.fShift, l.dot]); // yhat, r - estimate y
      expect(m.x, Value.fromDouble(7.5615));
      expect(m.y, Value.fromDouble(0.9879548276));
      if (enterOrNot.isEmpty) {
        expect(m.z, Value.fromDouble(8));
        expect(m.t, Value.fromDouble(9));
      } else {
        // Yep - verified with real 15C
        expect(m.z, Value.fromDouble(70));
        expect(m.t, Value.fromDouble(8));
      }

      m.xF = 58.3;
      _play([l.fShift, l.dot]); // yhat, r - estimate y
      expect(m.x, Value.fromDouble(7.109295));
      expect(m.y, Value.fromDouble(0.9879548276));
    }
  }

  Future<void> _page139({required bool asProgram}) async {
    model.isComplexMode = true;
    model.userMode = false;
    if (asProgram) {
      controller.buttonWidgetDown(layout.gShift);
      controller.buttonWidgetDown(layout.rs); // P/R
      controller.buttonWidgetDown(layout.fShift);
      controller.buttonWidgetDown(layout.rdown); // CLEAR PRGM
      controller.buttonWidgetDown(layout.fShift);
      controller.buttonWidgetDown(layout.sst); // LBL
      controller.buttonWidgetDown(layout.sqrt); // A
    }
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.n7); // FIX
    controller.buttonWidgetDown(layout.n4);
    controller.buttonWidgetDown(layout.gShift);
    controller.buttonWidgetDown(layout.n5); // CF
    controller.buttonWidgetDown(layout.n8);
    if (!asProgram) {
      expect(false, model.isComplexMode);
    }
    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.enter);
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.sin); // DIM
    controller.buttonWidgetDown(layout.sqrt); // A
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.chs); // MATRIX
    controller.buttonWidgetDown(layout.n1); // A
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.rcl); // USER

    controller.buttonWidgetDown(layout.n3);
    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n8);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.sqrt); // A
    controller.buttonUp();
    if (!asProgram) {
      expect(model.display.current, ' 3.8000     ');
      expect(model.matrices[0].get(0, 0), Value.fromDouble(3.8));
    }

    controller.buttonWidgetDown(layout.n7);
    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.sqrt); // A
    controller.buttonUp();
    if (!asProgram) {
      expect(model.matrices[0].get(0, 1), Value.fromDouble(7.2));
    }

    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n3);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.sqrt); // A
    controller.buttonUp();
    if (!asProgram) {
      expect(model.matrices[0].get(1, 0), Value.fromDouble(1.3));
    }

    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n9);
    controller.buttonWidgetDown(layout.chs);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.sqrt); // A
    controller.buttonUp();
    if (asProgram) {
      controller.buttonWidgetDown(layout.gto);
      controller.buttonWidgetDown(layout.sqrt); // GTO A, should be skipped
    } else {
      expect(model.matrices[0].get(1, 1), Value.fromDouble(-0.9));
      expect(model.memory.registers[0], Value.fromDouble(1));
      expect(model.memory.registers[1], Value.fromDouble(1));
    }

    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.enter);
    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.sin); // DIM
    controller.buttonWidgetDown(layout.eX); // B

    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.n6);
    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n5);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.eX); // B
    controller.buttonUp();
    if (!asProgram) {
      expect(model.matrices[1].get(0, 0), Value.fromDouble(16.5));
    }

    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.n2);
    controller.buttonWidgetDown(layout.dot);
    controller.buttonWidgetDown(layout.n1);
    controller.buttonWidgetDown(layout.chs);
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.eX); // B
    controller.buttonUp();
    if (asProgram) {
      controller.buttonWidgetDown(layout.gto);
      controller.buttonWidgetDown(layout.sqrt); // GTO A, should be skipped
    } else {
      expect(model.matrices[1].get(1, 0), Value.fromDouble(-22.1));
    }

    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.eex); // result
    controller.buttonWidgetDown(layout.tenX); // C

    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // matrix
    controller.buttonWidgetDown(layout.eX); // B
    if (!asProgram) {
      expect(model.x, Value.fromMatrix(1));
    }
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // matrix
    controller.buttonWidgetDown(layout.sqrt); // A
    if (!asProgram) {
      expect(model.x, Value.fromMatrix(0));
    }
    controller.buttonWidgetDown(layout.div);
    if (asProgram) {
      controller.buttonWidgetDown(layout.gShift);
      controller.buttonWidgetDown(layout.gsb); // RTN
      controller.buttonWidgetDown(layout.fShift);
      controller.buttonWidgetDown(layout.sst); // LBL
      controller.buttonWidgetDown(layout.eX); // B
      controller.buttonWidgetDown(layout.rcl);
      controller.buttonWidgetDown(layout.tenX); // C
      controller.buttonWidgetDown(layout.gShift);
      controller.buttonWidgetDown(layout.rs); // P/R
      controller.buttonWidgetDown(layout.sqrt); // A (in user mode)
      controller.buttonUp();
      expect(await out.moveNext(), true);
      expect(out.current, ProgramEvent.done);
    }
    expect(model.x, Value.fromMatrix(2));

    if (asProgram) {
      controller.buttonWidgetDown(layout.eX); // B in user mode
      controller.buttonUp();
      expect(await out.moveNext(), true);
      expect(out.current, ProgramEvent.done);
    } else {
      controller.buttonWidgetDown(layout.rcl);
      controller.buttonWidgetDown(layout.tenX); // C
      controller.buttonUp();
    }
    expect(model.x, Value.fromDouble(-11.28873239));
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.tenX); // C
    controller.buttonUp();
    expect(model.x, Value.fromDouble(8.249608762));

    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.rcl); // USER (off)
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.chs); // matrix
    controller.buttonWidgetDown(layout.n0);
    for (int i = 0; i < 5; i++) {
      expect(model.matrices[i].length, 0);
    }
    expect(model.userMode, false);
  }

  ///
  /// Test STO-G-(matrix) and RCL-G-Matrix
  ///
  void _page146() {
    final Matrix mat = model.matrices[3];
    mat.resize(model, 3, 3);
    mat.set(2, 1, Value.zero);
    mat.set(1, 2, Value.fromDouble(99.99));
    model.yF = 42.42;
    model.pushStack();
    model.yF = 3.9; // Row 3
    model.xF = 2.01; // Column 2
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.gShift);
    controller.buttonWidgetDown(layout.yX); // D
    controller.buttonUp();
    expect(mat.get(2, 1), Value.fromDouble(42.42));
    expect(model.x, Value.fromDouble(42.42));
    model.xF = 6.66;
    model.pushStack();
    controller.buttonDown(Operations.n2); // Ro2
    controller.buttonDown(Operations.enter);
    controller.buttonDown(Operations.n3); // Column
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.gShift);
    controller.buttonWidgetDown(layout.yX); // D
    controller.buttonUp();
    expect(model.x, Value.fromDouble(99.99));
    expect(model.y, Value.fromDouble(6.66));
    mat.resize(model, 0, 0);
  }

  ///
  /// Test STO-matrix
  ///
  void _stoMatrixAndChs() {
    final Matrix mat = model.matrices[3];
    mat.resize(model, 3, 3);
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        mat.set(i, j, Value.fromDouble(10.0 * i + j));
      }
    }
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.yX); // Matrix
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.fShift);
    controller.buttonWidgetDown(layout.reciprocal);
    model.xF = -42;
    controller.buttonWidgetDown(layout.sto);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.yX);

    final Matrix mat2 = model.matrices[4];
    mat.resize(model, 3, 3);
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        expect(mat.get(i, j), Value.fromDouble(-42));
        expect(mat2.get(i, j), Value.fromDouble(10.0 * i + j));
      }
    }

    // Test chs on matrix E
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.reciprocal); // Matrix
    controller.buttonWidgetDown(layout.chs); // Matrix
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        expect(mat2.get(i, j), Value.fromDouble(-10.0 * i + -j));
      }
    }
  }

  void _invertMatrix(bool useInvert) {
    void invert(Matrix m) {
      if (useInvert) {
        linalg.invert(m);
      } else {
        final identity = CopyMatrix(m)..identity();
        final result = CopyMatrix(m);
        linalg.solve(m, identity, result);
        m.isLU = false;
        result.visit((r, c) => m.set(r, c, result.get(r, c)));
      }
    }

    final Matrix mat2 = model.matrices[4];
    final Matrix mat = model.matrices[3];
    mat2.resize(model, 2, 2);
    mat2.set(0, 0, _toValue(0.1));
    mat2.set(0, 1, _toValue(0.1));
    mat2.set(1, 0, _toValue(0.2));
    mat2.set(1, 1, _toValue(0.4));
    AMatrix mat2c = CopyMatrix(mat2);
    invert(mat2);
    expect(mat2.get(0, 0).asDouble, 20);
    expect(mat2.get(0, 1).asDouble, -5);
    expect(mat2.get(1, 0).asDouble, -10);
    expect(mat2.get(1, 1).asDouble, 5);
    invert(mat2);
    expect(mat2.equivalent(mat2c), true);

    mat2.resize(model, 3, 3);
    mat2.set(0, 0, _toValue(0.1));
    mat2.set(0, 1, _toValue(0.1));
    mat2.set(0, 2, _toValue(0.1));
    mat2.set(1, 0, _toValue(0.2));
    mat2.set(1, 1, _toValue(0.4));
    mat2.set(1, 2, _toValue(0.8));
    mat2.set(2, 0, _toValue(0.1));
    mat2.set(2, 1, _toValue(0.3));
    mat2.set(2, 2, _toValue(0.6));
    mat2c = CopyMatrix(mat2);
    invert(mat2);
    expect(mat2.get(0, 0).asDouble, 0);
    expect(mat2.get(0, 1).asDouble, 15);
    expect(mat2.get(0, 2).asDouble, -20);
    expect(mat2.get(1, 0).asDouble, 20);
    expect(mat2.get(1, 1).asDouble, -25);
    expect(mat2.get(1, 2).asDouble, 30);
    expect(mat2.get(2, 0).asDouble, -10);
    expect(mat2.get(2, 1).asDouble, 10);
    expect(mat2.get(2, 2).asDouble, -10);
    invert(mat2);
    expectMatrix(mat2, mat2c, useInvert ? 5e-10 : 2e-9);

    // Test 1/x on matrix E
    mat2.set(0, 0, _toValue(0.1));
    mat2.set(0, 1, _toValue(0.1));
    mat2.set(0, 2, _toValue(0.1));
    mat2.set(1, 0, _toValue(0.2));
    mat2.set(1, 1, _toValue(0.4));
    mat2.set(1, 2, _toValue(0.8));
    mat2.set(2, 0, _toValue(0.1));
    mat2.set(2, 1, _toValue(0.5));
    mat2.set(2, 2, _toValue(0.9));
    final result = model.matrices[model.resultMatrix = 2];
    controller.buttonWidgetDown(layout.rcl);
    controller.buttonWidgetDown(layout.chs); // Matrix
    controller.buttonWidgetDown(layout.reciprocal); // E
    controller.buttonWidgetDown(layout.reciprocal); // 1/x
    {
      const epsilon = 1.1e-8;
      expectRounded(epsilon, result.get(0, 0), 5);
      expectRounded(epsilon, result.get(0, 1), 5);
      expectRounded(epsilon, result.get(0, 2), -5);
      expectRounded(epsilon, result.get(1, 0), 12.5);
      expectRounded(epsilon, result.get(1, 1), -10);
      expectRounded(epsilon, result.get(1, 2), 7.5);
      expectRounded(epsilon, result.get(2, 0), -7.5);
      expectRounded(epsilon, result.get(2, 1), 5);
      expectRounded(epsilon, result.get(2, 2), -2.5);
    }

    final orig = [
      [0.01, 0.02, 0.03, 0.04, 0.05],
      [0.01, 0.03, 0.05, 0.07, 0.09],
      [0.01, 0.06, 0.1, 0.15, 0.25],
      [0.1, 0.2, 0.5, 0.7, 0.8],
      [0.3, 0.6, 0.7, 0.8, 0.9],
    ];
    final inverted = [
      [450.0, -200.0, 0.0, 0.0, -5.0],
      [-12.5, 200.0, -25.0, -12.5, -1.25],
      [-612.5, -300.0, 75.0, 27.5, 18.75],
      [362.5, 300.0, -75.0, -17.5, -13.75],
      [12.5, -100.0, 25.0, 2.5, 1.25],
    ];
    for (final m in model.matrices) {
      m.resize(model, 0, 0);
    }
    model.memory.numRegisters = 2;
    mat.resize(model, 5, 5);
    mat2.resize(model, 5, 5);
    mat.isLU = false;
    mat2.isLU = false;
    // do all 5! (120) permutations
    for (int a = 0; a < 5; a++) {
      final remain = [0, 1, 2, 3, 4];
      final map = <int>[];
      final lastX = <int>[];
      void take(int x) {
        lastX.add(x);
        map.add(remain[x]);
        remain.removeAt(x);
      }

      void give() {
        final lx = lastX.removeLast();
        final lv = map.removeLast();
        remain.insert(lx, lv);
      }

      take(a);
      for (int b = 0; b < 4; b++) {
        take(b);
        for (int c = 0; c < 3; c++) {
          take(c);
          for (int d = 0; d < 2; d++) {
            take(d);
            take(0);
            for (int r = 0; r < 5; r++) {
              for (int c = 0; c < 5; c++) {
                mat.set(r, map[c], Value.fromDouble(orig[r][c]));
                mat2.set(map[r], c, Value.fromDouble(inverted[r][c]));
              }
            }
            final o = CopyMatrix(mat);
            invert(mat);
            expectMatrix(mat, mat2, 5e-6);
            invert(mat);
            expectMatrix(mat, o, useInvert ? 2e-8 : 5e-8);
            give();
            give();
          }
          give();
        }
        give();
      }
    }

    ///
    /// Make a bunch of pseudo-random matrices, find their inverses, multiply
    /// 'em, and make sure the result is close to the identity matrix.
    ///
    final random = [
      0.11554357410230745,
      0.1752190781091121,
      0.2554799105149069,
      0.7882517396398285,
      0.9553619742044123,
      0.31669130654119626,
      0.6512789895641755,
      0.956850550664375,
      0.5149877831225405,
      0.9069305781274585,
      0.6148645579026758,
      0.2954207054723502,
      0.9252281346955582,
      1.0374866365398772,
      0.30523103927522177,
      0.9498085834094088,
      0.596642195724848,
      0.7278426526965753,
      1.0453753342972407,
      0.7553738159786345,
      0.15637221523026837,
      0.8670820197735291,
      0.3938634878728674,
      0.4382736054911537,
      0.1717232227697613,
      1.062594511041458,
      0.43563026638450497,
      0.8034066490281968,
      0.2142472399579687,
      0.5918618563998227,
      0.9345396921345667,
      0.8449774408819636,
      0.783358655118447,
      1.0281576723791797,
      0.6229052671179554,
      1.028115675075235,
      0.9757683761758337,
      0.2646857903574741,
      0.7999931334094097,
      0.969812107245347,
      0.42444150839051675,
      0.8935187276167458,
      0.5256281891538678,
      0.905695547664674,
      0.2450874099913132,
      0.5912254403400581,
      0.7810969255400474,
      0.8788464339354397,
      0.6620639665847116,
      1.0943110970818815,
      0.48470482292355066,
      0.6615836506436301,
      1.0458772534696898,
      0.5047192340830525,
      0.4685312103667608,
      0.9802805674851287,
      0.21305505735550592,
      0.37026185427005986,
      0.10162243410658447,
      0.7848549364642744,
      0.28347485762438895,
      0.1818113208618173,
      1.0280231209098611,
      0.6961553994372459,
      0.9903127956749369,
      0.7456275776442648,
      0.6278249317681296,
      0.5293719965367599,
      0.3448840987921128,
      0.3181939701519737,
      0.12990316554686723,
      0.7981990455439859,
      0.7227555038509729,
      0.925907636507783,
      0.843093213283728,
      0.7396488347741407,
      0.9487692238747365,
      0.39142942330231,
      0.6152346182123536,
      0.7380712954605932,
      0.9166836954506805,
      0.7484829378036751,
      0.19031076562245933,
      0.5856881358721754,
      0.21339616026637045,
      0.5615065546729514,
      0.5880700604803681,
      0.3135305338351917,
      1.0329419877061843,
      0.726816109416792,
      0.9315827556414396,
      0.37734079984471613,
      0.3732704741421152,
      0.2996321641769589,
      0.5189723759038541,
      0.13142897558336689,
      0.34724822080474493,
      0.2751082165630431,
      0.11038090886648369,
      0.7374852462277609,
      0.6666619454401502,
    ];
    for (int sz = 1; sz <= 5; sz++) {
      mat.resize(model, sz, sz);
      mat2.resize(model, sz, sz);
      final identity = CopyMatrix(mat)..identity();
      final result = CopyMatrix(mat);

      for (int startPos = 0; startPos < random.length; startPos++) {
        int pos = startPos;
        mat.visit((r, c) {
          mat2.set(r, c, Value.fromDouble(random[pos]));
          mat.set(r, c, Value.fromDouble(random[pos++]));
          pos = pos % random.length;
        });
        //
        // While we're here, test the determinant
        //
        if (sz == 2) {
          final dm = dart_mat.Matrix2.zero();
          mat2.visit((r, c) => dm.setEntry(r, c, mat.get(r, c).asDouble));
          expectRounded(
            2e-9,
            Value.fromDouble(linalg.determinant(mat2).asDouble),
            dm.determinant(),
          );
        } else if (sz == 3) {
          final dm = dart_mat.Matrix3.zero();
          mat2.visit((r, c) => dm.setEntry(r, c, mat.get(r, c).asDouble));
          expectRounded(
            2e-9,
            linalg.determinant(mat2).toValue(),
            dm.determinant(),
          );
        } else if (sz == 4) {
          final dm = dart_mat.Matrix4.zero();
          mat2.visit((r, c) => dm.setEntry(r, c, mat.get(r, c).asDouble));
          expectRounded(
            2e-9,
            linalg.determinant(mat2).toValue(),
            dm.determinant(),
          );
        }
        invert(mat2);
        result.dot(mat, mat2);
        expectMatrix(result, identity, useInvert ? 5e-7 : 2e-6);
      }
    }

    mat.resize(model, 0, 0);
    mat2.resize(model, 0, 0);
  }

  void expectRounded(double epsilon, Value v, double expected) {
    if ((v.asDouble - expected).abs() > epsilon) {
      expect(false, '$v differs from $expected by more than $epsilon');
    }
  }

  void _singularMatrix() {
    // Advanced functions page 98:  Singular matrix example.  Our LU
    // perturbation to avoid zero pivots is unlikely to be identical to what
    // the real 15C does, but it was chosen to work for this known example.
    final mat = model.matrices[0];
    mat.resize(model, 2, 2);
    mat.set(0, 0, Value.fromDouble(3));
    mat.set(0, 1, Value.fromDouble(3));
    mat.set(1, 0, Value.fromDouble(1));
    mat.set(1, 1, Value.fromDouble(1));
    final mat2 = model.matrices[1];
    mat2.resize(model, 2, 1);
    mat2.set(0, 0, Value.fromDouble(1));
    mat2.set(1, 0, Value.fromDouble(1));
    final result = model.matrices[model.resultMatrix = 2];
    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelB);
    controller.buttonUp();
    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelA);
    controller.buttonUp();
    controller.buttonDown(Operations15.div);
    expect(mat.isLU, true);
    expect(mat.get(0, 0), Value.fromDouble(3));
    expect(mat.get(0, 1), Value.fromDouble(3));
    expect(mat.get(1, 0), Value.fromDouble(1.0 / 3.0));
    expect(mat.get(1, 1), Value.fromDouble(1e-10));
    expect(result.get(0, 0), Value.fromDouble(-6666666667));
    expect(result.get(1, 0), Value.fromDouble(6666666667));
    model.matrices[0].resize(model, 0, 0);
    model.matrices[1].resize(model, 0, 0);
    model.matrices[2].resize(model, 0, 0);
  }

  void _transpose() {
    final mat = model.matrices[1];
    for (int rows = 1; rows <= 50; rows++) {
      for (int cols = 1; cols <= 50 ~/ rows; cols++) {
        mat.resize(model, rows, cols);
        mat.visit((r, c) => mat.set(r, c, _toValue(100.0 * r + c)));
        final orig = CopyMatrix(mat);
        controller.buttonDown(Operations15.rcl15);
        controller.buttonDown(Operations15.matrix);
        controller.buttonDown(Operations15.letterLabelB);
        controller.buttonDown(Operations15.matrix);
        controller.buttonDown(Operations.n4);
        expect(mat.rows, orig.columns);
        expect(mat.columns, orig.rows);
        mat.visit((r, c) {
          expect(mat.get(r, c), orig.get(c, r));
        });
      }
    }
    mat.resize(model, 0, 0);
  }

  void _complexMatrix() {
    final numRegisters = model.memory.numRegisters;
    model.memory.numRegisters = 2;
    final mat = model.matrices[1];
    for (int rows = 1; rows <= 50; rows++) {
      for (int cols = 2; cols <= 50 ~/ rows; cols += 2) {
        mat.resize(model, rows, cols);
        mat.visit((r, c) => mat.set(r, c, _toValue(100.0 * r + c)));
        final orig = CopyMatrix(mat);
        controller.buttonDown(Operations15.rcl15);
        controller.buttonDown(Operations15.matrix);
        controller.buttonDown(Operations15.letterLabelB);
        controller.buttonDown(Operations15.pYX);
        expect(mat.rows, orig.rows * 2);
        expect(mat.columns, orig.columns ~/ 2);
        mat.visit((r, c) {
          expect(
            mat.get(r, c),
            orig.get(r % orig.rows, c * 2 + (r >= orig.rows ? 1 : 0)),
          );
        });
        controller.buttonDown(Operations15.cYX);
        expectMatrix(mat, orig);
      }
    }
    for (int rows = 1; rows <= 12; rows++) {
      for (int cols = 1; cols <= 12 ~/ rows; cols++) {
        mat.resize(model, rows * 2, cols);
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            mat.set(r, c, _toValue(1 + r + 100.0 * c));
            mat.set(r + rows, c, _toValue(1001 + r + 100.0 * c));
          }
        }
        final copy = CopyMatrix(mat);
        mat.convertToZTilde(model);
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            expect(mat.get(r, c), copy.get(r, c));
            expect(mat.get(r + rows, c + cols), copy.get(r, c));
            expect(mat.get(r + rows, c), copy.get(r + rows, c));
            expect(mat.get(r, c + cols), copy.get(r + rows, c).negateAsFloat());
            mat.set(r, c + cols, Value.zero);
            mat.set(r + rows, c + cols, Value.zero);
          }
        }
        mat.convertFromZTilde(model);
        expectMatrix(mat, copy);
      }
    }
    mat.resize(model, 0, 0);
    model.memory.numRegisters = numRegisters;
  }

  void _misc() {
    final mat = model.matrices[model.resultMatrix = 1]; // B
    mat.resize(model, 5, 5);
    final vals = [
      <double>[1, 3, 29, 4.7, 16.8],
      <double>[27, -3, 5, 24, 3.14],
      <double>[99, 86, 8, 42, 6.66],
      <double>[23, 6.022, 51, 52, 88],
      <double>[210, -37, 5, 16, 7],
    ];

    mat.visit((r, c) => mat.set(r, c, _toValue(vals[r][c])));
    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelB);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations.n7); // Row norm
    expect(model.x, Value.fromDouble(275));

    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelB);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations.n8); // Frobenius norm
    expect(model.x, Value.fromDouble(284.5818154));

    mat.transpose();

    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelB);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations.n7); // Row norm
    expect(model.x, Value.fromDouble(360));

    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations15.letterLabelB);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations.n8); // Frobenius norm
    expect(model.x, Value.fromDouble(284.5818154));

    // Test issue 80:  Set matrix dimension to 0 with non-number
    // in x or y
    mat.resize(model, 3, 3);
    model.x = Value.fromMatrix(1);
    model.yF = 0;
    controller.buttonDown(Operations15.dim);
    controller.buttonDown(Operations15.eX15); // B
    expect(mat.columns, 0);
    expect(mat.rows, 0);
    mat.resize(model, 3, 3);
    model.xF = 0;
    model.y = Value.fromMatrix(1);
    controller.buttonDown(Operations15.dim);
    controller.buttonDown(Operations15.eX15);
    expect(mat.columns, 0);
    expect(mat.rows, 0);

    // Test issue 81:  Stack lift and rcl <matrix>
    model.userMode = false;
    mat.resize(model, 1, 1);
    controller.buttonDown(Operations15.matrix);
    controller.buttonDown(Operations.n1);
    model.xF = -5;
    controller.buttonDown(Operations15.sto15);
    controller.buttonDown(Operations15.eX15); // B
    controller.buttonUp();

    controller.buttonDown(Operations.enter);
    controller.buttonDown(Operations.n1);
    controller.buttonDown(Operations.enter);
    controller.buttonDown(Operations.n2);
    controller.buttonDown(Operations.enter);
    controller.buttonDown(Operations.n3);
    controller.buttonDown(Operations.enter);
    controller.buttonDown(Operations.n4);
    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.eX15); // B
    controller.buttonUp();
    expect(model.xF, -5);
    expect(model.yF, 4);
    expect(model.z, Value.fromDouble(3));
    expect(model.t, Value.fromDouble(2));
    controller.buttonDown(Operations.n5);
    expect(model.xF, 5);
    expect(model.yF, -5);
    expect(model.z, Value.fromDouble(4));
    expect(model.t, Value.fromDouble(3));

    controller.buttonDown(Operations.enter);
    controller.buttonDown(Operations.n1);
    controller.buttonDown(Operations.enter);
    controller.buttonDown(Operations.n2);
    controller.buttonDown(Operations.enter);
    controller.buttonDown(Operations.n3);
    controller.buttonDown(Operations.enter);
    controller.buttonDown(Operations15.rcl15);
    controller.buttonDown(Operations15.eX15); // B
    controller.buttonUp();
    expect(model.xF, -5);
    expect(model.yF, 3);
    expect(model.z, Value.fromDouble(2));
    expect(model.t, Value.fromDouble(1));
    controller.buttonDown(Operations.n5);
    expect(model.xF, 5);
    expect(model.yF, -5);
    expect(model.z, Value.fromDouble(3));
    expect(model.t, Value.fromDouble(2));

    mat.resize(model, 0, 0);
  }

  void _testScalar(NormalOperation op, double Function(double x, double y) f) {
    final values = [
      [1.1, -2.2, 3.3],
      [4.4, 5.5, 6.6],
    ];
    final scalarValues = [327.1, -56.0, 1.99, 42.24];
    final Matrix mat = model.matrices[0];
    final Matrix result = model.matrices[model.resultMatrix = 1];
    mat.resize(model, 2, 3);
    for (final s in scalarValues) {
      mat.visit((r, c) {
        model.yF = values[r][c];
        model.xF = s;
        controller.buttonDown(op);
        expect(Value.fromDouble(f(s, values[r][c])), model.x);
        mat.set(r, c, _toValue(values[r][c]));
      });
    }
    for (final s in scalarValues) {
      model.xF = s;
      model.y = Value.fromMatrix(0);
      controller.buttonDown(op);
      expect(model.x, Value.fromMatrix(1));
      expect(2, result.rows);
      expect(3, result.columns);
      result.visit((r, c) {
        expect(Value.fromDouble(f(s, values[r][c])), result.get(r, c));
      });
    }
    for (final s in scalarValues) {
      model.x = Value.fromMatrix(0);
      model.yF = s;
      controller.buttonDown(op);
      expect(model.x, Value.fromMatrix(1));
      expect(2, result.rows);
      expect(3, result.columns);
      result.visit((r, c) {
        expect(Value.fromDouble(f(values[r][c], s)), result.get(r, c));
      });
    }
  }

  void _play(List<CalculatorButton> script) {
    for (final b in script) {
      controller.buttonWidgetDown(b);
      controller.buttonUp();
    }
  }

  /// Stuff from chapter 12 of the 15C manual (Matrices)
  Future<void> _ch12() async {
    final l = layout;
    final mA = model.matrices[0];
    final mB = model.matrices[1];
    final mC = model.matrices[2];
    final mD = model.matrices[3];
    model.userMode = false;
    model.resultMatrix = 0;
    _play([l.fShift, l.chs, l.n0]); // F matrix 0
    _play([l.fShift, l.chs, l.n1]); // F matrix 1
    _play([l.fShift, l.rcl]); // F user
    _play([l.n2, l.enter, l.n3, l.fShift, l.sin, l.sqrt]); // 2, 3 f DIM A
    for (final n in [l.n1, l.n2, l.n3, l.n4, l.n5, l.n6]) {
      _play([n, l.sto, l.sqrt]); // n f STO A
    }
    expectMatrixVals(mA, [
      [1, 2, 3],
      [4, 5, 6],
    ]);
    _play([l.n2, l.sto, l.n0, l.n3, l.sto, l.n1, l.n9, l.sto, l.sqrt]);
    expectMatrixVals(mA, [
      [1, 2, 3],
      [4, 5, 9],
    ]);
    _play([l.n2, l.enter, l.n1, l.rcl, l.gShift, l.sqrt]);
    expect(model.x, Value.fromDouble(4));
    _play([l.rcl, l.chs, l.sqrt, l.sto, l.chs, l.eX, l.rcl, l.chs, l.eX]);
    _play([l.fShift, l.chs, l.n4]);
    expect(model.x, Value.fromMatrix(1));
    expectMatrixVals(mB, [
      [1, 4],
      [2, 5],
      [3, 9],
    ]);

    // p. 152:
    _play([l.fShift, l.eex, l.eX, l.rcl, l.chs, l.sqrt]); // result B, RCL mat A
    _play([l.n2, l.mult]);
    expect(model.x, Value.fromMatrix(1));
    _play([l.n1, l.minus]);
    expect(model.x, Value.fromMatrix(1));
    expectMatrixVals(mB, [
      [1, 3, 5],
      [7, 9, 17],
    ]);
    _play([l.fShift, l.eex, l.tenX, l.rcl, l.chs, l.eX]); // result C, RCL mat B
    _play([l.rcl, l.fShift, l.chs, l.sqrt, l.plus]); // Matrix add
    expect(model.x, Value.fromMatrix(2));
    expectMatrixVals(mC, [
      [2, 5, 8],
      [11, 14, 26],
    ]);
    _play([l.rcl, l.chs, l.eX]); // RCL mat B
    _play([l.rcl, l.fShift, l.chs, l.sqrt, l.minus]); // matrix subtract
    expect(model.x, Value.fromMatrix(2));
    expectMatrixVals(mC, [
      [0, 1, 2],
      [3, 4, 8],
    ]);

    _play([l.n0, l.enter, l.fShift, l.sin, l.tenX]); // dim(C) = 0,0
    expect(mC.length, 0);
    // Calculate transpose(A) * B using transpose, *
    _play([l.rcl, l.chs, l.sqrt, l.fShift, l.chs, l.n4]); // RCL A, transpose
    expect(model.x, Value.fromMatrix(0));
    _play([l.rcl, l.chs, l.eX, l.fShift, l.eex, l.tenX]); // RCL B, result C
    _play([l.mult]);
    expect(model.x, Value.fromMatrix(2));
    const aTstarB = [
      [29, 39, 73],
      [37, 51, 95],
      [66, 90, 168],
    ];
    expectMatrixVals(mC, aTstarB);
    _play([l.rcl, l.chs, l.sqrt, l.fShift, l.chs, l.n4]); // RCL A, transpose

    _play([l.n0, l.enter, l.fShift, l.sin, l.tenX]); // dim(C) = 0,0
    expect(mC.length, 0);
    // Calculate transpose(A) * B using matrix 5
    _play([l.rcl, l.chs, l.sqrt]); // RCL A
    expect(model.x, Value.fromMatrix(0));
    _play([l.rcl, l.chs, l.eX, l.fShift, l.eex, l.tenX]); // RCL B, result C
    _play([l.fShift, l.chs, l.n5]);
    expect(model.x, Value.fromMatrix(2));
    expectMatrixVals(mC, aTstarB);

    // p. 157:
    _play([l.n2, l.enter, l.fShift, l.sin, l.sqrt, l.fShift, l.chs, l.n1]);
    _play([l.n1, l.sto, l.sqrt, l.sto, l.sqrt]);
    _play([l.dot, l.n2, l.n4, l.sto, l.sqrt]);
    _play([l.dot, l.n8, l.n6, l.sto, l.sqrt]);
    _play([l.n2, l.enter, l.n3, l.fShift, l.sin, l.eX]);
    _play([l.n2, l.n7, l.n4, l.sto, l.eX]);
    _play([l.n2, l.n3, l.n3, l.sto, l.eX]);
    _play([l.n3, l.n3, l.n1, l.sto, l.eX]);
    _play([l.n1, l.n2, l.n0, l.dot, l.n3, l.n2, l.sto, l.eX]);
    _play([l.n1, l.n1, l.n2, l.dot, l.n9, l.n6, l.sto, l.eX]);
    _play([l.n1, l.n5, l.n1, l.dot, l.n3, l.n6, l.sto, l.eX]);
    _play([l.fShift, l.eex, l.yX]);
    _play([l.rcl, l.chs, l.eX, l.rcl, l.chs, l.sqrt]);
    _play([l.div]);
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(186));
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(141));
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(215));
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(88));
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(92));
    _play([l.rcl, l.yX]);
    expect(model.x, Value.fromDouble(116));

    // Residual, from advanced functions page 101
    mA.resize(model, 3, 3);
    final residO = [
      [33, 16, 72],
      [-24, -10, -57],
      [-8, -4, -17],
    ];
    mA.visit((r, c) => mA.set(r, c, _toValue(residO[r][c].toDouble())));
    mB.resize(model, 3, 3);
    mB.identity();
    _play([l.rcl, l.chs, l.sqrt, l.sto, l.chs, l.yX]); // RCL m A, STO m D
    expect(model.x, Value.fromMatrix(0));
    _play([l.rcl, l.chs, l.eX, l.rcl, l.chs, l.yX]); // RCL m b, RCL m D
    expect(model.z, Value.fromMatrix(0));
    expect(model.y, Value.fromMatrix(1));
    expect(model.x, Value.fromMatrix(3));
    _play([l.fShift, l.eex, l.tenX]);
    expect(model.z, Value.fromMatrix(0));
    expect(model.y, Value.fromMatrix(1));
    expect(model.x, Value.fromMatrix(3));
    _play([l.div]); // result C, divide
    // print(mC.formatValueWith((v) => v.asDouble.toStringAsFixed(9)));
    expect(model.y, Value.fromMatrix(0));
    expect(model.x, Value.fromMatrix(2));
    expectMatrixVals(mC, [
      [-9.666666881, -2.666666726, -32.00000071],
      [8.000000167, 2.500000046, 25.50000055],
      [2.666666728, 0.6666666836, 9.000000203],
    ], 0.000000015);
    _play([l.fShift, l.eex, l.eX]); // result B
    _play([l.fShift, l.chs, l.n6]); // Matrix 6 (residual)
    _play([l.rcl, l.chs, l.yX, l.div]); // RCL mat D, divide
    _play([l.rcl, l.chs, l.tenX, l.plus]); // RCL mat C, plus
    expectMatrixVals(mB, [
      [-9.666666667, -2.666666667, -32],
      [8, 2.5, 25.5],
      [2.666666667, 0.6666666667, 9],
    ]);

    // Complex matrices, page 163:
    _play([l.fShift, l.chs, l.n0, l.n2, l.enter, l.n4]);
    _play([l.fShift, l.sin, l.sqrt, l.fShift, l.chs, l.n1]);
    _play([l.n4, l.sto, l.sqrt]);
    _play([l.n3, l.sto, l.sqrt]);
    _play([l.n7, l.sto, l.sqrt]);
    _play([l.n2, l.chs, l.sto, l.sqrt]);
    _play([l.n1, l.sto, l.sqrt]);
    _play([l.n5, l.sto, l.sqrt]);
    _play([l.n3, l.sto, l.sqrt]);
    _play([l.n8, l.sto, l.sqrt]);
    _play([l.rcl, l.chs, l.sqrt]);
    _play([l.fShift, l.plus]); // Py,x
    expectMatrixVals(mA, [
      [4, 7],
      [1, 3],
      [3, -2],
      [5, 8],
    ]);
    _play([l.gShift, l.plus]); // Cy,x
    expectMatrixVals(mA, [
      [4, 3, 7, -2],
      [1, 5, 3, 8],
    ]);
    _play([l.fShift, l.plus]); // Py,x
    expectMatrixVals(mA, [
      [4, 7],
      [1, 3],
      [3, -2],
      [5, 8],
    ]);

    // Page 165:
    _play([l.rcl, l.chs, l.sqrt, l.fShift, l.chs, l.n2]); // RCL A, -> Ztilde
    _play([l.fShift, l.eex, l.eX, l.fShift, l.reciprocal]);
    expect(model.x, Value.fromMatrix(1));
    _play([l.fShift, l.chs, l.n3]);
    expectMatrixVals(mB, [
      [-0.02541436465, 0.2419889503],
      [-0.01215469613, -0.1016574586],
      [-0.2828729282, -0.002209944705],
      [0.1690607735, -0.1314917127],
    ], 1.5e-10);

    // page 167:
    _play([l.rcl, l.chs, l.sqrt, l.rcl, l.chs, l.eX]);
    _play([l.fShift, l.eex, l.tenX, l.mult]);
    expectMatrixVals(mC, [
      [1, -2.85e-10],
      [4e-11, 1],
      [1e-11, 3.8e-10],
      [1e-11, -1.05e-10],
    ], 1.5e-9);

    // page 170:
    _play([l.fShift, l.chs, l.n0, l.fShift, l.chs, l.n1]);
    _play([l.n4, l.enter, l.n2, l.fShift, l.sin, l.sqrt]);
    _play([l.n1, l.n0, l.sto, l.sqrt]);
    _play([l.n0, l.sto, l.sqrt, l.sto, l.sqrt, l.sto, l.sqrt]);
    _play([l.n2, l.n0, l.n0, l.sto, l.sqrt]);
    _play([l.chs, l.sto, l.sqrt, l.sto, l.sqrt]);
    _play([l.n1, l.n7, l.n0, l.sto, l.sqrt]);
    _play([l.n4, l.enter, l.n1, l.fShift, l.sin, l.eX]);
    _play([l.n0, l.sto, l.chs, l.eX]);
    _play([l.n5, l.enter, l.n1, l.enter, l.sto, l.gShift, l.eX]);
    expect(model.memory.registers[0], Value.fromDouble(1));
    expect(model.memory.registers[1], Value.fromDouble(1));
    _play([l.rcl, l.chs, l.eX, l.rcl, l.chs, l.sqrt]);
    expect(model.y, Value.fromMatrix(1));
    expect(model.x, Value.fromMatrix(0));
    _play([l.fShift, l.chs, l.n2, l.fShift, l.eex, l.tenX, l.div]);
    expect(model.x, Value.fromMatrix(2));
    _play([l.gShift, l.plus]);
    expectMatrixVals(mC, [
      [0.03715608128, 0.1311391104],
      [0.04371303680, 0.1542813064],
    ], 1.5e-10);

    void testMatrixAccess(
      List<CalculatorButton> op,
      double val,
      double r, [
      double? xr,
    ]) {
      void forMatrix(CalculatorButton matButton, Matrix mat) {
        model.userMode = false;
        mat.resize(model, 2, 3);
        model.memory.registers[0] = Value.fromDouble(2);
        model.memory.registers[1] = Value.fromDouble(3);
        mat.set(1, 2, _toValue(val));
        _play(op);
        controller.buttonWidgetDown(matButton);
        controller.buttonUp();
        expect(mat.get(1, 2), Value.fromDouble(r));
        if (xr != null) {
          expect(model.x, Value.fromDouble(xr));
        }
        mat.resize(model, 0, 0);
      }

      final x = model.x;
      forMatrix(l.tenX, mC); // C
      model.x = x;
      model.memory.registers.index = Value.fromMatrix(1);
      forMatrix(l.cos, mB); // (i)
    }

    model.xF = 1.2;
    testMatrixAccess([l.sto, l.plus], 40.8, 42);
    testMatrixAccess([l.sto, l.minus], 43.2, 42);
    testMatrixAccess([l.sto, l.mult], 100, 120);
    testMatrixAccess([l.sto, l.div], 120, 100);
    testMatrixAccess([l.fShift, l.n4], 100, 1.2); // swap
    testMatrixAccess([l.fShift, l.n4], -3.00104, 100); // swap
    expect(model.x, Value.fromDouble(-3.00104));
    testMatrixAccess([l.fShift, l.n6], -7.00402, -5.00402); // isg
    testMatrixAccess([l.fShift, l.n5], 1.00204, -3.00204); // dse
    model.xF = 1.2;
    testMatrixAccess([l.rcl, l.plus], 40.8, 40.8, 42);
    model.xF = 1.2;
    testMatrixAccess([l.rcl, l.minus], 43.2, 43.2, -42);
    model.xF = 1.2;
    testMatrixAccess([l.rcl, l.mult], 42, 42, 50.4);
    model.xF = -50.4;
    testMatrixAccess([l.rcl, l.div], -1.2, -1.2, 42);

    // Conditional tests on matrix descriptors, p. 174
    _play([l.gShift, l.rs, l.fShift, l.rdown, l.fShift, l.sst, l.sqrt]);
    // Program mode, clear program, label A
    _play([l.rcl, l.chs, l.reciprocal, l.gShift, l.mult]); // E = 0
    _play([l.n2, l.n1, l.sto, l.n0]); // (skip 2)1 sto 0
    _play([l.rcl, l.chs, l.reciprocal, l.gShift, l.minus, l.n0]); // E != 0
    _play([l.n4, l.n2, l.sto, l.plus, l.n0]); // (4)2 sto + 0
    _play([l.rcl, l.chs, l.reciprocal, l.enter, l.gShift, l.minus, l.n5]);
    // E = E
    _play([l.n5, l.n5, l.sto, l.plus, l.n0]); // (5)5 sto + 0
    _play([l.rcl, l.chs, l.reciprocal, l.rcl, l.chs, l.yX]);
    _play([l.gShift, l.minus, l.n5]); // E = D
    _play([l.n2, l.n1, l.sto, l.n1]); // (skip 2)1 sto 1
    _play([l.rcl, l.chs, l.reciprocal, l.n0, l.gShift, l.minus, l.n6]);
    // E != 0
    _play([l.n4, l.n2, l.sto, l.plus, l.n1]); // (4)2 sto + 1
    _play([l.rcl, l.n0, l.rcl, l.n1]);
    _play([l.gShift, l.rs]); // P/R
    _play([l.gsb, l.sqrt]); // GSB A
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(model.yF, 98);
    expect(model.xF, 43);

    // Matrix stack operations, p. 174-175
    model.userMode = true;
    _play([l.fShift, l.chs, l.n0]); // F matrix 0
    // Dim A and B to 2x2, and store 1 2 3 4 in A, 5 6 7 8 in B
    _play([l.n2, l.enter, l.fShift, l.sin, l.sqrt, l.fShift, l.sin, l.eX]);
    _play([l.fShift, l.chs, l.n1]);
    _play([l.n1, l.sto, l.sqrt]);
    _play([l.n2, l.sto, l.sqrt]);
    _play([l.n3, l.sto, l.sqrt]);
    _play([l.n4, l.sto, l.sqrt]);
    _play([l.n5, l.sto, l.eX]);
    _play([l.n6, l.sto, l.eX]);
    _play([l.n7, l.sto, l.eX]);
    _play([l.n8, l.sto, l.eX]);
    _play([l.fShift, l.eex, l.tenX]); // Result C
    _play([l.n6, l.enter, l.n5, l.enter, l.n4, l.enter]);
    _play([l.rcl, l.chs, l.sqrt]); // rcl matrix a
    _play([l.fShift, l.reciprocal]);
    expect(model.x, Value.fromMatrix(2));
    expect(model.y, Value.fromDouble(4));
    expect(model.z, Value.fromDouble(5));
    expect(model.getStackByIndex(3), Value.fromDouble(6));
    expect(model.lastX, Value.fromMatrix(0));

    _play([l.n6, l.enter, l.n5, l.enter, l.n4, l.enter]);
    _play([l.rcl, l.chs, l.eX, l.rcl, l.chs, l.sqrt]); // rcl matrix a, b
    _play([l.mult]);
    expect(model.x, Value.fromMatrix(2));
    expect(model.y, Value.fromDouble(4));
    expect(model.z, Value.fromDouble(5));
    expect(model.getStackByIndex(3), Value.fromDouble(5));
    expect(model.lastX, Value.fromMatrix(0));

    // p. 176
    model.lastX = Value.fromDouble(1234);
    _play([l.n4, l.enter, l.n4, l.n2, l.enter, l.n1, l.enter, l.n2]);
    _play([l.sto, l.gShift, l.sqrt]);
    expect(model.x, Value.fromDouble(42));
    expect(model.y, Value.fromDouble(4));
    expect(model.z, Value.fromDouble(4));
    expect(model.getStackByIndex(3), Value.fromDouble(4));
    expect(model.lastX, Value.fromDouble(1234));

    _play([l.n5, l.enter, l.n4, l.enter, l.n1, l.enter, l.n2]);
    _play([l.rcl, l.gShift, l.sqrt]);
    expect(model.x, Value.fromDouble(42));
    expect(model.y, Value.fromDouble(4));
    expect(model.z, Value.fromDouble(5));
    expect(model.getStackByIndex(3), Value.fromDouble(5));
    expect(model.lastX, Value.fromDouble(1234));

    // p. 177
    model.userMode = true;
    _play([l.fShift, l.chs, l.n1]); // Matrix 1
    _play([l.rcl, l.chs, l.yX, l.sto, l.tan]); // Store "D" to I
    _play([l.n2, l.enter, l.fShift, l.sin, l.tan]); // dim D to 2x2
    // That tested f-DIM-I
    for (final n in [l.n3, l.n5, l.n7, l.n2]) {
      _play([n, l.sto, l.yX]); // sto D
    }
    model.userMode = false;
    _play([l.gShift, l.rs, l.fShift, l.rdown, l.fShift, l.sst, l.sqrt]);
    // Program mode, clear program, label A
    _play([l.fShift, l.chs, l.n1]); // Matrix 1
    _play([l.fShift, l.sst, l.n4]); // label 4
    _play([l.rcl, l.yX, l.gShift, l.sqrt]); // rcl D, x^2
    _play([l.fShift, l.rcl]); // toggle user mode
    _play([l.sto, l.yX]); // sto D
    _play([l.fShift, l.rcl]); // toggle user mode
    _play([l.gto, l.n4]);
    _play([l.gShift, l.rs]); // P/R
    expectMatrixVals(mD, [
      [3, 5],
      [7, 2],
    ]);
    _play([l.gsb, l.sqrt]); // GSB A
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expectMatrixVals(mD, [
      [3 * 3, 5 * 5],
      [7 * 7, 2 * 2],
    ]);
    // Check that row-norm and Frobenius norm act as conditional branch
    for (final asProgram in [true, false]) {
      for (final test in [l.n7, l.n8]) {
        for (final mat in [true, false]) {
          if (asProgram) {
            _play([l.gShift, l.rs, l.fShift, l.rdown, l.fShift, l.sst, l.sqrt]);
          } else {
            model.program.currentLine = 3; // A known value
          }
          if (mat) {
            _play([l.rcl, l.chs, l.yX]); // rcl matrix D
          } else {
            _play([l.n7]);
          }
          _play([l.fShift, l.chs, test]); // f matrix test
          _play([l.n4, l.n2, l.enter]);
          if (asProgram) {
            _play([l.gShift, l.rs]); // P/R
            _play([l.gsb, l.sqrt]); // GSB A
            expect(await out.moveNext(), true);
            expect(out.current, ProgramEvent.done);
            if (mat) {
              expect(model.xF, 42); // skip
            } else {
              expect(model.xF, 2); // skip
            }
          } else {
            expect(model.xF, 42); // no skip
            expect(model.program.currentLine, 3);
          }
        }
      }
    }

    setMatrix(model, mD, [
      [1, 2.7, -3],
      [5, 24, 0.33],
    ]);
    _play([l.rcl, l.chs, l.yX]);
    expect(model.x, Value.fromMatrix(3));
    _play([l.chs]); // rcl mat D, chs
    expect(model.x, Value.fromMatrix(3));
    expectMatrixVals(mD, [
      [-1, -2.7, 3],
      [-5, -24, -0.33],
    ]);

    setMatrix(model, mD, [
      [1, 2.7, -3],
      [5, 24, 0.33],
      [-31, 3.14, -6.22],
    ]);
    _play([l.rcl, l.chs, l.yX, l.fShift, l.chs, l.n7]); // mat 7 on D
    expect(model.xF, 40.36);
    _play([l.rcl, l.chs, l.yX, l.fShift, l.chs, l.n8]); // mat 8 on D
    expect(model.xF, 40.34782398);
    _play([l.rcl, l.chs, l.yX, l.fShift, l.chs, l.n9]); // mat 9 on D
    expect(model.xF, -2373.067200);

    // p. 178, misc. matrix addressing:
    setMatrix(model, mD, [
      [1, 2.7, -3],
      [5, 24, 0.33],
      [-31, 3.14, -6.22],
    ]);
    setMatrix(model, mC, [
      [19, 20.7, -73],
      [19, 27, 2.33],
      [-310, 0.314, -6.22222],
      [22.1, 22.2, 22.3],
    ]);
    _play([l.rcl, l.chs, l.tenX, l.sto, l.tan]); // I := mC
    _play([l.n2, l.sto, l.n0, l.n3, l.sto, l.n1]); // r = 2, c = 3
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.rcl, l.cos]); // rcl (i), that is, C
    expect(model.xF, 2.33);
    _play([l.rcl, l.tenX]); // rcl C
    expect(model.xF, 2.33);
    _play([l.rcl, l.yX]); // rcl D
    expect(model.xF, 0.33);
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.n7, l.enter, l.n3, l.enter, l.n1]); // z = 7, y/r = 3, x/c = 1
    _play([l.rcl, l.gShift, l.cos]); // rcl g (i), that is, C
    expect(model.xF, -310);
    expect(model.yF, 7);
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.n7, l.enter, l.n3, l.enter, l.n1]); // z = 7, y/r = 3, x/c = 1
    _play([l.rcl, l.gShift, l.tenX]); // rcl g C
    expect(model.xF, -310);
    expect(model.yF, 7);
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.n7, l.enter, l.n3, l.enter, l.n1]); // z = 7, y/r = 3, x/c = 1
    _play([l.rcl, l.gShift, l.yX]); // rcl g D
    expect(model.xF, -31);
    expect(model.yF, 7);

    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.rcl, l.sin, l.yX]); // rcl dim D
    expect(model.xF, 3);
    expect(model.yF, 3);
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.rcl, l.sin, l.tan]); // rcl dim I, that is, C
    expect(model.xF, 3);
    expect(model.yF, 4);

    _play([l.rcl, l.chs, l.eX, l.sto, l.eex]); // rcl mat B, sto result
    _play([l.n0, l.enter, l.enter, l.enter]);
    _play([l.rcl, l.eex]); // rcl result
    expect(model.x, Value.fromMatrix(1));
    _play([l.fShift, l.eex, l.yX]); // f result D
    _play([l.rcl, l.eex]); // rcl result
    expect(model.x, Value.fromMatrix(3));

    model.userMode = false;
    setMatrix(model, mD, [
      [1.1, 2.2],
    ]);
    _play([l.rcl, l.chs, l.yX, l.sto, l.tan]); // I := D
    _play([l.fShift, l.chs, l.n1]); // F matrix 1
    _play([l.n3, l.sto, l.yX]);
    expectMatrixVals(mD, [
      [3, 2.2],
    ]);
    _play([l.fShift, l.rcl]); // toggle user mode
    _play([l.n4, l.sto, l.cos]);
    _play([l.n5, l.sto, l.yX, l.n6, l.sto, l.cos]);
    expectMatrixVals(mD, [
      [6, 5],
    ]);
    _play([l.fShift, l.rcl]); // toggle user (to off)
    setMatrix(model, mD, [
      [1.1, 2.2],
      [3.1, 4.2],
      [5.1, 6.2],
    ]);
    _play([l.n1, l.enter, l.n3, l.enter, l.n2, l.sto, l.gShift, l.yX]);
    expectMatrixVals(mD, [
      [1.1, 2.2],
      [3.1, 4.2],
      [5.1, 1],
    ]);
    _play([l.n2, l.chs, l.enter, l.n2, l.enter, l.n1, l.sto, l.gShift, l.cos]);
    expectMatrixVals(mD, [
      [1.1, 2.2],
      [-2, 4.2],
      [5.1, 1],
    ]);

    _play([l.rcl, l.chs, l.yX, l.sto, l.chs, l.sqrt]); // A := D
    expectMatrixVals(mA, [
      [1.1, 2.2],
      [-2, 4.2],
      [5.1, 1],
    ]);
    _play([l.n9, l.chs, l.sto, l.chs, l.sqrt]); // A := 9
    expectMatrixVals(mA, [
      [-9, -9],
      [-9, -9],
      [-9, -9],
    ]);

    final testOpAndResults = [
      [
        l.plus,
        [
          [8.2, 10.4],
          [9.2, 13.4],
        ],
        [
          [-36.8, -35.7],
          [-34.8, -33.7],
        ],
      ],
      [
        l.minus,
        [
          [-6, -6],
          [-3, -5],
        ],
        [
          [39, 40.1],
          [41, 42.1],
        ],
        [
          [-39, -40.1],
          [-41, -42.1],
        ],
      ],
      [
        l.mult,
        [
          [21.23, 29.26],
          [47.63, 64.06],
        ],
        [
          [-41.69, -83.38],
          [-117.49, -159.18],
        ],
      ],
      [
        l.div,
        [
          [-1, -0.9281045754],
          [1, 1.071895425],
        ],
        [
          [-0.02902374670, -0.05804749340],
          [-0.08179419525, -0.1108179420],
        ],
        [
          [72.35454545, -37.9],
          [-53.40454545, 18.95],
        ],
      ],
    ];
    // Test +, -, *, and / on matrices and scalars
    _play([l.fShift, l.eex, l.tenX]); // f result C
    for (final tor in testOpAndResults) {
      for (var i = 0; i < 3; i++) {
        setMatrix(model, mA, [
          [1.1, 2.2],
          [3.1, 4.2],
        ]);
        _play([l.rcl, l.chs, l.sqrt]); // rcl matrix A
        if (i == 0) {
          setMatrix(model, mB, [
            [7.1, 8.2],
            [6.1, 9.2],
          ]);
          _play([l.rcl, l.chs, l.eX]); // rcl matrix B
          _play([tor[0] as CalculatorButton]);
          expectMatrixVals(mC, tor[1] as List<List<num>>);
        } else {
          _play([l.n3, l.n7, l.dot, l.n9, l.chs]); // -37.9
          if (i == 2) {
            _play([l.xy]);
          }
          _play([tor[0] as CalculatorButton]);
          if (tor.length == 3) {
            // Same result x<-->y or no
            expectMatrixVals(mC, tor[2] as List<List<num>>);
          } else {
            expectMatrixVals(mC, tor[i + 1] as List<List<num>>);
          }
        }
      }
    }

    model.userMode = false;
    _play([l.fShift, l.chs, l.n0]); // F matrix 0
  }

  /// Stuff from chapter 13 of the 15C manual (solve)
  Future<void> _ch13() async {
    final l = layout;
    model.userMode = false;
    model.memory.numRegisters = 10;
    _play([l.gShift, l.rs, l.fShift, l.rdown]); // Program, clear program
    _play([l.fShift, l.sst, l.sqrt]); // f LBL A
    _play([l.n0, l.enter, l.n1, l.fShift, l.div, l.eX]); // 0, 0 f solve B
    _play([l.gShift, l.gsb]); // g RTN
    _play([l.fShift, l.sst, l.eX]); // f LBL B
    _play([l.n1, l.sto, l.plus, l.n9]); // 1, sto + 9
    _play([l.gsb, l.eX]); // GSB B (infinite recursive loop)
    _play([l.gShift, l.rs]); // P/R

    model.memory.registers[9] = Value.fromDouble(0);
    _play([l.gsb, l.eX]); // GSB B
    await out.moveNext();
    expect(out.current.errorNumber, 5);
    expect(model.display.current, '   error 5  ');
    // Check stack depth:
    expect(model.memory.registers[9], Value.fromDouble(8));
    _play([l.n0]); // Clear error and get back to normal state

    // Same test again, to test if failing due to an error caused
    // a problem.
    model.memory.registers[9] = Value.fromDouble(0);
    _play([l.gsb, l.eX]); // GSB B
    await out.moveNext();
    expect(out.current.errorNumber, 5);
    expect(model.display.current, '   error 5  ');
    // Check stack depth:
    expect(model.memory.registers[9], Value.fromDouble(8));
    _play([l.n0]); // Clear error and get back to normal state

    model.memory.registers[9] = Value.fromDouble(0);
    _play([l.fShift, l.div, l.eX]); // solve B
    await out.moveNext();
    expect(out.current.errorNumber, 5);
    expect(model.memory.registers[9], Value.fromDouble(8));
    _play([l.n0]); // Clear error and get back to normal state

    model.memory.registers[9] = Value.fromDouble(0);
    _play([l.gsb, l.sqrt]); // GSB A, to call solve from subroutine
    await out.moveNext();
    expect(out.current.errorNumber, 5);
    expect(model.memory.registers[9], Value.fromDouble(6));
    _play([l.n0]); // Clear error and get back to normal state

    // Find sqrt(2) the hard way
    _play([l.gShift, l.rs, l.fShift, l.rdown]); // Program, clear program
    _play([l.fShift, l.sst, l.sqrt]); // f LBL A
    _play([l.n0, l.enter, l.n2, l.fShift, l.div, l.eX]); // 0, 2 f solve B
    _play([l.gShift, l.gsb]); // g RTN
    _play([l.fShift, l.sst, l.eX]); // f LBL B
    _play([l.gShift, l.sqrt, l.n2, l.minus]);
    _play([l.gShift, l.gsb]); // g RTN
    _play([l.gShift, l.rs]); // P/R
    _play([l.gsb, l.sqrt]); // GSB A
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(model.xF, 1.414213562);
    expect(model.yF, 1.414213562);
    expect(model.z.asDouble.abs() <= 1e-9, true);

    // Example from page 182
    _play([l.gShift, l.rs, l.fShift, l.rdown]); // Program, clear program
    _play([l.fShift, l.sst, l.n0]); // f LBL 0
    _play([l.n3, l.minus, l.mult, l.n1, l.n0, l.minus]);
    _play([l.gShift, l.gsb]); // g RTN
    _play([l.gShift, l.rs]); // P/R
    _play([l.n0, l.enter, l.n1, l.n0]);
    _play([l.fShift, l.div, l.n0]); // f solve 0
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(model.xF, 5);
    expect(model.yF, 4.999999922);
    expect(model.z.asDouble.abs() < 1e-9, true);

    model.yF = 0;
    model.xF = -10;
    _play([l.fShift, l.div, l.n0]); // f solve 0
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(model.xF, -2);
    expect(model.yF, -2.000001296);
    expect(model.z.asDouble.abs() < 1e-9, true);

    // Example from page 184:
    _play([l.gShift, l.rs, l.fShift, l.rdown]); // Program, clear program
    _play([l.fShift, l.sst, l.sqrt]); // f LBL A
    _play([l.n2, l.n0, l.div, l.chs, l.eX, l.chs]);
    _play([l.n1, l.plus, l.n5, l.n0, l.n0, l.n0, l.mult]);
    _play([l.xy, l.n2, l.n0, l.n0, l.mult, l.minus]);
    _play([l.gShift, l.gsb]); // g RTN
    _play([l.fShift, l.sst, l.eX]); // f LBL B
    _play([l.n5, l.enter, l.n6]);
    _play([l.fShift, l.div, l.sqrt]); // f solve A
    _play([l.n4, l.n2]); // 42 (or 2, if solve fails)
    _play([l.gShift, l.rs]); // P/R

    _play([l.n5, l.enter, l.n6]);
    _play([l.fShift, l.div, l.sqrt]); // f solve A
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(model.xF, 9.284255091);
    expect(model.yF, 9.284255115);
    expect(model.z.asDouble.abs() < 1e-9, true);

    // Test "do if true" if solve A done in program B
    _play([l.gsb, l.eX]); // GSB B
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(model.xF, 42);
    expect(model.yF, 9.284255091);

    // Example from page 186:
    _play([l.gShift, l.rs, l.fShift, l.rdown]); // Program, clear program
    _play([l.fShift, l.sst, l.sqrt]); // f LBL A
    _play([l.gShift, l.chs, l.n1, l.plus]);
    _play([l.gShift, l.gsb]); // g RTN
    _play([l.fShift, l.sst, l.eX]); // f LBL B
    _play([l.n1, l.enter, l.n1, l.chs]);
    _play([l.fShift, l.div, l.sqrt]); // f solve A
    _play([l.n4, l.n2]); // 42 (or 2, if solve fails)
    _play([l.gShift, l.rs]); // P/R

    _play([l.n1, l.enter, l.n1, l.chs]);
    _play([l.fShift, l.div, l.sqrt]); // f solve A
    expect(await out.moveNext(), true);
    expect(out.current.errorNumber, 8);
    _play([l.gsb]); // clear error

    // Test "do if true" if solve A done in program B
    _play([l.gsb, l.eX]); // GSB B
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(model.xF, 2);

    // Example from page 189:
    _play([l.gShift, l.rs, l.fShift, l.rdown]); // Program, clear program
    _play([l.fShift, l.sst, l.dot, l.n3]); // f LBL .3
    _play([l.n6, l.minus, l.mult, l.n8, l.plus, l.mult, l.n4, l.mult]);
    _play([l.n7, l.dot, l.n5, l.minus]);
    _play([l.gShift, l.rs]); // P/R

    _play([l.n1, l.enter, l.n2]);
    _play([l.fShift, l.div, l.dot, l.n3]); // f solve .3
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect(model.xF, 1.5);
    expect(model.yF, 1.499999992);
    expect(model.z.asDouble, 0);
  }

  // Chapter 14:  integrate
  Future<void> _ch14() async {
    final l = layout;
    model.userMode = false;
    model.memory.numRegisters = 10;
    _play([l.gShift, l.n8]); // g-rad

    // Find that the integral of sin from 0 to pi is 2
    _play([l.gShift, l.rs, l.fShift, l.rdown]); // Program, clear program
    _play([l.fShift, l.sst, l.sqrt]); // f LBL A
    _play([l.sin]);
    _play([l.gShift, l.rs]); // P/R
    _play([l.n0, l.gShift, l.eex]); // 0 g-PI
    _play([l.fShift, l.mult, l.sqrt]); // f integrate a
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect((model.xF - 2).abs() < 0.0000001, true, reason: '${model.xF - 2}');
    expect(model.yF.abs() < 0.00009, true);
    expect(model.z, Value.fromDouble(dart.pi));
    expect(model.t.asDouble, 0);

    // P. 195
    _play([l.gShift, l.rs, l.fShift, l.rdown]); // Program, clear program
    _play([l.fShift, l.sst, l.dot, l.n9]); // f LBL .9
    _play([l.sin, l.cos, l.gShift, l.gsb]); // cos sin g-rtn
    _play([l.gShift, l.rs]); // P/R
    _play([l.n0, l.gShift, l.eex]); // 0 g-PI
    _play([l.fShift, l.mult, l.dot, l.n9]); // f integrate .9
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect((model.xF - 2.403939).abs() < 0.00001, true);
    expect(model.yF.abs() < 0.00005, true);
    expect(model.z, Value.fromDouble(dart.pi));
    expect(model.t.asDouble, 0);

    // P. 197-8
    _play([l.gShift, l.rs, l.fShift, l.rdown]); // Program, clear program
    _play([l.fShift, l.sst, l.dot, l.n9]); // f LBL .9
    _play([l.sin, l.minus, l.cos]);
    _play([l.gShift, l.rs]); // P/R
    _play([l.n0, l.gShift, l.eex]); // 0 g-PI
    _play([l.fShift, l.mult, l.dot, l.n9]); // f integrate .9
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect((model.xF - 1.38246).abs() < 0.00001, true);
    expect(model.yF.abs() < 0.00005, true);

    // P. 199:  sin(x)/x
    _play([l.gShift, l.rs, l.fShift, l.rdown]); // Program, clear program
    _play([l.fShift, l.sst, l.dot, l.n2]); // f LBL .2
    _play([l.sin, l.xy, l.div]);
    _play([l.gShift, l.rs]); // P/R
    _play([l.n0, l.enter, l.n2]); // 0 g-PI
    _play([l.fShift, l.mult, l.dot, l.n2]); // f integrate .2
    expect(await out.moveNext(), true);
    expect(out.current, ProgramEvent.done);
    expect((model.xF - 1.60541).abs() < 0.00001, true);
    expect(model.yF.abs() < 0.00005, true);

    // Issue 115:  RCL (i) shouldn't set LastX
    _play([l.n0, l.sto, l.tan, l.sto, l.n0]); // Store 0 in I and R0
    _play([l.n1, l.n0, l.sqrt, l.rcl, l.cos, l.gShift, l.enter]);
    expect(model.xF, 10.0);
    // Now try with a matrix in R0
    _play([l.rcl, l.chs, l.sqrt, l.sto, l.n0]);
    _play([l.n1, l.n0, l.sqrt, l.rcl, l.cos, l.gShift, l.enter]);
    expect(model.xF, 10.0);
  }

  // Misc.
  Future<void> _misc2() async {
    final l = layout;
    model.userMode = false;
    for (final sign in [-1.0, 1.0]) {
      for (final roundMode in [l.n7, l.n8, l.n9]) {
        // FIX, SCI, ENG
        _play([l.fShift, roundMode, l.n1]);
        model.xF = sign * 1.234567891;
        _play([l.gShift, l.xy]); // round
        expect(model.x, Value.fromDouble(sign * 1.2));
        model.xF = sign * 1.294567891;
        _play([l.gShift, l.xy]); // round
        expect(model.x, Value.fromDouble(sign * 1.3));
        model.xF = sign * 9.999999998e99;
        _play([l.gShift, l.xy]); // round
        expect(model.x, Value.fromDouble(sign * 9.999999998e99));
      }
      _play([l.fShift, l.n7, l.n2]); // FIX 2
      model.xF = sign * 12.34567891;
      _play([l.gShift, l.xy]); // round
      expect(model.x, Value.fromDouble(sign * 12.35));
      model.xF = sign * 12.34467891;
      _play([l.gShift, l.xy]); // round
      expect(model.x, Value.fromDouble(sign * 12.34));
      model.xF = sign * 0.1235467891;
      _play([l.gShift, l.xy]); // round
      expect(model.x, Value.fromDouble(sign * 0.12));
      model.xF = sign * 0.1255467891;
      _play([l.gShift, l.xy]); // round
      expect(model.x, Value.fromDouble(sign * 0.13));
      model.xF = sign * 9.999999998e98;
      _play([l.gShift, l.xy]); // round
      expect(model.x, Value.fromDouble(sign * 9.999999998e98));
      model.xF = sign * 1.2345668e-32;
      _play([l.gShift, l.xy]); // round
      expect(model.x, Value.zero);
      model.xF = sign * 0.005;
      _play([l.gShift, l.xy]); // round
      expect(model.x, Value.fromDouble(sign * 0.01));
      model.xF = sign * 0.004999999999;
      _play([l.gShift, l.xy]); // round
      expect(model.x, Value.zero);
      for (final roundMode in [l.n8, l.n9]) {
        // SCI, ENG
        for (final mult in [
          1.0,
          10.0,
          100.0,
          1000.0,
          10000.0,
          1e70,
          1e-70,
          1e71,
          1e-71,
          1e72,
          1e-72,
        ]) {
          _play([l.fShift, roundMode, l.n3]);
          model.xF = sign * 1.234567891 * mult;
          _play([l.gShift, l.xy]); // round
          expect(model.x, Value.fromDouble(sign * 1.235 * mult));
          model.xF = sign * 1.234499999 * mult;
          _play([l.gShift, l.xy]); // round
          expect(model.x, Value.fromDouble(sign * 1.234 * mult));
        }
      }
    }
    model.xF = 42;
    _play([l.fShift, l.sin, l.cos]); // f DIM (i)
    model.setXYZT(Value.zero);
    _play([l.rcl, l.sin, l.cos]); // RCL DIM (i)
    expect(model.xF, 42);
    model.xF = 19;
    _play([l.fShift, l.sin, l.fShift, l.cos]); // f DIM (i)
    model.setXYZT(Value.zero);
    _play([l.rcl, l.fShift, l.sin, l.fShift, l.cos]); // RCL DIM (i)
    expect(model.xF, 19);

    // Check rcl op # stack lift behavior
    _play([l.n9, l.sto, l.n3]);
    for (final swap in [false, true]) {
      _play([l.n7, l.enter, l.plus]);
      expect(model.lastX, Value.fromDouble(7));
      _play([l.n1, l.enter, l.n2, l.enter, l.n3, l.enter, l.n4]);
      if (swap) {
        _play([l.xy, l.xy]); // Enables stack lift
      }
      _play([l.rcl, l.minus, l.n3]);
      expect(model.xF, -5);
      expect(model.yF, 3);
      expect(model.z.asDouble, 2);
      expect(model.t.asDouble, 1);
      _play([l.n8]);
      expect(model.xF, 8);
      expect(model.yF, -5);
      expect(model.z.asDouble, 3);
      expect(model.t.asDouble, 2);
      _play([l.enter]);
      expect(model.lastX, Value.fromDouble(7)); // From way back when
    }
  }

  Future<void> runWithComplex(bool complex) async {
    model.isComplexMode = complex;
    await _ch12();
    // print("listing:  ${JsonEncoder.withIndent('  ').convert(model.memory.toJson(comments: true))}");
    _page146();
    _stoMatrixAndChs();
    _invertMatrix(true);
    _invertMatrix(false);
    _singularMatrix();
    _transpose();
    _complexMatrix();
    _misc();
    // Operations15.div is tested at the end of the ch. 12 tests.
    // scalar div matrix doesn't behave like _testScalar is built to handle.
    _testScalar(Operations15.mult, (x, y) => y * x);
    _testScalar(Operations15.plus, (x, y) => y + x);
    _testScalar(Operations15.minus, (x, y) => y - x);
    model.isComplexMode = false;
  }

  // Test f-FIX-I
  Future<void> _bug65() async {
    final l = layout;
    model.xF = 1.2345678;
    _play([l.fShift, l.n7, l.n5]);
    expect(model.display.current, ' 1.23457    ');
    _play([l.fShift, l.n7, l.n1]);
    expect(model.display.current, ' 1.2        ');
    model.xF = 3;
    _play([l.sto, l.tan, l.gShift, l.bsp, l.fShift, l.n7, l.tan]);
    model.xF = 1.2345678;
    _play([l.enter]);
    expect(model.display.current, ' 1.235      ');
    model.xF = 4;
    _play([l.sto, l.tan, l.gShift, l.bsp, l.fShift, l.n7, l.tan]);
    model.xF = 1.2345678;
    _play([l.enter]);
    expect(model.display.current, ' 1.2346     ');
  }

  Future<void> run() async {
    await _bug65();
    await _statistics();
    await _page139(asProgram: false);
    await _page139(asProgram: true);
    await runWithComplex(false);
    await runWithComplex(true);
    await _ch13();
    await _ch14();
    await _misc2();
  }

  void expectMatrix(AMatrix m, AMatrix expected, [double epsilon = 0]) {
    expect(m.rows, expected.rows);
    expect(m.columns, expected.columns);
    m.visit((r, c) {
      bool bad = false;
      if (epsilon == 0) {
        if (m.get(r, c) != expected.get(r, c)) {
          bad = true;
        }
      } else if ((m.getF(r, c) - expected.getF(r, c)).asDouble.abs() >
          epsilon) {
        print('Value differs by ${(m.getF(r, c) - expected.getF(r, c)).abs()}');
        print('    This is more than tolerance of $epsilon');
        print('Expected: $expected');
        bad = true;
      }
      if (bad) {
        print('Matrix value ($r,$c) bad.  Matrix:  $m');
        print('Expected:  $expected');
        expect(bad, false);
      }
    });
  }

  void expectMatrixVals(
    AMatrix m,
    List<List<num>> expected, [
    final double epsilon = 0,
  ]) {
    expect(m.rows, expected.length);
    for (int r = 0; r < expected.length; r++) {
      final row = expected[r];
      expect(m.columns, row.length);
      for (int c = 0; c < row.length; c++) {
        bool bad = false;
        if (epsilon == 0) {
          if (m.get(r, c) != Value.fromDouble(row[c].toDouble())) {
            print('${m.get(r, c)} != ${Value.fromDouble(row[c].toDouble())}');
            bad = true;
          }
        } else if ((m.get(r, c).asDouble - row[c]).abs() > epsilon) {
          print('Value differs by ${(m.get(r, c).asDouble - row[c]).abs()}');
          print('    This is more than tolerance of $epsilon');
          // print(m.getF(r, c).toStringAsFixed(10));
          // print(row[c].toStringAsFixed(10));
          bad = true;
        }
        if (bad) {
          print('Matrix value ($r,$c) bad.  Matrix:  $m');
          print('Expected:  $expected');
          expect(bad, false);
        }
      }
    }
  }

  void setMatrix(Model15 model, Matrix m, List<List<num>> val) {
    if (val.isEmpty) {
      m.resize(model, 0, 0);
    } else {
      m.resize(model, val.length, val[0].length);
    }
    m.visit((r, c) => m.set(r, c, _toValue(val[r][c].toDouble())));
  }
}

String formatDouble(double v, int digits) {
  String r = v.toStringAsFixed(digits);
  if (r.startsWith('-')) {
    double d = double.parse(r);
    if (d == 0) {
      r = 0.toStringAsFixed(digits);
    }
  }
  return r;
}

Future<void> valueExponentTest() async {
  for (int e = -99; e <= 99; e++) {
    final d = double.parse('5e$e');
    expect(
      Value.fromDouble(d).asDouble.toStringAsExponential(10),
      d.toStringAsExponential(10),
    );
  }
  expect(Value.fromDouble(5e-100).asDouble, 0.0);
  expect(Value.fromDouble(-5e-100).asDouble, 0.0);
  try {
    expect(Value.fromDouble(5e100), false);
  } on FloatOverflow catch (e) {
    expect(e.infinity, Value.fMaxValue);
  }
  try {
    expect(Value.fromDouble(-5e100), false);
  } on FloatOverflow catch (e) {
    expect(e.infinity, Value.fMinValue);
  }
}

Future<void> valueFracOpTest() async {
  expect(
    Value.fromDouble(0.0000000001234567891).fracOp(),
    Value.fromDouble(0.0000000001234567891),
  );
  expect(
    Value.fromDouble(0.000000001234567891).fracOp(),
    Value.fromDouble(0.000000001234567891),
  );
  expect(
    Value.fromDouble(0.00000001234567891).fracOp(),
    Value.fromDouble(0.00000001234567891),
  );
  expect(
    Value.fromDouble(0.0000001234567891).fracOp(),
    Value.fromDouble(0.0000001234567891),
  );
  expect(
    Value.fromDouble(0.000001234567891).fracOp(),
    Value.fromDouble(0.000001234567891),
  );
  expect(
    Value.fromDouble(0.00001234567891).fracOp(),
    Value.fromDouble(0.00001234567891),
  );
  expect(
    Value.fromDouble(0.0001234567891).fracOp(),
    Value.fromDouble(0.0001234567891),
  );
  expect(
    Value.fromDouble(0.001234567891).fracOp(),
    Value.fromDouble(0.001234567891),
  );
  expect(
    Value.fromDouble(0.01234567891).fracOp(),
    Value.fromDouble(0.01234567891),
  );
  expect(
    Value.fromDouble(0.1234567891).fracOp(),
    Value.fromDouble(0.1234567891),
  );
  expect(Value.fromDouble(1.234567891).fracOp(), Value.fromDouble(0.234567891));
  expect(Value.fromDouble(12.34567891).fracOp(), Value.fromDouble(0.34567891));
  expect(Value.fromDouble(123.4567891).fracOp(), Value.fromDouble(0.4567891));
  expect(Value.fromDouble(1234.567891).fracOp(), Value.fromDouble(0.567891));
  expect(Value.fromDouble(12345.67891).fracOp(), Value.fromDouble(0.67891));
  expect(Value.fromDouble(123456.7891).fracOp(), Value.fromDouble(0.7891));
  expect(Value.fromDouble(1234567.891).fracOp(), Value.fromDouble(0.891));
  expect(Value.fromDouble(12345678.91).fracOp(), Value.fromDouble(0.91));
  expect(Value.fromDouble(123456789.1).fracOp(), Value.fromDouble(0.1));
  expect(Value.fromDouble(1234567891).fracOp(), Value.fromDouble(0.0));
  for (int e = -99; e < 0; e++) {
    final d = double.parse('1.234567891e$e');
    expect(Value.fromDouble(d).fracOp(), Value.fromDouble(d));
  }
  for (int e = 9; e <= 99; e++) {
    final d = double.parse('1.234567891e$e');
    expect(Value.fromDouble(d).fracOp(), Value.zero);
  }
  expect(Value.zero.fracOp(), Value.zero);
  expect(Value.fMaxValue.fracOp(), Value.zero);
  expect(Value.fMinValue.fracOp(), Value.zero);
}

Future<void> valueIntOpTest() async {
  expect(Value.fromDouble(1.234567891).intOp(), Value.fromDouble(1));
  expect(Value.fromDouble(12.34567891).intOp(), Value.fromDouble(12));
  expect(Value.fromDouble(123.4567891).intOp(), Value.fromDouble(123));
  expect(Value.fromDouble(1234.567891).intOp(), Value.fromDouble(1234));
  expect(Value.fromDouble(12345.67891).intOp(), Value.fromDouble(12345));
  expect(Value.fromDouble(123456.7891).intOp(), Value.fromDouble(123456));
  expect(Value.fromDouble(1234567.891).intOp(), Value.fromDouble(1234567));
  expect(Value.fromDouble(12345678.91).intOp(), Value.fromDouble(12345678));
  expect(Value.fromDouble(123456789.1).intOp(), Value.fromDouble(123456789));
  expect(Value.fromDouble(1234567891).intOp(), Value.fromDouble(1234567891));
  expect(Value.fromDouble(12345678914).intOp(), Value.fromDouble(12345678910));
  for (int e = -99; e < 0; e++) {
    final d = double.parse('1.234567891e$e');
    expect(Value.fromDouble(d).intOp(), Value.zero);
  }
  for (int e = 9; e <= 99; e++) {
    final d = double.parse('1.234567891e$e');
    expect(Value.fromDouble(d).intOp(), Value.fromDouble(d));
  }
  expect(Value.zero.intOp(), Value.zero);
  expect(Value.fMaxValue.intOp(), Value.fMaxValue);
  expect(Value.fMinValue.intOp(), Value.fMinValue);
}

Future<void> decimalFPIntOpTest() async {
  for (int e = -99; e <= 99; e++) {
    for (String sign in ['', '-']) {
      var v = Value.fromDouble(double.parse('${sign}1.234567891e$e'));
      var vi = v.intOp();
      expect(DecimalFP12(v).intOp(), DecimalFP12(vi));
      expect(DecimalFP22(v).intOp(), DecimalFP22(vi));

      v = Value.fromDouble(double.parse('${sign}1.23456e$e'));
      vi = v.intOp();
      expect(DecimalFP6(v).intOp().toValue(), vi);
    }
  }
  expect(DecimalFP22.zero.intOp(), DecimalFP22.zero);
}

Future<void> trigTest() async {
  final List<List<double>> degValuesInUnitCircle = [
    [0.0, 0.0, 1.0, 0.0],
    [45.0, 0.7071067812, 0.7071067812, 1.0],
    [90.0, 1.0, 0.0, double.infinity],
    [135.0, 0.7071067812, -0.7071067812, -1.0],
    [180.0, 0.0, -1.0, 0.0],
    [225.0, -0.7071067812, -0.7071067812, 1.0],
    [270.0, -1.0, 0.0, double.infinity],
    [315.0, -0.7071067812, 0.7071067812, -1.0],
  ];
  // Expect, rounded to Value's precision
  void er(double v, double e, Value explain) {
    if (v == double.infinity || e == double.infinity) {
      expect(v, e, reason: '$explain');
    } else {
      expect(Value.fromDouble(v), Value.fromDouble(e), reason: '$explain');
    }
  }

  for (double mult in [1e7, 1e4, 100.0, 10.0, 7.0, 3.0, 2.0, 1.0, 0.0]) {
    for (final vals in degValuesInUnitCircle) {
      final deg = Value.fromDouble(vals[0] + 360 * mult);
      final nDeg = Value.fromDouble(vals[0] - 360 - 360 * mult);
      final grad = Value.fromDouble(vals[0] * 100 / 90 + 400 * mult);
      final nGrad = Value.fromDouble((vals[0] * 100 / 90) - 400 - 400 * mult);
      er(sin15(deg, TrigMode.deg), vals[1], deg);
      er(sin15(nDeg, TrigMode.deg), vals[1], nDeg);
      er(sin15(grad, TrigMode.grad), vals[1], grad);
      er(sin15(nGrad, TrigMode.grad), vals[1], nGrad);
      er(cos15(deg, TrigMode.deg), vals[2], deg);
      er(cos15(nDeg, TrigMode.deg), vals[2], nDeg);
      er(cos15(grad, TrigMode.grad), vals[2], grad);
      er(cos15(nGrad, TrigMode.grad), vals[2], nGrad);
      er(tan15(deg, TrigMode.deg), vals[3], deg);
      er(tan15(nDeg, TrigMode.deg), vals[3], nDeg);
      er(tan15(grad, TrigMode.grad), vals[3], grad);
      er(tan15(nGrad, TrigMode.grad), vals[3], nGrad);
    }
  }
  final List<List<double>> bigDegValues = [
    [360.0000001, 1.745329252e-9, 1.0, 1.745329252e-9],
    [720e7, 0.0, 1.0, 0.0],
    [720e8, 0.0, 1.0, 0.0],
    [720e9, 0.0, 1.0, 0.0],
    [7.2e99, 0.0, 1.0, 0.0],
    [-7.2e99, 0.0, 1.0, 0.0],
    [7.21e99, -0.9848077530, 0.1736481777, -5.671281820],
    [-7.21e99, 0.9848077530, 0.1736481777, 5.671281820],
  ];
  for (final vals in bigDegValues) {
    final deg = Value.fromDouble(vals[0]);
    er(sin15(deg, TrigMode.deg), vals[1], deg);
    er(cos15(deg, TrigMode.deg), vals[2], deg);
    er(tan15(deg, TrigMode.deg), vals[3], deg);
  }
  final List<List<double>> bigGradValues = [
    [8e99, 0.0, 1.0, 0.0],
    [-8e99, 0.0, 1.0, 0.0],
    [8.1e99, 0.0, 1.0, 0.0],
    [-8.1e99, 0.0, 1.0, 0.0],
  ];
  for (final vals in bigGradValues) {
    final grad = Value.fromDouble(vals[0]);
    er(sin15(grad, TrigMode.grad), vals[1], grad);
    er(cos15(grad, TrigMode.grad), vals[2], grad);
    er(tan15(grad, TrigMode.grad), vals[3], grad);
  }
}

Future<void> decimalAddSubtract() async {
  void testDoubles(double n1, double n2) {
    Value v1 = Value.fromDouble(n1);
    Value v2 = Value.fromDouble(n2);
    try {
      expect(v1.decimalAdd(v2), Value.fromDouble(n1 + n2));
    } on FloatOverflow {
      try {
        expect(v1.decimalAdd(v2), false);
      } on FloatOverflow {
        // ignore
      }
      try {
        expect(Value.fromDouble(v1.asDouble + v2.asDouble), false);
      } on FloatOverflow {
        // ignore
      }
    }
    try {
      expect(
        v1.decimalSubtract(v2),
        Value.fromDouble(n1 - n2),
        reason: 'for $n1, $n2',
      );
    } on FloatOverflow {
      try {
        expect(v1.decimalSubtract(v2), false);
      } on FloatOverflow {
        // ignore
      }
      try {
        expect(Value.fromDouble(v1.asDouble - v2.asDouble), false);
      } on FloatOverflow {
        // ignore
      }
    }
  }

  void testAddNoReverse(double n1, double n2, double expected) {
    check(Value Function() f1, Value Function() f2) {
      try {
        expect(f1(), f2());
      } on FloatOverflow {
        try {
          expect(f1(), false);
        } on FloatOverflow {
          // test passes
        }
        try {
          expect(f2(), false);
        } on FloatOverflow {
          // test passes
        }
      }
    }

    try {
      check(
        () => Value.fromDouble(n1).decimalAdd(Value.fromDouble(n2)),
        () => Value.fromDouble(expected),
      );
      check(
        () => Value.fromDouble(n1).decimalSubtract(Value.fromDouble(-n2)),
        () => Value.fromDouble(expected),
      );
      check(
        () => Value.fromDouble(-n1).decimalAdd(Value.fromDouble(-n2)),
        () => Value.fromDouble(-expected),
      );
      check(
        () => Value.fromDouble(-n1).decimalSubtract(Value.fromDouble(n2)),
        () => Value.fromDouble(-expected),
      );
    } catch (e) {
      print("Failed for $n1 $n2");
      rethrow;
    }
  }

  void testAdd(double n1, double n2, double expected) {
    testAddNoReverse(n1, n2, expected);
    testAddNoReverse(n2, n1, expected);
  }

  void testSubtract(double n1, double n2, double expected) {
    testAdd(n1, -n2, expected);
  }

  void testComparison(double n1, double n2) {
    {
      final f1 = DecimalFP12(Value.fromDouble(n1));
      final f2 = DecimalFP12(Value.fromDouble(n2));
      expect(f1 > f2, n1 > n2);
      expect(f1 >= f2, n1 >= n2);
      expect(f1 < f2, n1 < n2);
      expect(f1 <= f2, n1 <= n2);
      expect(f1 == f2, n1 == n2);
    }
    {
      final f1 = DecimalFP22(Value.fromDouble(n1));
      final f2 = DecimalFP22(Value.fromDouble(n2));
      expect(f1 > f2, n1 > n2);
      expect(f1 >= f2, n1 >= n2);
      expect(f1 < f2, n1 < n2);
      expect(f1 <= f2, n1 <= n2);
      expect(f1 == f2, n1 == n2);
    }
    // Also check DecimalFP.asDouble
    final v = Value.fromDouble(n1);
    expect(Value.fromDouble(DecimalFP22(v).asDouble), v);
    expect(Value.fromDouble(DecimalFP12(v).asDouble), v);
  }

  testSubtract(100, 58, 42);
  testSubtract(100, 99, 1);
  testAdd(0, 0, 0);
  for (int i in [-1, 0, 1, 101, -3000, 65536]) {
    expect(DecimalFP12(Value.fromDouble(i.toDouble())).asInt, i);
  }

  // Do additions and subtractions where athe difference in magnitude is
  // great enough that we get the same answer in decimal and double
  {
    final numbers = {
      9.123456789e99,
      1.567891234e42,
      1.567891235e41,
      0.0,
      1.567891235e-41,
      1.567891234e-42,
      9.123456789e-99,
    };
    for (final n1 in numbers) {
      for (final n2 in numbers) {
        testDoubles(n1, n2);
        testComparison(n1, n2);
        testComparison(n1, -n2);
        testComparison(-n1, n2);
        testComparison(-n1, -n2);
      }
    }
  }

  // Do a bunch of additions/subtractions that are represented exactly in
  // IEEE double-precision (53 bits of mantissa; 2^^53 is a 15 digit number
  for (int n1 = 1; n1 <= 15; n1++) {
    for (int n2 = 1; n2 <= 15; n2++) {
      const patterns = {
        '000000000000000',
        '111111111100000',
        '999999999900000',
        '123456789100000',
        '567891234700000',
        '987654321900000',
        '891521596500000',
        '281902729800000',
      };
      for (final d1 in patterns) {
        for (final d2 in patterns) {
          testDoubles(
            double.parse(d1.substring(0, n1)),
            double.parse(d2.substring(0, n2)),
          );
        }
      }
    }
  }

  // While we're at it, make sure moving the decimal exponent around
  // doesn't change anything...
  for (double f in [1, 1e-50, 1e+60]) {
    // Test some edge cases that we know don't work with binary floating point,
    // and others mentioned in issue #78
    testSubtract(f * 100, f * 99.999999, f * 1e-6);
    testAdd(f * 1, f * 5e-10, f * 1.000000001);
    testSubtract(f * 1, f * 5e-10, f * 0.9999999995);
    testSubtract(f * 1, f * 6e-11, f * 0.9999999999);
    testSubtract(f * 1, f * 5e-11, f * 1);
    testSubtract(f * 1, f * 5.000000001e-11, f * 0.9999999999);
    testAdd(f * 2, f * 5e-10, f * 2.000000001);
    testSubtract(f * 2, f * 5e-10, f * 2);
    testAdd(f * 3, f * 5e-10, f * 3.000000001);
    testSubtract(f * 3, f * 5e-10, f * 3);
  }

  // Test overflow
  testAdd(9.999999999e99, 0.000000001e99, double.infinity);
  testAdd(9.999999999e99, 0.0000000005e99, double.infinity);
  testAdd(9.999999999e99, 0.0000000004999999999e99, 9.999999999e99);

  // Test underflow
  testSubtract(2e-99, 1.000000000e-99, 1e-99);
  testSubtract(2e-99, 1.000000001e-99, 0); // It's 9.9999999990e-100

  // Test a bunch of random numbers
  final random = Random();
  // No real point in setting a seed, since Random() can change across
  // platforms and versions of the library.
  double getRandom(final int exp) {
    return 2 * (random.nextDouble() - 0.5) * pow(10.0, exp);
  }

  const fmt = SciFloatFormatter(9);
  for (int i = 0; i < 1000; i++) {
    if (i % 1000 == 0 && i > 0) {
      print('$i');
    }
    final int exp = random.nextInt(201) - 100;
    final Value v1;
    final Value v2;
    try {
      v1 = Value.fromDouble(getRandom(exp));
      v2 = Value.fromDouble(getRandom(exp + random.nextInt(25) - 12));
    } on FloatOverflow {
      continue;
    }
    final d1 = Decimal.fromJson(fmt.format(v1, false));
    final d2 = Decimal.fromJson(fmt.format(v2, false));
    final Value plus;
    final Value minus;
    try {
      plus = Value.fromDouble(double.parse((d1 + d2).toStringAsExponential(9)));
      minus = Value.fromDouble(
        double.parse((d1 - d2).toStringAsExponential(9)),
      );
    } on FloatOverflow {
      continue;
    }
    testAdd(v1.asDouble, v2.asDouble, plus.asDouble);
    testSubtract(v1.asDouble, v2.asDouble, minus.asDouble);
  }
}

Future<void> decimalMultiplyAndDivide() async {
  void checkResult(
    Value result,
    double expected,
    bool lenient,
    String Function() msg,
  ) {
    final e = Value.fromDouble(expected);

    if (result != e &&
        (!lenient ||
            result != Value.fromDouble(expected * 1.0000000000001) &&
                result != Value.fromDouble(expected / 1.0000000000001))) {
      expect(result, e, reason: msg());
    }
  }

  void testDoubles(double n1, double n2, {bool lenient = false}) {
    Value v1 = Value.fromDouble(n1);
    Value v2 = Value.fromDouble(n2);
    try {
      checkResult(
        v1.decimalMultiply(v2),
        v1.asDouble * v2.asDouble,
        lenient,
        () => ' for $v1 * $v2',
      );
    } on FloatOverflow {
      try {
        expect(v1.decimalMultiply(v2), false);
      } on FloatOverflow {
        // ignore
      }
      try {
        expect(Value.fromDouble(v1.asDouble * v2.asDouble), false);
      } on FloatOverflow {
        // ignore
      }
    }
    if (v2 != Value.zero) {
      lenient =
          lenient ||
          (n1 == 5 &&
              (n2 == 9999999999e0 ||
                  n2 == 9999999999e1 ||
                  n2 == 9999999999e2 ||
                  n2 == 9999999999e3 ||
                  n2 == 9999999999e4 ||
                  n2 == 9999999999e5));
      lenient = lenient || (n1 == 9876543 && n2 == 98765432);
      try {
        checkResult(
          v1.decimalDivideBy(v2),
          v1.asDouble / v2.asDouble,
          lenient,
          () => ' for $v1 / $v2',
        );
      } on FloatOverflow {
        try {
          expect(v1.decimalDivideBy(v2), false);
        } on FloatOverflow {
          // ignore
        }
        try {
          expect(Value.fromDouble(v1.asDouble / v2.asDouble), false);
        } on FloatOverflow {
          // ignore
        }
      }
    }
  }

  expect(
    Value.fromDouble(
      -6.087e+14,
    ).decimalMultiply(Value.fromDouble(0.000013838095)),
    Value.fromDouble(-8423248427.0),
  );
  // The actual answer is -8423248426.5, and IEEE FP rounds down, wheras
  // the 15C rounds up.
  try {
    expect(Value.oneF.decimalDivideBy(Value.zero), false);
  } on CalculatorError catch (e) {
    expect(e.num15, 0);
    expect(e.num16, 0);
  }
  testDoubles(1, 1);
  testDoubles(1, -1);
  testDoubles(-1, -1);
  testDoubles(-1, 1);

  // Try some numbers at the extremes
  {
    final numbers = {
      9.123456789e99,
      1.567891234e42,
      0.0,
      1.567891234e-42,
      9.123456789e-99,
    };
    for (final n1 in numbers) {
      for (final n2 in numbers) {
        testDoubles(n1, n2);
      }
    }
  }

  // Do a bunch of operations that are represented exactly in
  // IEEE double-precision (53 bits of mantissa; 2^^53 is a 15 digit number
  for (int n1 = 1; n1 <= 15; n1++) {
    for (int n2 = 1; n2 <= 15; n2++) {
      const patterns = {
        '000000000000000',
        '111111111100000',
        '999999999900000',
        '123456789100000',
        '567891234700000',
        '987654321900000',
        '891521596500000',
        '281902729800000',
      };
      for (final d1 in patterns) {
        for (final d2 in patterns) {
          testDoubles(
            double.parse(d1.substring(0, n1)),
            double.parse(d2.substring(0, n2)),
          );
        }
      }
    }
  }

  // Test a bunch of random numbers...
  final random = Random();
  // No real point in setting a seed, since Random() can change across
  // platforms and versions of the library.
  double getRandom(final int exp) {
    return 2 * (random.nextDouble() - 0.5) * pow(10.0, exp);
  }

  for (int i = 0; i < 1000; i++) {
    final v1 = getRandom(random.nextInt(201) - 100);
    final v2 = getRandom(random.nextInt(201) - 100);
    testDoubles(v1, v2, lenient: true);
    if (i % 100000 == 0 && i > 0) {
      print('$i');
    }
  }
}

Future<void> decimalComplex() async {
  ComplexValue c(double re, double im) =>
      ComplexValue(Value.fromDouble(re), Value.fromDouble(im));

  expect(
    c(
      9961222200,
      4314481542,
    ).decimalMultiply(c(9157785135, 3984172017), (v) => v()),
    c(7.403309596e19, 7.919831767e19),
  );
}

Future<void> lastX15C() async {
  final c = TestCalculator(for15C: true);
  final controller = c.controller;
  final model = c.model;
  void play(List<Operation> script) {
    for (final b in script) {
      controller.buttonDown(b);
      controller.buttonUp();
    }
  }

  play([
    Operations.n1,
    Operations.enter,
    Operations.n2,
    Operations15.sigmaPlus,
  ]);
  play([
    Operations.n3,
    Operations.enter,
    Operations.n4,
    Operations15.sigmaPlus,
  ]);

  for (final complex in [false, true]) {
    c.model.isComplexMode = complex;

    /// Single argument operations:
    for (final op in [
      Operations15.sqrtOp15,
      Operations15.xSquared,
      Operations15.eX15,
      Operations15.lnOp,
      Operations15.tenX15,
      Operations15.logOp,
      Operations15.percent,
      Operations15.reciprocal15,
      Operations15.deltaPercent,
      Operations.abs,
      Operations15.sin,
      Operations15.sinh,
      Operations15.sinInverse,
      Operations15.sinhInverse,
      Operations15.cos,
      Operations15.cosh,
      Operations15.cosInverse,
      Operations15.coshInverse,
      Operations15.tan,
      Operations15.tanh,
      Operations15.tanInverse,
      Operations15.tanhInverse,
      Operations15.toR,
      Operations15.toP,
      Operations15.toHMS,
      Operations15.toH,
      Operations15.toRad,
      Operations15.toDeg,
      Operations15.fracOp,
      Operations15.intOp,
      Operations15.xFactorial,
      Operations15.yHatR,
    ]) {
      play([Operations.n9, Operations.enter, Operations15.plus]);
      play([Operations.dot, Operations.n1, Operations.enter]);
      play([Operations.dot, Operations.n2, Operations.enter]);
      play([Operations.dot, Operations.n3, Operations.enter]);
      play([Operations.dot, Operations.n4]);
      expect(
        model.lastX,
        Value.fromDouble(9),
        reason: 'lastX for $op $complex',
      );
      play([op]);
      if (op == Operations15.yHatR) {
        expect(model.t, Value.fromDouble(.2), reason: 't for $op $complex');
        expect(model.z, Value.fromDouble(.3), reason: 'z for $op $complex');
      } else {
        expect(model.t, Value.fromDouble(.1), reason: 't for $op $complex');
        expect(model.z, Value.fromDouble(.2), reason: 'z for $op $complex');
        if (!{Operations15.toR, Operations15.toP}.contains(op)) {
          expect(model.y, Value.fromDouble(.3), reason: 'y for $op $complex');
        }
      }
      expect(
        model.lastX,
        Value.fromDouble(.4),
        reason: 'lastX for $op $complex',
      );
    }

    /// Two argument operations:
    for (final op in [
      Operations15.yX15,
      Operations15.div,
      Operations15.mult,
      Operations15.minus,
      Operations15.plus,
      Operations15.pYX,
      Operations15.cYX,
    ]) {
      play([Operations.n9, Operations.enter, Operations15.plus]);
      play([Operations.n4, Operations.enter]);
      play([Operations.n3, Operations.enter]);
      play([Operations.n2, Operations.enter]);
      play([Operations.n1]);
      expect(model.lastX, Value.fromDouble(9));
      play([op]);
      expect(model.t, Value.fromDouble(4));
      expect(model.z, Value.fromDouble(4), reason: 'z for $op $complex');
      expect(model.y, Value.fromDouble(3));
      expect(
        model.lastX,
        Value.fromDouble(1),
        reason: 'lastX for $op $complex',
      );
    }

    // Stuff that doesn't touch LastX:
    for (final op in [
      Operations15.xBar,
      Operations15.stdDeviation,
      Operations15.linearRegression,
    ]) {
      play([Operations.n9, Operations.enter, Operations15.plus]);
      play([Operations.n4, Operations.enter]);
      play([Operations.n3, Operations.enter]);
      play([Operations.n2, Operations.enter]);
      play([Operations.n1]);
      expect(model.lastX, Value.fromDouble(9));
      play([op]);
      expect(model.t, Value.fromDouble(2));
      expect(model.z, Value.fromDouble(1), reason: 'z for $op $complex');
      expect(
        model.lastX,
        Value.fromDouble(9),
        reason: 'lastX for $op $complex',
      );
    }

    // CHS and the stack (not really lastX related)
    play([Operations.n1, Operations.enter, Operations.n2, Operations.xy]);
    play([Operations.enter, Operations.chs]);
    expect(model.xF, -1);
    expect(model.yF, 1);
    expect(model.z.asDouble, 2);
    play([Operations.n4]);
    expect(model.xF, 4);
    expect(model.yF, -1);
    expect(model.z.asDouble, 1);
    expect(model.t.asDouble, 2);
    play([Operations.clx]);
  }
}

Value _toValue(double v) => Value.fromDouble(v);
