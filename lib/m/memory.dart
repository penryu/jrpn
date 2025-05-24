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
part of 'model.dart';

/// Controls the policy around memory allocation
abstract class MemoryPolicy {
  /// Throws a CalculatorError(3) if the given register does not exist.
  void checkRegisterAccess(int i);

  /// Give the string displayed by the MEM key
  String showMemory();

  /// Throws CalculatorError(4) if there's no room to add seven bytes
  /// of program memory.
  void checkExtendProgramMemory();

  int get maxProgramBytes;
}

/// The calculator's internal memory that holds registers and
/// programs.
///
/// Programs are stored starting at location 0.  Registers are stored
/// starting
abstract class Memory<OT extends ProgramOperation> {
  @protected
  ByteData _storage;
  @protected
  ByteData get storage => _storage;
  //  We hold one nybble (4 bits) in each byte of _storage.  The program
  // is also stored here, and we zero out that part of storage when
  // program lines are added/removed, to simulate the behavior of shared
  // storage.
  //
  // The program is stored starting at the first byte, and register 0 is
  // stored at the end of _storage, with higher numbered registers at lower
  // addresses.
  final int minimumMemoryNybbles;

  late final ProgramMemory<OT> program;
  late final registers = Registers(this);

  Model<OT> get model;

  MemoryPolicy get policy;

  Memory({required int memoryNybbles})
      : _storage = ByteData(memoryNybbles),
        minimumMemoryNybbles = memoryNybbles;

  ///
  /// Total number of nybbles of storage, not including rI.  The index
  /// register is 68 bits (17 nybbles) on the 16C, and 14 nybbles on the 15C.
  ///
  int get totalNybbles => storage.lengthInBytes;

  /// Amount of memory taken up by program
  int get programNybbles => program.programBytes * 2;

  /// Called by our controller, which necessarily happens after the Model
  /// exists.
  void initializeSystem(OperationMap<OT> layout, OT lbl, OT rtn);
  // We rely on our Controller to give us an OperationMap with the
  // layout information that tells us the row/column positions of the various
  // operations.  Those positions are how the 16C displays program
  // instructions, and it's also how we externalize them in our JSON
  // state file.
  //
  // We don't need to retain the layout, but we do need to ensure that
  // one is created.  The OperationMap constructor has the side effect
  // of initializing late final fields that we depend on.  Admittedly, this
  // is a little tricky - making initialization happen while keeping modules
  // decoupled sometimes is.

  ///
  /// Change the memory size.  Returns a descriptive error message string
  /// on error.
  ///
  String? changeMemorySize(int newSize) {
    newSize = min(
        max(minimumMemoryNybbles, newSize), minimumMemoryNybbles + 1024 * 1024);
    // Max of 1 mega-nybble extra memory.  This is big enough to be effectively
    // infinite, and small enough to be trivially small on modern hardware.

    if (newSize == _storage.lengthInBytes) {
      return null;
    }
    final oldStorage = _storage;
    _storage = ByteData(newSize);
    final error = checkMemorySize();
    if (error != null) {
      _storage = oldStorage;
      return error;
    }
    for (int i = 0; i < programNybbles; i++) {
      _storage.setUint8(i, oldStorage.getUint8(i));
    }
    final newLength = _storage.lengthInBytes;
    final oldLength = oldStorage.lengthInBytes;
    final other = min(newLength, oldLength) - programNybbles;
    for (int i = 1; i <= other; i++) {
      _storage.setUint8(newLength - i, oldStorage.getUint8(oldLength - i));
    }
    model.needsSave = true;
    return null;
  }

  @protected
  String? checkMemorySize();

  void reset() {
    for (int i = 0; i < totalNybbles; i++) {
      storage.setUint8(i, 0);
    }
    program.reset(zeroMemory: false);
    registers.resetI();
  }

  Map<String, Object> toJson() {
    final st = StringBuffer();
    for (int i = 0; i < totalNybbles; i++) {
      st.write(storage.getUint8(i).toRadixString(16));
    }
    final r = <String, Object>{
      'storage': st.toString(),
      'program': program.toJson(),
      'I': registers._indexValue.toJson()
    };
    return r;
  }

  void decodeJson(Map<String, dynamic> json) {
    final sto = json['storage'] as String;
    _storage = ByteData(sto.length);
    for (int i = 0; i < totalNybbles; i++) {
      storage.setUint8(i, int.parse(sto.substring(i, i + 1), radix: 16));
    }
    // Must come after storage.  cf. ProgramMemory.decodeJson().
    program.decodeJson(json['program'] as Map<String, dynamic>);
    registers._indexValue =
        Value.fromJson(json['I'] as String, maxInternal: Registers._maxI);
  }
}

/// A helper for the index register, which is always stored as a 68 bit
/// quantity, regardless of the calculator mode.
class NumStatus68 implements NumStatus {
  final Model _model; // For the sign mode

  NumStatus68(this._model);

  @override
  bool cFlag = false;

  @override
  bool gFlag = false;

