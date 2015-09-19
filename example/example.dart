import 'dart:async';

import 'package:sqlite3_driver/sqlite3_driver.dart';

Future main() async {
  var sw = new Stopwatch();
  // ****************
  // Create connection
  // ****************
  _start(sw, "Create connection");
  var connection = new Sqlite3Connection(":memory:");
  _stop(sw, "Create connection");

  // ****************
  // Open connection
  // ****************
  _start(sw, "Open connection");
  await connection.open();
  _stop(sw, "Open connection");

  try {
    // ****************
    // Create table
    // ****************
    _start(sw, "Create table");
    var stmtCreate = new Sqlite3Statement(connection, sqlCreateTable);
    await stmtCreate.execute();
    _stop(sw, "Create table");

    // ****************
    // Insert data
    // ****************
    var count = 10000;
    _start(sw, "Insert $count rows");
    var stmtInsert = new Sqlite3Statement(connection, sqlInsertData);
    for (var i = 0; i < count; i++) {
      var parameters = {};
      parameters[":ID"] = i;
      parameters[":NAME"] = "Name";
      parameters[":AGE"] = 25;
      parameters[":ADDRESS"] = "Address";
      parameters[":SALARY"] = 10000.0;
      parameters[":DATA"] = [0, i];
      await stmtInsert.execute(parameters);
    }

    _stop(sw, "Insert $count rows");

    // ****************
    // Read data
    // ****************
    _start(sw, "Read $count rows");
    var stmtSelect = new Sqlite3Statement(connection, sqlReadData);
    var stream = await stmtSelect.executeQuery({":AGE": 25});
    await for (var row in stream) {
      var id = row["ID"];
    }

    _stop(sw, "Read $count rows");

    // ****************
    // Delete data
    // ****************
    _start(sw, "Delete $count rows");
    var stmtDelete = new Sqlite3Statement(connection, sqlDeleteData);
    await stmtDelete.execute({":AGE": 25});
    var affectedRows = await connection.affectedRows;
    _stop(sw, "Delete $affectedRows rows");
  } finally {
    connection.close();
  }
}

void _start(Stopwatch sw, String message) {
  print("$message...");
  sw.reset();
  sw.start();
}

void _stop(Stopwatch sw, String message) {
  sw.stop();
  print("$message: ${sw.elapsedMilliseconds / 1000} sec");
}

String sqlCreateTable = """
CREATE TABLE COMPANY (
ID INT PRIMARY KEY NOT NULL,
NAME TEXT NOT NULL,
AGE INT NOT NULL,
ADDRESS CHAR(50),
SALARY REAL,
DATA BLOB);
""";

String sqlDeleteData = """
DELETE
FROM COMPANY
WHERE AGE = :AGE;
""";

String sqlInsertData = """
INSERT INTO COMPANY (ID, NAME, AGE, ADDRESS, SALARY, DATA)
VALUES (:ID, :NAME, :AGE, :ADDRESS, :SALARY, :DATA);
""";

String sqlReadData = """
SELECT *
FROM COMPANY
WHERE AGE = :AGE;
""";
