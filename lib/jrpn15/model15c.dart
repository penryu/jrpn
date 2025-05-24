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

library;

import 'dart:math' as dart;

import 'package:jrpn/m/model.dart';

import 'matrix.dart';

class Model15<OT extends ProgramOperation> extends Model<OT> {
  late final List<Matrix> matrices = [
    Matrix('a'),
    Matrix('b'),
    Matrix('c'),
    Matrix('d'),
    Matrix('e'),
  ];

  int _resultMatrix = 0; // Index into matrices
  int get resultMatrix => _resultMatrix;
  set resultMatrix(int v) {
    _resultMatrix = v;
    needsSave = true;
  }

  final ProgramInstruction<OT> Function(OT, ArgDone) _newProgramInstructionF;
  final List<List<MKey<OT>?>> Function() _getLogicalKeys;

  @override
  bool userMode = false;

  //
  // A bit hacky:  Some operations, like matrix operations, don't run until
  // the button is released, and they can be cancelled by holding the button
  // down.  This doesn't fit in with the input design terribly well, so I was
  // more or less forced to squirrel away an indication that a function has
  // been deferred here, in the model.
  //
  // Returns true if stack lift needs to be enabled.
  //
  bool Function()? deferToButtonUp;
  @override
  bool get hasDeferToButtonUp => deferToButtonUp != null;

  Model15(this._getLogicalKeys, this._newProgramInstructionF)
    : super(DisplayMode.fix(4, false), 56, 10);

  // It's a little hacky, but we need to defer initialization of
  // logicalKeys until after the controller initializes
  // Operations.numberOfFlags.  This seems the
  // least bad option.
  @override
  late final List<List<MKey<OT>?>> logicalKeys = _getLogicalKeys();

  @override
  ProgramInstruction<OT> newProgramInstruction(OT operation, ArgDone arg) =>
      _newProgramInstructionF(operation, arg);

  final rand = RandomGenerator();

  @override
  void reset() {
    userMode = false;
    displayMode = DisplayMode.fix(4, false);
    super.reset();
    rand.reset();
    trigMode = TrigMode.deg;
    _resultMatrix = 0;
    for (final mat in matrices) {
      mat.resize(this, 0, 0);
    }
    memory.program.suspendedProgram?.abort();
    memory.program.suspendedProgram = null;
    assert(memory.program.runner == null);
    memory.program.runner?.abort(); // Should be null, but be conservative
    memory.program.runner = null;
    memory.numRegisters = 20;
  }

  @override
  late final Memory15<OT> memory = Memory15<OT>(this, memoryNybbles: 66 * 14);
  // cf. 16C manual, page 214.  The index register doesn't count against
  // our storage, so that's space for 66 total registers, of 14 nybbles each.

  @override
  bool get displayLeadingZeros => false;

  @override
  bool get cFlag => false;

  @override
  set cFlag(bool v) {
    assert(false);
  }

  @override
  bool get gFlag => false;

  @override
  set gFlag(bool v) {
    assert(false);
  }

  @override
  String get modelName => '15C';

  @override
  bool get is15C => true;

  @override
  int get returnStackSize => 7;

  @override
  bool get floatOverflow => getFlag(9);

  @override
  set floatOverflow(bool v) {
    if (v) {
      setFlag(9, v);
    }
  }

  @override
  void setFlag(int i, bool v) {
    if (i == 8) {
      isComplexMode = v;
    } else {
      super.setFlag(i, v);
    }
  }

  @override
  set isComplexMode(bool v) {
    if (v && !isComplexMode) {
      memory.policy.checkAvailable(5);
      // Might throw CalculatorError
    }
    if (v != isComplexMode) {
      setupComplex(
        v ? List<Value>.filled(4, Value.zero, growable: false) : null,
      );
    }
    super.setFlag(8, v);
  }

  @override
  bool get errorBlink => floatOverflow;
  @override
  void resetErrorBlink() => setFlag(9, false);

  @override
  void chsX() {
    final mi = x.asMatrix;
    if (mi == null) {
      super.chsX();
    } else {
      matrices[mi].chsElements();
      needsSave = true;
    }
  }

  @override
  String formatValue(Value v) {
    final int? mx = v.asMatrix;
    if (mx == null) {
      return super.formatValue(v);
    } else {
      return matrices[mx].lcdString;
    }
  }

