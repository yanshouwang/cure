import 'dart:convert';
import 'dart:typed_data';

import 'package:cure/core.dart';
import 'package:tuple/tuple.dart';

final messagePack = MessagePackCodec();

class MessagePackCodec extends Codec<Object, Uint8List> {
  final Map<int, MessagePackExtensionCodec> _decoders;
  final Map<Type, MessagePackExtensionCodec> _encoders;
  final MessagePackDecodeOptions _decodeOptions;
  final MessagePackEncodeOptions _encodeOptions;

  @override
  Converter<Uint8List, Object> get decoder =>
      _MessagePackDecoder(_decoders, _decodeOptions);
  @override
  Converter<Object, Uint8List> get encoder =>
      _MessagePackEncoder(_encoders, _encodeOptions);

  MessagePackCodec({
    MessagePackDecodeOptions decodeOptions,
    MessagePackEncodeOptions encodeOptions,
  })  : _decoders = {},
        _encoders = {},
        _decodeOptions = decodeOptions,
        _encodeOptions = encodeOptions {
    _register(TimestampCodec());
  }

  void _register<T>(MessagePackExtensionCodec<T> codec) {
    // keep decoders and encoders are ont-to-one relationship.
    if (_encoders.containsKey(T)) {
      final encoder = _encoders[T];
      if (encoder.type < 0) {
        throw ArgumentError.value(T);
      } else if (encoder.type != codec.type) {
        throw ArgumentError.value(codec.type);
      }
    }
    _decoders[codec.type] = codec;
    _encoders[T] = codec;
  }

  void register<T>(MessagePackExtensionCodec<T> codec) {
    if (codec.type < 0 || codec.type > 128) {
      throw ArgumentError.value(codec.type);
    }
    _register(codec);
  }

  void unregister<T>() {
    if (_encoders.containsKey(T)) {
      final codec = _encoders[T];
      if (codec.type < 0) {
        throw ArgumentError.value(T);
      }
      _decoders.remove(codec.type);
      _encoders.remove(T);
    }
  }

  @override
  Object decode(Uint8List source, [MessagePackDecodeOptions options]) {
    if (options == null) {
      return decoder.convert(source);
    } else {
      return _MessagePackDecoder(_decoders, options).convert(source);
    }
  }

  @override
  Uint8List encode(Object obj, [MessagePackEncodeOptions options]) {
    if (options == null) {
      return encoder.convert(obj);
    } else {
      return _MessagePackEncoder(_encoders, options).convert(obj);
    }
  }
}

class _MessagePackDecoder extends Converter<Uint8List, Object> {
  final Map<int, MessagePackExtensionCodec> decoders;
  final int maxStrLength;
  final int maxBinaryLength;
  final int maxArrayLength;
  final int maxMapLength;
  final int maxExtensionLength;

  final List<StackState> stack;

  int totalPos;
  int pos;

  Uint8List bytes;
  ByteData view;
  int headByte;

  _MessagePackDecoder(this.decoders, MessagePackDecodeOptions options)
      : maxStrLength = options?.maxStrLength ?? DEFAULT_MAX_LENGTH,
        maxBinaryLength = options?.maxBinaryLength ?? DEFAULT_MAX_LENGTH,
        maxArrayLength = options?.maxArrayLength ?? DEFAULT_MAX_LENGTH,
        maxMapLength = options?.maxMapLength ?? DEFAULT_MAX_LENGTH,
        maxExtensionLength = options?.maxExtensionLength ?? DEFAULT_MAX_LENGTH,
        stack = [] {
    totalPos = 0;
    pos = 0;
    bytes = Uint8List(0);
    view = ByteData.view(bytes.buffer);
    headByte = HEAD_BYTE_REQUIRED;
  }

  @override
  Object convert(Uint8List source) {
    reinitializeState();
    setBuffer(source);

    final object = decode();
    if (hasRemaining()) {
      throw createExtraByteError(pos);
    }
    return object;
  }

  void reinitializeState() {
    totalPos = 0;
    headByte = HEAD_BYTE_REQUIRED;
  }

  void setBuffer(Uint8List buffer) {
    bytes = buffer;
    view = ByteData.view(bytes.buffer);
    pos = 0;
  }