  @override
  int get wordSize => 68;

  @override
  final BigInt wordMask = (BigInt.one << 68) - BigInt.one;

  @override
  final BigInt signMask = (BigInt.one << 67);

  @override
  BigInt get maxInt => _model._integerSignMode.maxValue(this);

  @override
  BigInt get minInt => _model._integerSignMode.minValue(this);

  @override
  bool get isFloatMode => _model.isFloatMode;

  @override
  IntegerSignMode get integerSignMode => _model.integerSignMode;

  Value signExtendFrom(Value other) {
    if (!_model.signMode.doesSignExtension) {
      return other;
    }
    BigInt internal = other.internal;
    if (BigInt.zero == internal & _model.signMask) {
      return other;
    }
    BigInt bitToSet = _model.signMask << 1;
    while (bitToSet <= signMask) {
      internal = internal | bitToSet;
      bitToSet <<= 1;
    }
    return Value.fromInternal(internal);
  }
}

///
/// A representation of the available memory as registers.  "Available memory"
/// is what's left over of the 406 nybble data store after the program's
/// storage is deducted.  Registers are stored starting from the top of memory
/// (register 0 has the highest address, working down).
///
/// On the 15C, matrices and some other things aren't stored in [Memory], but
/// the space they take is deducted from what's available.  See
/// `Model15.availableRegisters`.
///
class Registers {
  final Memory _memory;
  // A helper for dealing with 68 bit values, like I
  final NumStatus68 helper68;

  /// Value of the index register, I, always stored in 68 bits.
  Value _indexValue = Value.zero;

  Registers(this._memory) : helper68 = NumStatus68(_memory.model);

  static final BigInt _maxI = BigInt.parse('fffffffffffffffff', radix: 16);
  // 16^17-1, that is, 2^68-1

  Model get _model => _memory.model;

  int get nybblesPerRegister => (_model.wordSize + 3) ~/ 4;

  static final BigInt _oneKmask = BigInt.from(0x3ff);

  Value operator [](int i) {
    _memory.policy.checkRegisterAccess(i);
    final int npr = nybblesPerRegister;
    int addr = _memory.totalNybbles - 1 - (i + 1) * npr;
    // Address of most significant nybble - 1
    BigInt value = BigInt.zero;
    for (int i = 0; i < npr; i++) {
      value = (value << 4) | BigInt.from(_memory.storage.getUint8(++addr));
    }
    final result = Value.fromInternal(value);
    return result;
  }

  static final BigInt _low4 = BigInt.from(0xf);

  void operator []=(int i, Value v) {
    _memory.policy.checkRegisterAccess(i);
    final int npr = nybblesPerRegister;
    BigInt value = v.internal;
    int addr = _memory.totalNybbles - 1 - i * npr;
    // Address of least significant nybble
    for (int i = 0; i < npr; i++) {
      _memory.storage.setUint8(addr--, (value & _low4).toInt());
      value >>= 4;
    }
    _model.needsSave = true;
  }

  Value get index => Value.fromInternal(_indexValue.internal & _model.wordMask);

  set index(Value v) {
    _indexValue = helper68.signExtendFrom(v);
    _model.needsSave = true;
  }

  Value get indirectIndex => this[_regIasIndex];
  set indirectIndex(Value v) => this[_regIasIndex] = v;

  /// Calculate the value of the I register for use as an index.  If that
  /// value is too big to be an index, then any int that is too big will do,
  /// since we'll just end up generating a CalculatorError anyway.
  int get _regIasIndex {
    if (_model.isFloatMode) {
      Value masked = Value.fromInternal(_indexValue.internal & _model.wordMask);
      double d = masked.asDouble.abs();
      if (d > 1000) {
        return 1000; // close enough to infinity
      } else {
        return d.floor();
      }
    } else {
      BigInt bi = _model._integerSignMode.toBigInt(_indexValue, helper68).abs();
      if (bi > _oneKmask) {
        return 1024; // close enough to infinity
      } else {
        return bi.toInt().abs();
      }
    }
  }

  void resetI() {
    _indexValue = Value.zero;
    _model.needsSave = true;
  }

  void clear() {
    final maxMem = _memory.totalNybbles;
    for (int addr = _memory.programNybbles; addr < maxMem; addr++) {
      _memory.storage.setUint8(addr, 0);
    }
    resetI();
  }

  bool isZeroI(Value v) => _model.signMode.isZero(helper68, v);

  /// Gives value after increment
  Value incrementI(int by) {
    return _indexValue = _model.signMode.increment(helper68, _indexValue, by);
  }
}

///
/// A representation of the calculator's 406 nybble data store as a list
/// of program instructions.  ProgramMemory takes over space from register
/// storage as needed.  We also keep the return stack for GSB instructions
/// here, and the current program line.
///
/// ProgramMemory takes care of the 15C's two-byte program instructions
/// (cf. 15C manual page 218).  For example, if line 3 is F-ENG-2, the next
/// line will be line 4, despite the fact that F-ENG-2 takes up two bytes.
///
abstract class ProgramMemory<OT extends ProgramOperation> {
  MProgramRunner? runner;
  bool get isRunning => runner != null;

