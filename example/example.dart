import 'dart:io';
import 'package:binary_interop/binary_interop.dart';
import 'package:binary_interop/binary_callback/binary_callback.dart';
import 'package:libc/headers.dart';
import 'package:sqlite3_driver/headers.dart';
import 'package:sqlite3_driver/sqlite3_bindings.dart';

void main() {
  var t = new BinaryTypes();
  var h = new BinaryTypeHelper(t);
  h.addHeaders(SQLITE3_HEADERS);
  h.addHeaders(LIBC_HEADERS);
  var sqlite3 = loadSqlite3Bindings(t);
  var version = sqlite3.sqlite3_libversion();
  print(h.readString(version));

  var filename = "test.db";

  var ppDb = t["sqlite3*"].alloc(null);
  var err = sqlite3.sqlite3_open(filename, ppDb);
  if (err != 0) {
    print("Can't open database: ${sqlite3.sqlite3_errmsg(ppDb.value)}");
    exit(-1);
  } else {
    print("Opened database successfully");
  }

  var sql = """
CREATE TABLE COMPANY(
ID INT PRIMARY KEY NOT NULL,
NAME TEXT    NOT NULL,
AGE INT NOT NULL,
ADDRESS CHAR(50),
SALARY REAL);
""";

  var cb = new BinaryCallback.binary(t["sqlite3_callback"].type, (List<BinaryData> args, BinaryData returns) {
    var argc = args[1].value;
    var argv = args[2];
    var azColName = args[3];
    for (var i = 0; i < argc; i++) {
      var name = h.readString(azColName[i].value);
      var value = h.readString(argv[i].value);
      print("$name = $value");
    }

    returns.value = 0;
  });

  var zErrMsg = t["char*"].alloc();

  err = sqlite3.sqlite3_exec(
      ppDb.value, sql, cb.functionCode, t["void*"].nullPtr, zErrMsg);

  if (err != Sqlite3Bindings.SQLITE_OK) {
    print("SQL error: ${h.readString(zErrMsg.value)}");
    sqlite3.sqlite3_free(zErrMsg);
  } else {
    print("Table created successfully");
  }

  sql = """
INSERT INTO COMPANY (ID,NAME,AGE,ADDRESS,SALARY)
VALUES (1, 'Paul', 32, 'California', 20000.00 );
INSERT INTO COMPANY (ID,NAME,AGE,ADDRESS,SALARY)
VALUES (2, 'Allen', 25, 'Texas', 15000.00 );
INSERT INTO COMPANY (ID,NAME,AGE,ADDRESS,SALARY)
VALUES (3, 'Teddy', 23, 'Norway', 20000.00 );
INSERT INTO COMPANY (ID,NAME,AGE,ADDRESS,SALARY)
VALUES (4, 'Mark', 25, 'Rich-Mond ', 65000.00 );
""";

  err = sqlite3.sqlite3_exec(
      ppDb.value, sql, cb.functionCode, t["void*"].nullPtr, zErrMsg);

  if (err != Sqlite3Bindings.SQLITE_OK) {
    print("SQL error: ${h.readString(zErrMsg.value)}");
    sqlite3.sqlite3_free(zErrMsg);
  } else {
    print("Records created successfully");
  }

  sql = "SELECT * from COMPANY";

  err = sqlite3.sqlite3_exec(
      ppDb.value, sql, cb.functionCode, t["void*"].nullPtr, zErrMsg);

  if (err != Sqlite3Bindings.SQLITE_OK) {
    print("SQL error: ${h.readString(zErrMsg.value)}");
    sqlite3.sqlite3_free(zErrMsg);
  } else {
    print("Operation done successfully");
  }

  sqlite3.sqlite3_close(ppDb.value);
}