  Object decode() {
    DECODE:
    while (true) {
      final headByte = readHeadByte();
      Object object;

      if (headByte >= 0xe0) {
        // negative fixint (111x xxxx) 0xe0 - 0xff
        object = headByte - 0x100;
      } else if (headByte < 0xc0) {
        if (headByte < 0x80) {
          // positive fixint (0xxx xxxx) 0x00 - 0x7f
          object = headByte;
        } else if (headByte < 0x90) {
          // fixmap (1000 xxxx) 0x80 - 0x8f
          final size = headByte - 0x80;
          if (size != 0) {
            addMapState(size);
            complete();
            continue;
          } else {
            object = {};
          }
        } else if (headByte < 0xa0) {
          // fixarray (1001 xxxx) 0x90 - 0x9f
          final size = headByte - 0x90;
          if (size != 0) {
            addArrayState(size);
            complete();
            continue;
          } else {
            object = [];
          }
        } else {
          // fixstr (101x xxxx) 0xa0 - 0xbf
          final byteLength = headByte - 0xa0;
          object = decodeString(byteLength, 0);
        }
      } else if (headByte == 0xc0) {
        // nil
        object = null;
      } else if (headByte == 0xc2) {
        // false
        object = false;
      } else if (headByte == 0xc3) {
        // true
        object = true;
      } else if (headByte == 0xca) {
        // float 32
        object = readF32();
      } else if (headByte == 0xcb) {
        // float 64
        object = readF64();
      } else if (headByte == 0xcc) {
        // uint 8
        object = readU8();
      } else if (headByte == 0xcd) {
        // uint 16
        object = readU16();
      } else if (headByte == 0xce) {
        // uint 32
        object = readU32();
      } else if (headByte == 0xcf) {
        // uint 64
        final value = readU64();
        object = value >= 0 ? value : BigInt.from(value).toUnsigned(64);
      } else if (headByte == 0xd0) {
        // int 8
        object = readI8();
      } else if (headByte == 0xd1) {
        // int 16
        object = readI16();
      } else if (headByte == 0xd2) {
        // int 32
        object = readI32();
      } else if (headByte == 0xd3) {
        // int 64
        object = readI64();
      } else if (headByte == 0xd9) {
        // str 8
        final byteLength = lookU8();
        object = decodeString(byteLength, 1);
      } else if (headByte == 0xda) {
        // str 16
        final byteLength = lookU16();
        object = decodeString(byteLength, 2);
      } else if (headByte == 0xdb) {
        // str 32
        final byteLength = lookU32();
        object = decodeString(byteLength, 4);
      } else if (headByte == 0xdc) {
        // array 16
        final size = readU16();
        if (size != 0) {
          addArrayState(size);
          complete();
          continue;
        } else {
          object = [];
        }
      } else if (headByte == 0xdd) {
        // array 32
        final size = readU32();
        if (size != 0) {
          addArrayState(size);
          complete();
          continue;
        } else {
          object = [];
        }
      } else if (headByte == 0xde) {
        // map 16
        final size = readU16();
        if (size != 0) {
          addMapState(size);
          complete();
          continue;
        } else {
          object = {};
        }
      } else if (headByte == 0xdf) {
        // map 32
        final size = readU32();
        if (size != 0) {
          addMapState(size);
          complete();
          continue;
        } else {
          object = {};
        }
      } else if (headByte == 0xc4) {
        // bin 8
        final size = lookU8();
        object = decodeBinary(size, 1);
      } else if (headByte == 0xc5) {
        // bin 16
        final size = lookU16();
        object = decodeBinary(size, 2);
      } else if (headByte == 0xc6) {
        // bin 32
        final size = lookU32();
        object = decodeBinary(size, 4);
      } else if (headByte == 0xd4) {
        // fixext 1
        object = decodeExtension(1, 0);
      } else if (headByte == 0xd5) {
        // fixext 2
        object = decodeExtension(2, 0);
      } else if (headByte == 0xd6) {
        // fixext 4
        object = decodeExtension(4, 0);
      } else if (headByte == 0xd7) {
        // fixext 8
        object = decodeExtension(8, 0);
      } else if (headByte == 0xd8) {
        // fixext 16
        object = decodeExtension(16, 0);
      } else if (headByte == 0xc7) {
        // ext 8
        final size = lookU8();
        object = decodeExtension(size, 1);
      } else if (headByte == 0xc8) {
        // ext 16
        final size = lookU16();
        object = decodeExtension(size, 2);
      } else if (headByte == 0xc9) {
        // ext 32
        final size = lookU32();
        object = decodeExtension(size, 4);
      } else {
        throw Exception('Unrecognized type byte: ${prettyByte(headByte)}');
      }

      complete();

      final stack = this.stack;
      while (stack.isNotEmpty) {
        // arrays and maps
        final state = stack[stack.length - 1];
        if (state is StackArrayState) {
          state.array[state.position] = object;
          state.position++;
          if (state.position != state.size) {
            continue DECODE;
          } else {
            stack.removeLast();
            object = state.array;
          }
        } else if (state is StackMapState) {
          if (state.type == State.map_key) {
            state.key = object;
            state.type = State.map_value;
            continue DECODE;
          } else {
            // it must be `state.type == State.MAP_VALUE` here
            state.map[state.key] = object;
            state.readCount++;

            if (state.readCount != state.size) {
              state.key = null;
              state.type = State.map_key;
              continue DECODE;
            } else {
              stack.removeLast();
              object = state.map;
            }
          }
        } else {
          throw ArgumentError.value(state);
        }
      }

      return object;
    }
  }