  MProgramRunner? suspendedProgram;

  @protected
  final Memory<OT> memory;

  /// Indexed by opcode
  @protected
  final List<OT?> _operationTable;

  /// Indexed by opcode
  @protected
  final List<ArgDone?> _argValues;

  @protected
  final int _extendedOpcode;
  // 0xfe on 15C, which means fe and ff are each a 256-entry page of
  // extended opcodes, where 0xfe is 0x100-0x1ff and xff are 0x200-0x2ff.
  // The 15C doesn't use up all of the potential opcodes, however.

  @protected
  final ProgramOperation _rtn;

  int _lines = 0;
  // Number of lines with extended op codes
  int _extendedLines = 0;

  final List<int> _returnStack;
  int _returnStackPos = -1;
  int get returnStackPos => _returnStackPos;

  /// Current line (editing and/or execution)
  int _currentLine = 0;

  /// opcodeAt(line) caches a line # and a corresponding address, since calculating
  /// the address would be O(n), given multibyte instructions.
  int _cachedLine = 1;

  /// Line 1 is stored starting at address 0
  int _cachedAddress = 0;

  /// This is a testing hook; tests can override this to tweak behaviors
  /// and detect events.
  ProgramListener programListener = ProgramListener();

  ProgramMemory(
      this.memory, OperationMap<OT> layout, int returnStackSize, this._rtn)
      : _returnStack = List.filled(returnStackSize, 0),
        _operationTable = layout._operationTable,
        _argValues = layout._argValues,
        _extendedOpcode = layout._extendedOpcode;

  /// 7-byte chunks occupied
  int get _chunksOccupied => (_lines + _extendedLines + 6) ~/ 7;

  int get programBytes => _chunksOccupied * 7;

  int get _maxAddress => (_lines + _extendedLines) * 2 - 1;

  /// Number of lines in the program
  int get lines => _lines;

  int get currentLine => _currentLine;

  int get bytesToNextAllocation =>
      ((memory.totalNybbles ~/ 14) * 7 - _lines - _extendedLines) % 7;

  set currentLine(int v) {
    if (v < 0 || (v > lines && v != MProgramRunner.pseudoReturnAddress)) {
      throw CalculatorError(4);
    }
    _currentLine = v;
  }

  bool get hasExtended => _extendedOpcode < 0x100;

  /// Insert a new instruction, and increment currentLine to refer to it.
  void insert(final ProgramInstruction<OT> instruction) {
    final needed = instruction.isExtended ? 2 : 1;
    if (bytesToNextAllocation < needed) {
      memory.policy.checkExtendProgramMemory();
    }
    assert(_currentLine >= 0 && _currentLine <= _lines);
    final storage = memory.storage;
    _setCachedAddress(_currentLine + 1);
    int addr = _cachedAddress; // stored as nybbles
    for (int a = _maxAddress; a >= addr; a--) {
      storage.setUint8(a + 2 * needed, storage.getUint8(a));
    }
    final int opcode = instruction.opcode;
    if (opcode >= 0x100) {
      assert(needed == 2);
      final int pageCode = (opcode >> 8) - 1 + _extendedOpcode;
      assert(pageCode >= _extendedOpcode && pageCode < 0x100);
      storage.setUint8(addr++, pageCode >> 4);
      storage.setUint8(addr++, pageCode & 0xf);
      _extendedLines++;
    } else {
      assert(needed == 1);
    }
    storage.setUint8(addr++, (opcode >> 4) & 0xf);
    storage.setUint8(addr++, opcode & 0xf);
    _lines++;
    _currentLine++; // Where we just inserted the instruction

    memory.model.needsSave = true;
  }

  void deleteCurrent() {
    assert(_lines > 0 && _currentLine > 0);
    final op = opcodeAt(_currentLine); // Sets _cachedAddress
    final extended = op >= 0x100;
    int addr = _cachedAddress;
    _lines--;
    _currentLine--;
    final int delta;
    if (extended) {
      _extendedLines--;
      delta = 4;
    } else {
      delta = 2;
    }
    final storage = memory.storage;
    while (addr <= _maxAddress) {
      storage.setUint8(addr, storage.getUint8(addr + delta));
      addr++;
    }
    if (extended) {
      storage.setUint8(addr++, 0);
      storage.setUint8(addr++, 0);
    }
    storage.setUint8(addr++, 0);
    storage.setUint8(addr, 0);

    memory.model.needsSave = true;
  }

  /// line counts from 1, with a phantom return at line 0
  ProgramInstruction<OT> operator [](final int line) {
    final int opCode = opcodeAt(line);
    final OT op = _operationTable[opCode]!;
    // "!" throws an exception on an illegal opCode, which is what we want.
    final ArgDone arg = _argValues[opCode]!;
    return memory.model.newProgramInstruction(op, arg);
    // We're storing the instructions as nybbles and creating
    // ProgramInstruction instances as needed, but not to save memory.
    // Rather, it's the easiest way of implementing it, given that we
    // want to store the program in a form that is faithful to the
    // original 16C, that preserves the memory management constraints.
    // The extra time we spend converting back and forth is, of course,
    // irrelevant.
  }