  @override
  Map<String, Object> toJson() {
    final r = super.toJson();
    r['numRegisters'] = memory.numRegisters;
    r['resultMatrix'] = resultMatrix;
    r['matrices'] = List.generate(
      matrices.length,
      (i) => matrices[i].toJson(),
      growable: false,
    );
    r['lastRandom'] = rand.lastValue;
    return r;
  }

  @override
  void decodeJson(Map<String, dynamic> json, {required bool needsSave}) {
    super.decodeJson(json, needsSave: needsSave);
    memory.numRegisters = json['numRegisters'] as int;
    resultMatrix = json['resultMatrix'] as int;
    isComplexMode = getFlag(8);
    final ms = json['matrices'] as List;
    for (int i = 0; i < matrices.length; i++) {
      matrices[i].decodeJson(ms[i] as Map<String, dynamic>);
    }
    final Object? lastRandom = json['lastRandom'];
    if (lastRandom is double) {
      rand.setNoReseed(lastRandom);
    }
  }

  @override
  int get registerNumberBase => 10;

  @override
  LcdContents selfTestContents() => LcdContents(
    hideComplement: false,
    longNumbers: LongNumbersSetting.window,
    mainText: '-8,8,8,8,8,8,8,8,8,8,',
    cFlag: false,
    complexFlag: true,
    euroComma: false,
    rightJustify: false,
    bits: 64,
    sign: SignMode.float,
    wordSize: null,
    gFlag: true,
    prgmFlag: true,
    shift: ShiftKey.g,
    trigMode: TrigMode.grad,
    userMode: true,
    extraShift: ShiftKey.f,
    lcdDigits: 11,
  );

  @override
  addStuffToSnapshot(StringBuffer buf) {
    for (final m in matrices) {
      if (m.length > 0) {
        buf.writeln();
        buf.write(m.toString());
      }
    }
    buf.writeln();
  }
}

///
/// Implementation of the RAN # key, and sto/rcl
///
/// Note that the generator isn't re-seeded with the last value every time
/// a number is requested.  That means that the sequence:
///    STO RAN #
///    RAN #
///    STO RAN #
///    RAN #
/// will yield a different result than:
///    STO RAN #
///    RAN #
///    RAN #
///  whereas the two will generate identical results on a real 15C.
///
/// Re-seeding each time would presumably generate worse results that
/// Dart's built-in function, and I'm a little concerned it might even
/// lead to pathological cases, like small cycles in certain cases.
///
class RandomGenerator {
  var _generator = dart.Random();
  double _lastValue = 0;

  RandomGenerator() {
    nextValue;
  }

  void setSeed(double seed) {
    seed = seed.abs();
    if (seed > 1) {
      final exp = log10(seed).floorToDouble() + 1;
      seed /= dart.pow(10.0, exp);
    }
    _lastValue = seed;
    int s = ((seed - 0.5) * dart.pow(2.0, 52.0)).round();
    _generator = dart.Random(s);
    // Stupid JavaScript ints are limited to +- 2^52. To be conservative, I
    // go for 2^51
  }

  ///
  /// Set from JSON on startup
  ///
  void setNoReseed(double val) => _lastValue = val;

  double get lastValue => _lastValue;

  double get nextValue => _lastValue = _generator.nextDouble();

  void reset() {
    _generator = dart.Random();
    nextValue;
  }
}

class MemoryPolicy15 extends MemoryPolicy {
  final Memory15 _memory;

  MemoryPolicy15(this._memory);

  @override
  void checkRegisterAccess(int i) {
    if (i < 0 || i >= _memory.numRegisters) {
      throw CalculatorError(3);
    }
  }

  @override
  String showMemory() {
    String dd = (_memory.numRegisters - 1).toString().padLeft(2);
    String uu = (_memory.availableRegisters).toString().padLeft(2);
    String pp = (_memory.program.programBytes ~/ 7).toString().padLeft(2);
    String b = (_memory.program.bytesToNextAllocation).toString();
    return '$dd $uu $pp-$b';
  }

  /// Throws CalculatorError(10) if the needed register memory isn't available
  void checkAvailable(int registers) {
    if (registers > _memory.availableRegisters) {
      throw CalculatorError(10);
    }
  }