  int readHeadByte() {
    if (headByte == HEAD_BYTE_REQUIRED) {
      headByte = readU8();
    }

    return headByte;
  }

  void complete() {
    headByte = HEAD_BYTE_REQUIRED;
  }

  void addMapState(int size) {
    if (size > maxMapLength) {
      throw Exception(
          'Max length exceeded: map length ($size) > maxMapLengthLength ($maxMapLength)');
    }

    final state = StackMapState(State.map_key, size, null, 0, {});
    stack.add(state);
  }

  void addArrayState(int size) {
    if (size > maxArrayLength) {
      throw Exception(
          'Max length exceeded: array length ($size) > maxArrayLength ($maxArrayLength)');
    }

    final state =
        StackArrayState(State.array, size, 0, List.filled(size, null));
    stack.add(state);
  }

  String decodeString(int byteLength, int headerOffset) {
    if (byteLength > maxStrLength) {
      throw Exception(
          'Max length exceeded: UTF-8 byte length ($byteLength) > maxStrLength ($maxStrLength)');
    }

    if (bytes.lengthInBytes < pos + headerOffset + byteLength) {
      throw RangeError('Insufficient data');
    }

    final offset = pos + headerOffset;
    final stringBytes = bytes.sublist(offset, offset + byteLength);
    final object = utf8.decode(stringBytes);
    pos += headerOffset + byteLength;
    return object;
  }

  bool stateIsMapKey() {
    if (stack.isNotEmpty) {
      return stack.last.type == State.map_key;
    }
    return false;
  }

  Uint8List decodeBinary(int byteLength, int headOffset) {
    if (byteLength > maxBinaryLength) {
      throw Exception(
          'Max length exceeded: bin length ($byteLength) > maxBinLength ($maxBinaryLength)');
    }

    if (!hasRemaining(byteLength + headOffset)) {
      throw RangeError('Insufficient data');
    }

    final offset = pos + headOffset;
    final object = bytes.sublist(offset, offset + byteLength);
    pos += headOffset + byteLength;
    return object;
  }

  Object decodeExtension(int size, int headOffset) {
    if (size > maxExtensionLength) {
      throw Exception(
          'Max length exceeded: ext length ($size) > maxExtLength ($maxExtensionLength)');
    }

    final type = view.getInt8(pos + headOffset);
    final data = decodeBinary(size, headOffset + 1 /* extType */);
    if (decoders.containsKey(type)) {
      final decoder = decoders[type];
      return decoder.decode(data);
    } else {
      return Tuple2(type, data);
    }
  }

  bool hasRemaining([size = 1]) {
    return view.lengthInBytes - pos >= size;
  }

  RangeError createExtraByteError(int posToShow) {
    return RangeError(
        'Extra ${view.lengthInBytes - pos} of ${view.lengthInBytes} byte(s) found at buffer[$posToShow]');
  }

  int lookU8() {
    return view.getUint8(pos);
  }

  int lookU16() {
    return view.getUint16(pos);
  }

  int lookU32() {
    return view.getUint32(pos);
  }

  int readU8() {
    final value = view.getUint8(pos);
    pos++;
    return value;
  }

  int readI8() {
    final value = view.getInt8(pos);
    pos++;
    return value;
  }

