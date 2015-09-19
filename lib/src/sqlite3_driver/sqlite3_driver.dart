part of sqlite3_driver;

class Sqlite3Connection implements SqlConnection {
  Set<SqlStatement> _statements = new Set<SqlStatement>();

  String _filename;

  _SqliteHelper _helper;

  BinaryData _pDb;

  Sqlite3Connection(String filename) {
    if (filename == null) {
      new ArgumentError.notNull("filename");
    }

    _filename = filename;
    _helper = new _SqliteHelper();
  }

  Future<int> get affectedRows async {
    if (_pDb == null) {
      return 0;
    }

    return _helper.bindings.sqlite3_changes(_pDb);
  }

  bool get isOpen {
    return _pDb != null;
  }

  Future<int> get lastInsertId async {
    if (_pDb == null) {
      return 0;
    }

    return _helper.bindings.sqlite3_last_insert_rowid(_pDb);
  }

  Future close() async {
    if (_pDb == null) {
      return;
    }

    for (var statement in _statements.toList()) {
      await statement.free();
    }

    var errorCode = _helper.bindings.sqlite3_close(_pDb);
    _helper.checkError(errorCode, this);
    _pDb = null;
  }

  Future open() async {
    if (_pDb != null) {
      return;
    }

    var ppDb = _helper.types["sqlite3*"].alloc(null);
    var pFilename = _helper.allocString16(_filename);
    var errorCode = _helper.bindings.sqlite3_open16(pFilename, ppDb);
    _pDb = ppDb.value;
    if (_pDb.isNullPtr) {
      throw new SqlException("Not enough memory");
    }

    _helper.checkError(errorCode, this);
  }
}

class Sqlite3Statement implements SqlStatement {
  final String commandText;

  final Sqlite3Connection connection;

  _SqliteHelper _helper;

  BinaryData _pStmt;

  Sqlite3Statement(this.connection, this.commandText) {
    if (connection == null) {
      throw new ArgumentError.notNull("connection");
    }

    if (commandText == null) {
      throw new ArgumentError.notNull("commandText");
    }

    if (commandText.trim().isEmpty) {
      throw new ArgumentError("Command text is empty");
    }

    if (!connection.isOpen) {
      throw new SqlException("Connection is not open");
    }

    _helper = new _SqliteHelper();
    var ppStmt = _helper.types["sqlite3_stmt*"].alloc(null);
    var pVoid = _helper.types["void*"].nullPtr;
    var pCommandText = _helper.allocString16(commandText);
    var errorCode = _helper.bindings
        .sqlite3_prepare16_v2(connection._pDb, pCommandText, -1, ppStmt, pVoid);
    _helper.checkError(errorCode, connection);
    _pStmt = ppStmt.value;
    connection._statements.add(this);
  }

  Future execute([dynamic parameters]) async {
    _checkConnection();
    _bindParameters(parameters);
    var errorCode = _helper._bindings.sqlite3_step(_pStmt);
    _checkResult(errorCode);
    _reset();
    return null;
  }

  Future<Stream<SqlDataRow>> executeQuery([dynamic parameters]) async {
    _checkConnection();
    _bindParameters(parameters);
    var controller = new StreamController<SqlDataRow>();
    var columnCount = _helper._bindings.sqlite3_column_count(_pStmt);
    var columns = new List<String>(columnCount);
    int errorCode;
    var int16_t = _helper.types["int16_t"];
    for (var i = 0; i < columnCount; i++) {
      var name =
          _helper.readString(_helper._bindings.sqlite3_column_name(_pStmt, i));
      columns[i] = name;
    }

    while ((errorCode = _helper._bindings.sqlite3_step(_pStmt)) ==
        Sqlite3Bindings.SQLITE_ROW) {
      var data = <String, dynamic>{};
      for (var i = 0; i < columnCount; i++) {
        var columnType = _helper._bindings.sqlite3_column_type(_pStmt, i);
        var value;
        switch (columnType) {
          case Sqlite3Bindings.SQLITE_BLOB:
            var numberOfBytes =
                _helper._bindings.sqlite3_column_bytes(_pStmt, i);
            var pBuffer = _helper._bindings.sqlite3_column_blob(_pStmt, i);
            var aChar = _helper.types["char[$numberOfBytes]"]
                .extern(pBuffer.base, pBuffer.offset);
            value = aChar.value;
            break;
          case Sqlite3Bindings.SQLITE_FLOAT:
            value = _helper._bindings.sqlite3_column_double(_pStmt, i);
            break;
          case Sqlite3Bindings.SQLITE_INTEGER:
            value = _helper._bindings.sqlite3_column_int64(_pStmt, i);
            break;
          case Sqlite3Bindings.SQLITE3_TEXT:
            var pData = _helper._bindings.sqlite3_column_text16(_pStmt, i);
            value = _helper.readString16(pData);
            break;
          case Sqlite3Bindings.SQLITE_NULL:
            value = null;
            break;
          default:
            throw new SqlException(
                "Unsupported data type '$columnType' of column $i");
        }

        data[columns[i]] = value;
      }

      controller.add(new _SqliteDataRow(data));
    }

    _checkResult(errorCode);
    _reset();
    controller.close();
    return controller.stream;
  }

  Future free() async {
    if (_pStmt == null) {
      return;
    }

    _helper.bindings.sqlite3_finalize(_pStmt);
    connection._statements.remove(this);
  }