  List<ProgramInstruction<OT>> getAllInstructions() {
    final result = <ProgramInstruction<OT>>[];
    for (int opcode = 0; opcode < _operationTable.length; opcode++) {
      final op = _operationTable[opcode];
      if (op != null) {
        final arg = _argValues[opcode]!;
        final instr = memory.model.newProgramInstruction(op, arg);
        assert(instr.opcode == opcode);
        result.add(instr);
      }
    }
    return result;
  }

  void _setCachedAddress(final int line) {
    if (line < _cachedLine) {
      _cachedLine = 1;
      _cachedAddress = 0;
    }
    while (_cachedLine < line) {
      _cachedLine++;
      if (_byteAt(_cachedAddress) >= _extendedOpcode) {
        _cachedAddress += 4;
      } else {
        _cachedAddress += 2;
      }
    }
  }

  int opcodeAt(final int line) {
    if (line == 0) {
      return (_rtn.arg as ArgDone).opcode;
    }
    assert(line > 0 && line <= _lines);
    _setCachedAddress(line);
    final b = _byteAt(_cachedAddress);
    if (b < _extendedOpcode) {
      return b;
    } else {
      return (((b - _extendedOpcode) + 1) << 8) | _byteAt(_cachedAddress + 2);
    }
  }

  int _byteAt(int a) =>
      (memory.storage.getUint8(a) << 4) + memory.storage.getUint8(a + 1);

  ProgramInstruction<OT> getCurrent() => this[currentLine];

  void reset({bool zeroMemory = true}) {
    if (zeroMemory) {
      final storage = memory.storage;
      for (int i = 0; i < _lines * 2; i++) {
        storage.setUint8(i, 0);
      }
    }
    _lines = 0;
    _currentLine = 0;
    _extendedLines = 0;
    resetReturnStack();
    suspendedProgram?.abort();
    suspendedProgram = null;
  }

  Map<String, dynamic> toJson() => <String, Object>{
        'lines': _lines,
        'currentLine': _currentLine,
        'returnStack': _returnStack,
        'returnStackPos': _returnStackPos
      };

  /// Must be called after the register storage has been read in, so any
  /// stray data will be properly zeroed out.
  void decodeJson(Map<String, dynamic> json) {
    int n = (json['lines'] as num).toInt();
    if (n < 0 || n > memory.totalNybbles ~/ 2) {
      throw ArgumentError('$n:  Illegal number of lines');
    }
    _lines = n;
    _extendedLines = 0;
    // Check for illegal instructions
    try {
      for (_currentLine = 1; _currentLine <= _lines; _currentLine++) {
        final instr = getCurrent();
        if (instr.isExtended) {
          _extendedLines++;
        }
      }
      _currentLine = 0;
    } catch (e) {
      _lines = 0;
      _currentLine = 0;
      rethrow;
    }
    n = (json['currentLine'] as num).toInt();
    if (n < 0 || n > _lines) {
      n = 0;
    }
    _currentLine = n;

    final returnStack = (json['returnStack'] as List<dynamic>?);
    if (returnStack != null && returnStack.length == _returnStack.length) {
      for (int i = 0; i < returnStack.length; i++) {
        _returnStack[i] = returnStack[i] as int;
      }
    }
    final returnStackPos = (json['returnStackPos'] as num?);
    if (returnStackPos != null) {
      _returnStackPos = returnStackPos.toInt();
    }
  }

  List<String> get listing {
    final r = List<String>.empty(growable: true);
    r.add('   000 {          } ');
    for (int i = 1; i <= lines; i++) {
      String line = i.toString().padLeft(3, '0');
      final ProgramInstruction<OT> pi = this[i];
      final String pd = this[i].programDisplay;
      String semiHuman =
          pd.substring(1).replaceAll(',', ' ').replaceAll('  .', ' .');
      if (pd.startsWith('u')) {
        semiHuman = '$semiHuman u';
      }
      semiHuman = semiHuman.padLeft(8);
      assert(semiHuman.length == 8, '"$semiHuman" from $pd'); // and no longer
      String human = pi.programListing;
      r.add('   $line { $semiHuman } $human');
    }
    return r;
  }

  void stepCurrentLine(int sign) {
    int line = currentLine + sign;
    if (line < 0) {
      currentLine = lines;
    } else if (line > lines) {
      currentLine = 0;
    } else {
      currentLine = line;
    }
  }

  void skipIfRunning() {
    if (isRunning) {
      incrementCurrentLine();
      // This wraps if we're at the end of program memory.  I tested, and
      // the 15C behaves this way.
    }
  }