  int readU16() {
    final value = view.getUint16(pos);
    pos += 2;
    return value;
  }

  int readI16() {
    final value = view.getInt16(pos);
    pos += 2;
    return value;
  }

  int readU32() {
    final value = view.getUint32(pos);
    pos += 4;
    return value;
  }

  int readI32() {
    final value = view.getInt32(pos);
    pos += 4;
    return value;
  }

  int readU64() {
    final value = view.getUint64(pos);
    pos += 8;
    return value;
  }

  int readI64() {
    final value = view.getInt64(pos);
    pos += 8;
    return value;
  }

  double readF32() {
    final value = view.getFloat32(pos);
    pos += 4;
    return value;
  }

  double readF64() {
    final value = view.getFloat64(pos);
    pos += 8;
    return value;
  }
}

enum State {
  array,
  map_key,
  map_value,
}

abstract class StackState {
  State type;
}

class StackMapState implements StackState {
  @override
  State type;
  int size;
  Object key;
  int readCount;
  Map map;

  StackMapState(this.type, this.size, this.key, this.readCount, this.map);
}

class StackArrayState implements StackState {
  @override
  State type;
  int size;
  int position;
  List array;

  StackArrayState(this.type, this.size, this.position, this.array);
}

const DEFAULT_MAX_LENGTH = 0xffffffff;
const HEAD_BYTE_REQUIRED = -1;

class _MessagePackEncoder extends Converter<Object, Uint8List> {
  final Map<Type, MessagePackExtensionCodec> encoders;
  final Object Function(Object) toEncodable;
  final int maxDepth;
  final int initialSize;
  final bool sortKeys;
  final bool forceFloat32;
  final bool forceIntegerToFloat;

  int pos;
  ByteData view;
  Uint8List bytes;

  _MessagePackEncoder(this.encoders, MessagePackEncodeOptions options)
      : toEncodable = options?.toEncodable ?? _defaultToEncodable,
        maxDepth = options?.maxDepth ?? DEFAULT_MAX_DEPTH,
        initialSize = options?.initialSize ?? DEFAULT_INITIAL_SIZE,
        sortKeys = options?.sortKeys ?? false,
        forceFloat32 = options?.forceFloat32 ?? false,
        forceIntegerToFloat = options?.forceIntegerToFloat ?? false {
    pos = 0;
    bytes = Uint8List(initialSize);
    view = ByteData.view(bytes.buffer);
  }

  @override
  Uint8List convert(Object object) {
    pos = 0;
    encode(object, 1);
    return bytes.sublist(0, pos);
  }

  void encode(Object object, int depth) {
    if (depth > maxDepth) {
      throw Exception('Too deep objects in depth $depth');
    }

    if (object == null) {
      encodeNil();
    } else if (object is bool) {
      encodeBoolean(object);
    } else if (object is int) {
      encodeInteger(object);
    } else if (object is BigInt) {
      encodeBigInteger(object);
    } else if (object is double) {
      encodeFloat(object);
    } else if (object is String) {
      encodeString(object);
    } else if (object is Uint8List) {
      encodeBinary(object);
    } else if (object is List) {
      encodeArray(object, depth);
    } else if (object is Map) {
      encodeMap(object, depth);
    } else {
      encodeOthers(object);
    }
  }

  void encodeNil() {
    writeU8(0xc0);
  }

  void encodeBoolean(bool value) {
    if (value == false) {
      writeU8(0xc2);
    } else {
      writeU8(0xc3);
    }
  }

  void encodeInteger(int value) {
    if (forceIntegerToFloat) {
      final number = value.toDouble();
      encodeFloat(number);
    } else if (value >= 0) {
      if (value < 0x80) {
        // positive fixint
        writeU8(value);
      } else if (value < 0x100) {
        // uint 8
        writeU8(0xcc);
        writeU8(value);
      } else if (value < 0x10000) {
        // uint 16
        writeU8(0xcd);
        writeU16(value);
      } else if (value < 0x100000000) {
        // uint 32
        writeU8(0xce);
        writeU32(value);
      } else {
        // uint 64
        writeU8(0xcf);
        writeU64(value);
      }
    } else {
      if (value >= -0x20) {
        // nagative fixint
        writeU8(0xe0 | (value + 0x20));
      } else if (value >= -0x80) {
        // int 8
        writeU8(0xd0);
        writeI8(value);
      } else if (value >= -0x8000) {
        // int 16
        writeU8(0xd1);
        writeI16(value);
      } else if (value >= -0x80000000) {
        // int 32
        writeU8(0xd2);
        writeI32(value);
      } else {
        // int 64
        writeU8(0xd3);
        writeI64(value);
      }
    }
  }

