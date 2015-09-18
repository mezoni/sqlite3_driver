part of sqlite3_driver.dbc;

abstract class SqlConnection {
  Future<int> get affectedRows;

  bool get isOpen;

  Future<int> get lastInsertId;

  Future close();

  Future open();
}

class SqlException {
  String message;

  SqlException([this.message]);

  String toString() {
    if (message == null) {
      return "SqlException";
    } else {
      return "SqlException: $message";
    }
  }
}

abstract class SqlDataRow {
  int get length;

  Iterable<String> get names;

  dynamic operator [](dynamic key);
}

abstract class SqlStatement {
  String get commandText;

  SqlConnection get connection;

  Future execute([dynamic parameters]);

  Future<Stream<SqlDataRow>> executeQuery([dynamic parameters]);

  Future free();

  Future prepare();
}