  void displayCurrent({bool flash = false, bool delayed = false}) {
    final display = memory.model.display;
    final String newText;
    if (currentLine == 0) {
      newText = '000-      ';
    } else {
      String ls = currentLine.toRadixString(10).padLeft(3, '0');
      String disp = getCurrent().programDisplay.toLowerCase();
      newText = '$ls$disp';
    }
    if (delayed) {
      final initial = memory.model._newLcdContents();
      display.current = newText;
      final delayed = memory.model._newLcdContents();
      final t = Timer(const Duration(milliseconds: 1400), () {
        display.show(delayed);
      });
      delayed._myTimer = t;
      initial._myTimer = t;
      display.show(initial);
    } else {
      display.current = newText;
      display.update(flash: flash);
    }
  }

  void popReturnStack() {
    if (_returnStackPos > 0) {
      currentLine = _returnStack[--_returnStackPos];
    } else {
      _returnStackPos = -1;
      currentLine = 0;
    }
  }

  void gosub(int label) {
    if (_returnStackPos >= _returnStack.length) {
      throw CalculatorError(5);
    }
    final returnTo = currentLine;
    goto(label);
    if (returnStackUnderflow) {
      // Keyboard entry of GSB, integrate or solve to start program
      _returnStackPos++;
    } else {
      _returnStack[_returnStackPos++] = returnTo;
    }
  }

  void goto(int label);

  @protected
  void gotoOpCode(int wanted) {
    // We might be at the label, so we start at 0.  Also, remember that
    // line 0 has the phantom return instruction, so we have to
    // iterate over lines+1 "lines".
    if (lines != 0) {
      for (int i = 0; i <= lines; i++) {
        int line = (currentLine + i) % lines;
        if (line == 0) {
          line = lines;
        }
        if (opcodeAt(line) == wanted) {
          currentLine = line;
          return;
        }
      }
    }
    throw CalculatorError(4);
  }

  void resetReturnStack() {
    _returnStackPos = -1;
    assert(returnStackUnderflow);
  }

  bool get returnStackUnderflow => _returnStackPos < 0;

  /// A RunStop keypress can resume a program, in which case the return stack
  /// should be left undisturbed.  It can also start a "new" program run,
  /// so we need to be sure the return stack isn't in underflow
  void adjustStackForRunStopStarting() {
    if (returnStackUnderflow) {
      _returnStackPos = 0;
    }
  }

  /// Increment the current line, up to a max of lines, wrapping to 0.
  /// To be clear, there are lines+1 possible values.
  ///
  /// Note that the branching instructions can cause the program to increment
  /// past the phantom RTN instruction at the end of memory, wrapping back
  /// to line 1.  This is intentional, and mirrors the behavior I observed
  /// on my 15C.
  void incrementCurrentLine() => currentLine = (currentLine + 1) % (lines + 1);

  void doNextIf(bool condition) {
    if (!condition) {
      incrementCurrentLine();
    }
  }

  String debugReturnStack() {
    final out = StringBuffer();
    out.write('                    return stack:');
    for (int i = 0; i < _returnStackPos; i++) {
      out.write('  ');
      out.write(_returnStack[i]);
    }
    return out.toString();
  }

  static final _whitespaceOrComma = RegExp(r'[\s+,]');

  ///
  /// Canonicalize the program display string
  ///
  static String _canonicalizePD(String pd) {
    if (pd.startsWith('-')) {
      pd = pd.substring(1);
    } else if (pd.startsWith('u')) {
      pd = '${pd.substring(1)} u';
    }
    final keys = pd.trim().split(_whitespaceOrComma);
    final result = StringBuffer();
    for (String k in keys) {
      k = k.trim();
      if (k.isEmpty) {
        continue;
      }
      if (result.isNotEmpty) {
        result.write(' ');
      }
      if (k.startsWith('.') || k.startsWith(',')) {
        result.write('48 '); // decimal point, both 15C and 16C
        result.write(k.substring(1));
      } else {
        result.write(k);
      }
    }
    return result.toString();
  }