  void encodeFloat(double value) {
    // non-integer numbers
    if (forceFloat32) {
      // float 32
      writeU8(0xca);
      writeF32(value);
    } else {
      // float 64
      writeU8(0xcb);
      writeF64(value);
    }
  }

  void encodeBigInteger(BigInt value) {
    if (value.isValidInt) {
      final number = value.toInt();
      encodeInteger(number);
    } else if (forceIntegerToFloat) {
      final number = value.toDouble();
      encodeFloat(number);
    } else {
      writeU8(0xcf);
      writeU8a(value.toArray());
    }
  }

  void encodeString(String value) {
    final maxHeaderSize = 1 + 4;

    final byteLength = value.utf8Count;
    ensureBufferSizeToWrite(maxHeaderSize + byteLength);
    writeStringHeader(byteLength);
    value.encodeUTF8(bytes, pos);
    pos += byteLength;
  }

  void encodeBinary(Uint8List values) {
    final size = values.lengthInBytes;
    if (size < 0x100) {
      // bin 8
      writeU8(0xc4);
      writeU8(size);
    } else if (size < 0x10000) {
      // bin 16
      writeU8(0xc5);
      writeU16(size);
    } else if (size < 0x100000000) {
      // bin 32
      writeU8(0xc6);
      writeU32(size);
    } else {
      throw Exception('Too large binary: $size');
    }
    writeU8a(values);
  }

  void encodeArray(List values, int depth) {
    final size = values.length;
    if (size < 16) {
      // fixarray
      writeU8(0x90 + size);
    } else if (size < 0x10000) {
      // array 16
      writeU8(0xdc);
      writeU16(size);
    } else if (size < 0x100000000) {
      // array 32
      writeU8(0xdd);
      writeU32(size);
    } else {
      throw Exception('Too large array: $size');
    }
    for (final item in values) {
      encode(item, depth + 1);
    }
  }

  void encodeMap(Map values, int depth) {
    final keys = values.keys.toList();
    if (sortKeys) {
      keys.sort();
    }

    final size = keys.length;

    if (size < 16) {
      // fixmap
      writeU8(0x80 + size);
    } else if (size < 0x10000) {
      // map 16
      writeU8(0xde);
      writeU16(size);
    } else if (size < 0x100000000) {
      // map 32
      writeU8(0xdf);
      writeU32(size);
    } else {
      throw Exception('Too large map object: $size');
    }

    for (final key in keys) {
      final value = values[key];

      encodeString(key);
      encode(value, depth + 1);
    }
  }

  void encodeOthers(Object object) {
    if (encoders.containsKey(object.runtimeType)) {
      final encoder = encoders[object.runtimeType];
      final data = encoder.encode(object);
      final size = data.length;
      if (size == 1) {
        // fixext 1
        writeU8(0xd4);
      } else if (size == 2) {
        // fixext 2
        writeU8(0xd5);
      } else if (size == 4) {
        // fixext 4
        writeU8(0xd6);
      } else if (size == 8) {
        // fixext 8
        writeU8(0xd7);
      } else if (size == 16) {
        // fixext 16
        writeU8(0xd8);
      } else if (size < 0x100) {
        // ext 8
        writeU8(0xc7);
        writeU8(size);
      } else if (size < 0x10000) {
        // ext 16
        writeU8(0xc8);
        writeU16(size);
      } else if (size < 0x100000000) {
        // ext 32
        writeU8(0xc9);
        writeU32(size);
      } else {
        throw Exception('Too large extension object: $size');
      }
      writeI8(encoder.type);
      writeU8a(data);
    } else {
      final encodable = toEncodable(object);
      encode(encodable, 1);
    }
  }

  void writeU8(int value) {
    ensureBufferSizeToWrite(1);

    view.setUint8(pos, value);
    pos++;
  }

  void writeU8a(Uint8List values) {
    final size = values.length;
    ensureBufferSizeToWrite(size);

    bytes.setAll(pos, values);
    pos += size;
  }

  void writeI8(int value) {
    ensureBufferSizeToWrite(1);

    view.setInt8(pos, value);
    pos++;
  }

