import 'dart:async';

import 'package:sqlite3_driver/sqlite3_driver.dart';

Future main() async {
  var sw = new Stopwatch();
  _start(sw, "Open connection");
  var connection = new Sqlite3Connection(":memory:");
  _stop(sw, "Open connection");
  await connection.open();
  try {
    _start(sw, "Create table");
    var stmt0 = new Sqlite3Statement(connection, sqlCreateTable);
    await stmt0.execute();
    _stop(sw, "Create table");


    var count = 10000;
    _start(sw, "Insert $count rows");
    var stmt1 = new Sqlite3Statement(connection, sqlInsertData);
    for (var i = 0; i < count; i++) {
      var parameters = {};
      parameters[":ID"] = i;
      parameters[":NAME"] = "Name";
      parameters[":AGE"] = 25;
      parameters[":ADDRESS"] = "Address";
      parameters[":SALARY"] = 10000.0;
      parameters[":DATA"] = [0, i];
      await stmt1.execute(parameters);
    }

    _stop(sw, "Insert $count rows");

    _start(sw, "Read $count rows");
    var stmt2 = new Sqlite3Statement(connection, sqlReadData);
    await stmt2.executeQuery({":AGE": 25});
    _stop(sw, "Read $count rows");

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
  print("$message: ${sw.elapsedMilliseconds / 1000} sec" );
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

String sqlInsertData = """
INSERT INTO COMPANY (ID, NAME, AGE, ADDRESS, SALARY, DATA)
VALUES (:ID, :NAME, :AGE, :ADDRESS, :SALARY, :DATA);
""";

String sqlReadData = """
SELECT *
FROM COMPANY
WHERE AGE = :AGE;
""";