  void importProgram(String listing) {
    final Map<String, ProgramInstruction<OT>> pdToInstruction;
    {
      final allInstructions = getAllInstructions();
      pdToInstruction = <String, ProgramInstruction<OT>>{
        for (final v in allInstructions) _canonicalizePD(v.programDisplay): v
      };
      assert(allInstructions.length == pdToInstruction.length);
    }
    final lines = listing.split('\n');
    final program = List<ProgramInstruction<OT>>.empty(growable: true);
    int lineNumber = 0;
    for (final line in lines) {
      lineNumber++;
      var rest = line.trim();
      if (rest.isEmpty || rest.startsWith('#')) {
        continue;
      }
      int pos = rest.indexOf(' ');
      if (pos == -1) {
        throw Exception('Error at line $lineNumber:  Line number not found');
      }
      final instructionNumber = int.tryParse(rest.substring(0, pos));
      if (instructionNumber == null) {
        throw Exception('No instruction number on line $lineNumber: $line');
      }
      rest = rest.substring(pos).trim();
      if (rest.substring(0, 1) != '{') {
        throw Exception('Error at line $lineNumber: '
            'Line doesn\'t have " {" after number: $line');
      }
      rest = rest.substring(1);
      pos = rest.indexOf('}');
      if (pos == -1) {
        throw Exception(
            'Syntax error at line $lineNumber: "}" not found: $line');
      }
      rest = _canonicalizePD(rest.substring(0, pos));
      if (rest.isEmpty) {
        if (program.isNotEmpty || instructionNumber != 0) {
          throw Exception(
              'Unexpected empty instruction at line $lineNumber: $line');
        }
      } else if (instructionNumber != program.length + 1) {
        throw Exception(
            'Unexpected instruction number at line $lineNumber: $line');
      } else {
        final instr = pdToInstruction[rest];
        if (instr == null) {
          throw Exception(
              'Instruction "$rest" not found at line $lineNumber: $line');
        }
        program.add(instr);
      }
    }
    final int len =
        program.fold(0, (n, instr) => n + (instr.isExtended ? 2 : 1));
    if (len > memory.policy.maxProgramBytes) {
      throw Exception('Insufficient space for $len byte program');
    }
    suspendedProgram?.abort();
    suspendedProgram = null;
    reset();
    for (final instr in program) {
      insert(instr);
    }
    currentLine = 0;
  }

  void importProgramFromFile(Uint8List original) {
    if (original.length > 1 && original[0] == 0xff && original[1] == 0xfe) {
      // UTF-16 LE (little endian).  It's not even supported by Dart's
      // encoder!  Also, Dart doesn't seem to have a little-endian to
      // native-endian converter.
      final sb = StringBuffer();
      for (int i = 2; i < original.length - 1; i += 2) {
        final code = original[i] | (original[i + 1] << 8);
        sb.writeCharCode(code);
      }
      return importProgram(sb.toString());
    } else {
      // Default to UTF8
      return importProgram(utf8.decoder.convert(original));
    }
  }
}

///
/// The model's view of an operation.  This is extended by the controller's
/// Operation class.  The parts of Operation that are relevant to the model
/// are lifted into the model class ProgramOperation so that Model doesn't
/// depend on a controller class.  Model is parameterized by ProgramOperation
/// so that the controller can refer to members of Operation that are logically
/// part of the controller.
///
abstract class ProgramOperation {
  Arg get arg;

  /// Human-readable name for program listing
  String get name;

  /// The row/column "name", which for digits looks like " 1".
  late final String rcName;

  late final int debugLogId;

  int get maxOneByteOpcodes => 9999;

  /// If used as an argument, the shift key needed for that argument.
  /// Rare:  sto g (LETTER) and rcl g (LETTER) do this.
  ProgramOperation? get argShift => null;

  static const _invalidOpcodeStart = -1;
  // Invalid op codes are negative, but still distinct.  That allows them to
  // be used in the capture of a debug key log.

  /// Give the numeric value of a number key, or one of the 15C's
  /// letters (which are 20..24).
  /// cf. tests.dart, SelfTests.testNumbers().
  int? get numericValue => null;

  /// Name for this key as an arg in the program listing, if other than the
  /// default.
  String? get programListingArgName => null;

  /// Is this the f or g shift key?
  bool get isShift => false;
}

///
/// The model's view of a key on the keyboard.  The model needs to know where
/// [ProgramOperation]s are on the portrait layout of the keyboard, because
/// they are displayed on the LCD display as row-column numbers.
///
class MKey<OT extends ProgramOperation> {
  final OT unshifted;
  final OT fShifted;
  final OT gShifted;

  final List<MKeyExtensionOp<OT>> extensionOps;

  const MKey(this.unshifted, this.fShifted, this.gShifted,
      {this.extensionOps = const []});
}

@immutable
class MKeyExtensionOp<OT extends ProgramOperation> {
  final OT op;
  final OT? shiftIn;
  final OT? secondShift;

  const MKeyExtensionOp(this.op, this.shiftIn, this.secondShift);
}

///
/// An instruction in a program, consisting of a [ProgramOperation] and
/// a keyboard argument value.
///
abstract class ProgramInstruction<OT extends ProgramOperation> {
  final OT op;

  final ArgDone arg;

  ProgramInstruction(this.op, this.arg);

  bool get isExtended => arg.opcode >= 0x100;

  final _noWidth = RegExp('[,.]');

  int get opcode => arg.opcode;

  @protected
  String rightJustify(String s, int len) {
    int nw = _noWidth.allMatches(s).length;
    return s.padLeft(6 + nw);
  }

  ///
  /// How this is displayed in the LCD
  ///
  String get programDisplay => arg.programDisplay;

  /// How this is displayed in a program listing
  String get programListing => arg.programListing;

  @override
  String toString() => 'ProgramInstruction($programListing)';
}

///
/// A representation of all of the operations.  This is used by the model
/// to assign op codes and labels to [ProgramOperation]s.
///
class OperationMap<OT extends ProgramOperation> {
  final int registerBase;
  final List<List<MKey<OT>?>> keys;
  final List<OT> numbers;