  void writeU16(int value) {
    ensureBufferSizeToWrite(2);

    view.setUint16(pos, value);
    pos += 2;
  }

  void writeI16(int value) {
    ensureBufferSizeToWrite(2);

    view.setInt16(pos, value);
    pos += 2;
  }

  void writeU32(int value) {
    ensureBufferSizeToWrite(4);

    view.setUint32(pos, value);
    pos += 4;
  }

  void writeI32(int value) {
    ensureBufferSizeToWrite(4);

    view.setInt32(pos, value);
    pos += 4;
  }

  void writeF32(double value) {
    ensureBufferSizeToWrite(4);
    view.setFloat32(pos, value);
    pos += 4;
  }

  void writeU64(int value) {
    ensureBufferSizeToWrite(8);

    view.setUint64(pos, value);
    pos += 8;
  }

  void writeI64(int value) {
    ensureBufferSizeToWrite(8);

    view.setInt64(pos, value);
    pos += 8;
  }

  void writeF64(double value) {
    ensureBufferSizeToWrite(8);
    view.setFloat64(pos, value);
    pos += 8;
  }

  void ensureBufferSizeToWrite(int sizeToWrite) {
    final requiredSize = pos + sizeToWrite;

    if (view.lengthInBytes < requiredSize) {
      resizeBuffer(requiredSize * 2);
    }
  }

  void resizeBuffer(int newSize) {
    final newBytes = Uint8List(newSize);
    final newView = ByteData.view(newBytes.buffer);

    newBytes.setAll(0, bytes);
    view = newView;
    bytes = newBytes;
  }

  void writeStringHeader(int byteLength) {
    if (byteLength < 32) {
      // fixstr
      writeU8(0xa0 + byteLength);
    } else if (byteLength < 0x100) {
      // str 8
      writeU8(0xd9);
      writeU8(byteLength);
    } else if (byteLength < 0x10000) {
      // str 16
      writeU8(0xda);
      writeU16(byteLength);
    } else if (byteLength < 0x100000000) {
      // str 32
      writeU8(0xdb);
      writeU32(byteLength);
    } else {
      throw Exception('Too long string: $byteLength bytes in UTF-8');
    }
  }
}

// reuse JSON format by default.
Object _defaultToEncodable(dynamic object) => object.toJSON();

const DEFAULT_MAX_DEPTH = 100;
const DEFAULT_INITIAL_SIZE = 2048;

class MessagePackDecodeOptions {
  final int maxStrLength;
  final int maxBinaryLength;
  final int maxArrayLength;
  final int maxMapLength;
  final int maxExtensionLength;

  MessagePackDecodeOptions({
    this.maxStrLength,
    this.maxBinaryLength,
    this.maxArrayLength,
    this.maxMapLength,
    this.maxExtensionLength,
  });
}

class MessagePackEncodeOptions {
  final Object Function(Object) toEncodable;
  final int maxDepth;
  final int initialSize;
  final bool sortKeys;
  final bool forceFloat32;
  final bool forceIntegerToFloat;

  MessagePackEncodeOptions({
    this.toEncodable,
    this.maxDepth,
    this.initialSize,
    this.sortKeys,
    this.forceFloat32,
    this.forceIntegerToFloat,
  });
}

abstract class MessagePackExtensionCodec<T> extends Codec<T, Uint8List> {
  int get type;
}

const EXT_TIMESTAMP = -1;
const TIMESTAMP32_MAX_SEC = 0x100000000 - 1; // 32-bit unsigned int
const TIMESTAMP64_MAX_SEC = 0x400000000 - 1; // 34-bit unsigned int

class TimestampCodec extends MessagePackExtensionCodec<Timestamp> {
  @override
  int get type => EXT_TIMESTAMP;
  @override
  Converter<Uint8List, Timestamp> get decoder => _TimestampDecoder();
  @override
  Converter<Timestamp, Uint8List> get encoder => _TimestampEncoder();
}