  Future prepare() async {
    if (_pStmt != null) {
      return;
    }
  }

  void _bindParameter(int index, dynamic parameter) {
    index++;
    int errorCode;
    if (parameter == null) {
      errorCode = _helper.bindings.sqlite3_bind_null(_pStmt, index);
    } else if (parameter is int) {
      errorCode = _helper.bindings.sqlite3_bind_int64(_pStmt, index, parameter);
    } else if (parameter is double) {
      errorCode =
          _helper.bindings.sqlite3_bind_double(_pStmt, index, parameter);
    } else if (parameter is String) {
      var pData = _helper.allocString16(parameter);
      // TODO: Optimize
      var f = _helper.types["void*"].extern(Sqlite3Bindings.SQLITE_TRANSIENT);
      errorCode =
          _helper.bindings.sqlite3_bind_text16(_pStmt, index, pData, -1, f);
    } else if (parameter is List) {
      var length = parameter.length;
      if (length == 0) {
        errorCode = _helper.bindings.sqlite3_bind_zeroblob(_pStmt, index, -1);
      } else {
        var pData = _helper.types["uint8_t[$length]"].alloc(parameter);
        // TODO: Optimize
        var f = _helper.types["void*"].extern(Sqlite3Bindings.SQLITE_TRANSIENT);
        errorCode =_helper.bindings.sqlite3_bind_blob(_pStmt, index, pData, length, f);
      }

    } else {
      throw new ArgumentError(
          "Unsupported type of parameter '$index': ${parameter.runtimeType} ");
    }

    _helper.checkError(errorCode, connection);
  }

  void _bindParameters(dynamic parameters) {
    if (parameters == null) {
      return;
    }

    if (parameters is List) {
      _bindParameterFromList(parameters);
      return;
    }

    if (parameters is Map) {
      _bindParameterFromMap(parameters);
      return;
    }

    throw new ArgumentError.value(parameters, "parameters");
  }

  void _bindParameterFromList(List parameters) {
    var length = parameters.length;
    for (var i = 0; i < length; i++) {
      var parameter = parameters[i];
      _bindParameter(i, parameter);
    }
  }

  void _bindParameterFromMap(Map parameters) {
    for (var name in parameters.keys) {
      // TODO: Convert parameter in UTF-8
      var index = _helper.bindings.sqlite3_bind_parameter_index(_pStmt, name);
      if (index == 0) {
        throw new ArgumentError("Parameter '$name' not found");
      }

      _bindParameter(index - 1, parameters[name]);
    }
  }

  void _checkConnection() {
    if (!connection.isOpen) {
      throw new SqlException("Connection is not open");
    }

    if (_pStmt == null) {
      throw new SqlException("Statement already finalized");
    }
  }

  void _checkResult(int errorCode) {
    if (errorCode != Sqlite3Bindings.SQLITE_DONE) {
      _helper.checkError(errorCode, connection);
    }
  }

  void _reset() {
    _helper._bindings.sqlite3_reset(_pStmt);
  }
}

class _SqliteDataRow implements SqlDataRow {
  final Map<String, dynamic> _data;

  List _list;

  _SqliteDataRow(this._data);

  int get length {
    return _data.length;
  }

  Iterable<String> get names {
    return _data.keys;
  }

  dynamic operator [](dynamic key) {
    if (key == null) {
      throw new ArgumentError.notNull("key");
    }

    if (key is String) {
      if (_data.containsKey(key)) {
        return _data[key];
      } else {
        throw new ArgumentError("Invalid key '$key'");
      }
    } else if (key is int) {
      if (_list == null) {
        _list = _data.values.toList();
      }

      var length = _list.length;
      if (key >= 0 && key < length) {
        return _list[key];
      } else {
        throw new RangeError.range(key, 0, length - 1, "key");
      }
    } else {
      throw new ArgumentError.value(key, "key");
    }
  }
}

class _SqliteHelper {
  static _SqliteHelper _instance;

  Sqlite3Bindings _bindings;

  BinaryTypeHelper _helper;

  BinaryTypes _types;

  factory _SqliteHelper() {
    if (_instance == null) {
      _instance = new _SqliteHelper._internal();
    }

    return _instance;
  }

  _SqliteHelper._internal() {
    _types = new BinaryTypes();
    _helper = new BinaryTypeHelper(types);
    _helper.addHeaders(SQLITE3_HEADERS);
    _helper.addHeaders(LIBC_HEADERS);
    _bindings = loadSqlite3Bindings(types);
  }

  Sqlite3Bindings get bindings {
    return _bindings;
  }

  BinaryTypeHelper get helper {
    return _helper;
  }

  BinaryTypes get types {
    return _types;
  }

  BinaryData allocString16(String string) {
    // TODO: Optimize
    var int16_t = types["int16_t"];
    return helper.allocString(string, type: int16_t);
  }

  void checkError(int errorCode, Sqlite3Connection connection) {
    String message;
    if (errorCode != Sqlite3Bindings.SQLITE_OK) {
      if (connection._pDb != null) {
        message = readString(_bindings.sqlite3_errmsg(connection._pDb));
      }

      throw new SqlException(message);
    }
  }

  String readString(BinaryData data) {
    return helper.readString(data);
  }

  String readString16(BinaryData data) {
    // TODO: Optimize
    var int16_t = types["int16_t"];
    var ptr = int16_t.extern(data.base, data.offset);
    return helper.readString(ptr);
  }
}