  /// Operations that can't be stored in the calculator's memory
  final List<OT> special;

  /// Key entry shortcuts, like how on the 16C, I is RCL-I and (i) is RCL-(i)
  final Map<OT, ArgDone> shortcuts;

  /// Maps from opCode to ProgramOperation.  Each operation occurs in the
  /// table 1+maxArg times.
  List<OT?> _operationTable = List.filled(0x400, null, growable: false);
  List<ArgDone?> _argValues = List.filled(0x400, null, growable: false);
  int _nextOpcode = 0;
  int _nextExtendedOpcode = 0;
  int _extendedOpcode = 0;
  // The "opcode" that means "this is an extended opcode".
  // Opcodes >= _extendedOpcode are extended.

  OperationMap._internal(
      this.registerBase, this.keys, this.numbers, this.special, this.shortcuts);

  static OperationMap? _instance;

  factory OperationMap(
      {required int registerBase,
      required List<List<MKey<OT>?>> keys,
      required List<OT> numbers,
      required List<OT> special,
      required Map<OT, ArgDone> shortcuts}) {
    final instance = _instance;
    if (instance == null) {
      final i = _instance = OperationMap<OT>._internal(
          registerBase, keys, numbers, special, shortcuts);
      i._initialize();
      return i;
    } else {
      assert(instance.registerBase == registerBase);
      assert(instance.keys == keys);
      assert(instance.numbers == numbers);
      assert(instance.special == special);
      return instance as OperationMap<OT>;
    }
  }

  void _initialize() {
    final visited = <OT>{};
    int nextInvalidOpcode = ProgramOperation._invalidOpcodeStart;
    for (int i = 0; i < numbers.length; i++) {
      final o = numbers[i];
      final ok = visited.add(o);
      assert(ok);
      o.rcName = ' ${i.toRadixString(16).toUpperCase()}';
      _initializeOperation(o, null);
    }
    for (int row = 0; row < keys.length; row++) {
      final keyRow = keys[row];
      for (int col = 0; col < keyRow.length; col++) {
        final MKey<OT>? key = keyRow[col];
        if (key == null) {
          continue;
        }
        if (!visited.contains(key.unshifted)) {
          key.unshifted.rcName = '${row + 1}${(col + 1) % 10}';
        }
        final String rcText = key.unshifted.rcName;
        if (!visited.contains(key.fShifted) && key.fShifted != key.unshifted) {
          key.fShifted.rcName = rcText;
        }
        if (!visited.contains(key.gShifted) && key.gShifted != key.unshifted) {
          key.gShifted.rcName = rcText;
        }
        for (final MKeyExtensionOp<OT> ext in key.extensionOps) {
          ext.op.rcName = rcText;
        }
      }
    }
    for (final k in shortcuts.keys) {
      assert(!visited.contains(k));
      visited.add(k);
      // We will visit k at the end, when the thing to which it is a
      // shortcut has been initialized.
    }
    for (int i = 0; i < special.length; i++) {
      // Handle keys that can't be part of a program
      final o = special[i];
      final ok = visited.add(o);
      assert(ok);
      o.debugLogId = nextInvalidOpcode;
      o.arg.init(registerBase,
          shift: null, arg: null, argDot: false, userMode: false, f: (ArgDone r,
              {required ProgramOperation? arg,
              required ProgramOperation? shift,
              required bool argDot,
              required bool userMode}) {
        r.opcode = nextInvalidOpcode--;
        r.programDisplay = 'unreachable';
        r.programListing = 'unreachable';
      });
    }
    for (int row = 0; row < keys.length; row++) {
      final keyRow = keys[row];
      for (int col = 0; col < keyRow.length; col++) {
        final MKey<OT>? key = keyRow[col];
        if (key == null) {
          continue;
        }
        if (!visited.contains(key.unshifted)) {
          visited.add(key.unshifted);
          _initializeOperation(key.unshifted, null);
        }
        if (!visited.contains(key.fShifted)) {
          visited.add(key.fShifted);
          _initializeOperation(key.fShifted, Arg.fShift);
        }
        if (!visited.contains(key.gShifted)) {
          visited.add(key.gShifted);
          _initializeOperation(key.gShifted, Arg.gShift);
        }
        for (final MKeyExtensionOp<OT> ext in key.extensionOps) {
          visited.add(ext.op);
          _initializeOperation(ext.op, ext.shiftIn, ext.secondShift);
        }
      }
    }
    shortcuts.forEach((OT op, ArgDone v) {
      final s = op.arg as ArgDone;
      s.opcode = v.opcode;
      s.programDisplay = v.programDisplay;
      s.programListing = v.programListing;
      op.debugLogId = s.opcode;
    });
    // The HP 15C has 452 extended op codes.  Wow!
    final int pages = (_nextExtendedOpcode + 0xff) >> 8;
    _extendedOpcode = 0x100 - pages;
    assert(_extendedOpcode >= 0 && _nextOpcode <= _extendedOpcode,
        'one byte opcodes:  $_nextOpcode, extended opcode: $_extendedOpcode');
    final len = (_nextExtendedOpcode == 0)
        ? _nextOpcode
        : (_nextExtendedOpcode + 0x100);
    _operationTable = List.unmodifiable(_operationTable.getRange(0, len));
    _argValues = List.unmodifiable(_argValues.getRange(0, len));
  }