class _TimestampDecoder extends Converter<Uint8List, Timestamp> {
  @override
  Timestamp convert(Uint8List data) {
    final view = ByteData.sublistView(data);
    // data may be 32, 64, or 96 bits
    switch (data.lengthInBytes) {
      case 4:
        {
          // timestamp 32 = { sec32 }
          final sec = view.getUint32(0);
          final nsec = 0;

          return Timestamp(sec, nsec);
        }
      case 8:
        {
          // timestamp 64 = { nsec30, sec34 }
          final nsec30AndSecHigh2 = view.getUint32(0);
          final secLow32 = view.getUint32(4);
          final sec = (nsec30AndSecHigh2 & 0x3) * 0x100000000 + secLow32;
          final nsec = nsec30AndSecHigh2 >> 2;

          return Timestamp(sec, nsec);
        }
      case 12:
        {
          // timestamp 96 = { nsec32 (unsigned), sec64 (signed) }
          final sec = view.getInt64(4);
          final nsec = view.getUint32(0);

          return Timestamp(sec, nsec);
        }
      default:
        throw Exception(
            'Unrecognized source size for timestamp: ${data.length}');
    }
  }
}

class _TimestampEncoder extends Converter<Timestamp, Uint8List> {
  @override
  Uint8List convert(Timestamp timestamp) {
    final sec = timestamp.seconds;
    final nsec = timestamp.nanoseconds;

    if (sec >= 0 && nsec >= 0 && sec <= TIMESTAMP64_MAX_SEC) {
      // Here sec >= 0 && nsec >= 0
      if (nsec == 0 && sec <= TIMESTAMP32_MAX_SEC) {
        // timestamp 32 = { sec32 (unsigned) }
        final rv = Uint8List(4);
        final view = ByteData.view(rv.buffer);
        view.setUint32(0, sec);
        return rv;
      } else {
        // timestamp 64 = { nsec30 (unsigned), sec34 (unsigned) }
        final secHigh = sec >> 32;
        final secLow = sec & 0xffffffff;
        final rv = Uint8List(8);
        final view = ByteData.view(rv.buffer);
        // nsec30 | secHigh2
        view.setUint32(0, (nsec << 2) | (secHigh & 0x3));
        // secLow32
        view.setUint32(4, secLow);
        return rv;
      }
    } else {
      // timestamp 96 = { nsec32 (unsigned), sec64 (signed) }
      final rv = Uint8List(12);
      final view = ByteData.view(rv.buffer);
      view.setUint32(0, nsec);
      view.setInt64(4, sec);
      return rv;
    }
  }
}

extension on String {
  int get utf8Count {
    final strLength = length;
    var byteLength = 0;
    var pos = 0;
    while (pos < strLength) {
      var value = codeUnitAt(pos++);
      if ((value & 0xffffff80) == 0) {
        // 1-byte
        byteLength++;
        continue;
      } else if ((value & 0xfffff800) == 0) {
        // 2-bytes
        byteLength += 2;
      } else {
        // handle surrogate pair
        if (value >= 0xd800 && value <= 0xdbff) {
          // high surrogate
          if (pos < strLength) {
            final extra = codeUnitAt(pos);
            if ((extra & 0xfc00) == 0xdc00) {
              ++pos;
              value = ((value & 0x3ff) << 10) + (extra & 0x3ff) + 0x10000;
            }
          }
        }

        if ((value & 0xffff0000) == 0) {
          // 3-byte
          byteLength += 3;
        } else {
          // 4-byte
          byteLength += 4;
        }
      }
    }
    return byteLength;
  }

  void encodeUTF8(Uint8List output, int outputOffset) {
    final data = utf8.encode(this);
    output.setAll(outputOffset, data);
  }
}

extension on BigInt {
  Uint8List toArray() {
    var number = this;
    // Not handling negative numbers. Decide how you want to do that.
    final length = (number.bitLength + 7) >> 3;
    var b256 = BigInt.from(256);
    var result = Uint8List(length);
    for (var i = length - 1; i >= 0; i--) {
      result[i] = number.remainder(b256).toInt();
      number = number >> 8;
    }
    return result;
  }
}

BigInt fromArray(Uint8List bytes) {
  BigInt read(int start, int end) {
    if (end - start <= 4) {
      var result = 0;
      for (var i = end - 1; i >= start; i--) {
        result = result * 256 + bytes[i];
      }
      return BigInt.from(result);
    }
    var mid = start + ((end - start) >> 1);
    var result =
        read(start, mid) + read(mid, end) * (BigInt.one << ((mid - start) * 8));
    return result;
  }

  return read(0, bytes.length);
}

String prettyByte(int byte) {
  return '${byte < 0 ? "-" : ""}0x${byte.abs().toRadixString(16).padLeft(2, "0")}';
}