  @override
  void checkExtendProgramMemory() {
    if (_memory.availableRegisters < 1) {
      throw CalculatorError(4);
    }
  }

  @override
  int get maxProgramBytes {
    int regs = _memory.availableRegistersWithProgram(null);
    regs += _memory.program.programBytes ~/ 7;
    return regs * 7;
  }
}

/// HP 15C's memory.  Like in the HP 16C, registers and programs are
/// stored by the nybble.  However, matrices, the imaginary stack, and
/// storage for solve/integrate just deduct from the memory otherwise
/// available, but don't actually use it.
///
/// On the 16C it made more sense to store the registers by the nybble,
/// since register size changes with the word size, rounded up to the nearest
/// nybble.  The 16C's memory contents aren't changed when the word size
/// changes, and while the mapping of the memory interpretation isn't specified,
/// the fact that a temporary change in word size doesn't lose information in
/// the registers is.
///
/// On the 15C, there's nothing like this behavior; registers are always
/// 14 nybbles.  We keep the user registers in the common storage, since
/// we inherit that from our superclass, but the other uses of the
/// register pool storage use regular dart structures for their underlying
/// storage.
class Memory15<OT extends ProgramOperation> extends Memory<OT> {
  @override
  final Model15<OT> model;

  @override
  late final MemoryPolicy15 policy = MemoryPolicy15(this);

  ///
  /// Number of registers, not including rI
  ///
  int _numRegisters = 20;

  Memory15(this.model, {required super.memoryNybbles});

  @override
  void initializeSystem(OperationMap<OT> layout, OT lbl, OT rtn) => program =
      ProgramMemory15<OT>(this, layout, model.returnStackSize, lbl, rtn);

  int get numRegisters => _numRegisters;
  set numRegisters(int v) {
    policy.checkAvailable(v - _numRegisters);
    for (int i = v; i < _numRegisters; i++) {
      registers[i] = Value.zero;
    }
    _numRegisters = v;
    model.needsSave = true;
  }

  /// Number of uncommitted registers available in the pool.
  int get availableRegisters =>
      availableRegistersWithProgram(program.runner ?? program.suspendedProgram);

  @override
  String? checkMemorySize() {
    final a = availableRegisters;
    if (a < 0) {
      return 'New memory size too small.\n'
          'Available registers would be $a.';
    }
    return null;
  }

  int availableRegistersWithProgram(MProgramRunner? runner) {
    int result = totalNybbles ~/ 14;
    result -= numRegisters;
    result -= program.programBytes ~/ 7;
    if (model.isComplexMode) {
      result -= 5;
    }
    for (final m in model.matrices) {
      result -= m.length;
    }
    result -= runner?.registersRequired ?? 0;
    return result;
  }
}

class ProgramMemory15<OT extends ProgramOperation> extends ProgramMemory<OT> {
  final List<int> _lblOpcodes;

  ProgramMemory15(
    super.memory,
    super.layout,
    super.returnStackSize,
    OT lbl,
    OT super.rtn,
  ) : _lblOpcodes = _makeLblOpcodes(lbl);

  static List<int> _makeLblOpcodes(ProgramOperation lbl) {
    /// Because LBL . n is two-byte, we have to chase down the opcodes
    /// assigned to the LBL instruction.
    final List<int?> table = List.filled(25, null);
    void visit(final Arg arg) {
      if (arg is KeyArg) {
        final ad = arg.child as ArgDone;
        final nv = arg.key.numericValue!;
        table[nv] = ad.opcode;
      } else if (arg is ArgAlternates) {
        for (final c in arg.children) {
          visit(c);
        }
      } else if (arg is DigitArg) {
        arg.visitChildren((nv, ad) => table[nv] = ad.opcode);
      } else {
        assert(false);
      }
    }

    visit(lbl.arg);
    return List.generate(table.length, (i) => table[i]!);
  }

  @override
  void goto(int label) {
    if (label < 0) {
      currentLine = -label;
    } else if (label >= _lblOpcodes.length) {
      throw CalculatorError(4);
    } else {
      gotoOpCode(_lblOpcodes[label]);
    }
  }
}

double log10(double val) => dart.log(val) * dart.log10e;