  void _initializeOperation(OT op, ProgramOperation? shiftIn,
      [ProgramOperation? secondShift]) {
    int remaining = op.maxOneByteOpcodes;
    op.debugLogId = remaining == 0 ? _nextExtendedOpcode : _nextOpcode;
    op.arg.init(registerBase,
        shift: shiftIn,
        arg: null,
        argDot: false,
        userMode: false, f: (ArgDone r,
            {required bool argDot,
            required ProgramOperation? shift,
            required ProgramOperation? arg,
            required bool userMode}) {
      if (remaining-- > 0) {
        r.opcode = _nextOpcode++;
      } else {
        r.opcode = 0x100 + _nextExtendedOpcode++;
      }
      _operationTable[r.opcode] = op;
      _argValues[r.opcode] = r;
      final String dash = userMode ? 'u' : '-';
      final String pd, pl;
      if (secondShift != null) {
        assert(shift != null);
        assert(arg == null);
        pd = '${shift!.rcName},${secondShift.rcName},${op.rcName}';
        pl = op.name;
      } else if (shift == null && arg == null) {
        assert(!argDot);
        pd = '    ${op.rcName}';
        pl = op.name;
      } else if (arg == null) {
        assert(!argDot);
        pd = ' ${shift!.rcName} ${op.rcName}';
        pl = op.name;
      } else {
        // arg != null
        final String as, las;
        if (argDot) {
          as = ' .${arg.rcName.trim()}';
          assert(as.length == 3);
          las = ' 1${arg.rcName.trim()}';
        } else {
          as = arg.rcName;
          assert(as.length == 2, '$op:  $arg $as');
          if (arg == Arg.kI || arg == Arg.kParenI) {
            las = ' ${arg.name}';
          } else if (arg == Arg.kDot) {
            las = ' .'; // "FLOAT  ." is nicer than "FLOAT 48".
          } else {
            las = ' ${(arg.programListingArgName ?? as.trim())}';
          }
        }
        if (shift == null) {
          final argShift = arg.argShift;
          if (argShift == null) {
            pd = ' ${op.rcName} $as';
          } else {
            pd = '${op.rcName},${argShift.rcName},$as';
          }
          pl = '${op.name}$las';
        } else if (shift.isShift) {
          pd = '${shift.rcName},${op.rcName},$as';
          pl = '${op.name}$las';
        } else {
          // Shift is an operation, like + in like "STO + 0"
          pd = '${op.rcName},${shift.rcName},$as';
          pl = '${op.name} ${shift.name}$las';
        }
      }
      r.programDisplay = '$dash$pd';
      final userName = userMode ? 'u ' : '';
      if (shiftIn == null) {
        r.programListing = '$userName$pl';
      } else {
        r.programListing = '$userName${shiftIn.name} $pl';
      }
      assert(r.programDisplay.length < 20, '$op');
    });
  }
}

///
/// The model's view of the thing that runs a program.
///
abstract class MProgramRunner {
  static const int pseudoReturnAddress = 0xdeadbeef;

  int get registersRequired;

  ///
  /// Can be called from the calculation part of operations
  /// (e.g. integrate and solve.)
  ///
  void startRunningProgram(covariant MProgramRunner newRunner);

  void pushPseudoReturn(Model m) {
    final program = m.memory.program;
    if (program.returnStackPos >= program._returnStack.length) {
      throw CalculatorError(5);
    }
    if (program._returnStackPos == -1) {
      program._returnStackPos = 0;
    } else {
      program._returnStack[program._returnStackPos++] = pseudoReturnAddress;
    }
  }

  void abort();

  String snapshotText();
}

///
///  A listener that receives callbacks when a program delivers results
///  to the user.
///
class ProgramListener {
  /// Called when the program finishes normally, via a RTN instruction.
  void onDone() {}

  /// Called when an R/S instruction stops the program (usually in the
  /// middle, to deliver intermediate results).
  void onRS() {}

  /// Called when a PSE instruction momentarily pauses the program to
  /// display results.
  void onPause() {}

  /// Called when the program stops due to a CalculatorError
  void onError(CalculatorError err) {}

  /// Called when the program is stopped due to a keypress
  void onStop() {}

  /// A future that completes when we should resume from a pause instruction,
  /// after [onPause()] is called.
  Future<void> resumeFromPause() => Future.delayed(const Duration(seconds: 1));

  /// Called at the moment a calculator error is shown, whether a program is
  /// running or not.  If a program is running, this should be followed by
  /// onError().
  void onErrorShown(CalculatorError err, StackTrace? stack) {}
}
