/**
 Copyright IBM Corporation 2017

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import XCTest
import SwiftKuery

#if os(Linux)
let tableParameters = "tableParametersLinux"
#else
let tableParameters = "tableParametersOSX"
#endif

class TestParameters: MySQLTest {

    static var allTests: [(String, (TestParameters) -> () throws -> Void)] {
        return [
            ("testParameters", testParameters),
            ("testMultipleParameterSets", testMultipleParameterSets),
            ("testNamedParameters", testNamedParameters),
        ]
    }

    class MyTable : Table {
        let a = Column("a")
        let b = Column("b")

        let tableName = tableParameters
    }

    func testParameters() {
        performTest(characterSet: "latin2", asyncTasks: { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { _ in }
            defer {
                cleanUp(table: t.tableName, connection: connection) { _ in }
            }

            executeRawQuery("CREATE TABLE " +  t.tableName + " (a varchar(40), b integer) CHARACTER SET latin2", connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
            }

            let i1 = Insert(into: t, rows: [[Parameter(), 10], ["apricot", Parameter()], [Parameter(), Parameter()]])
            executeQueryWithParameters(query: i1, connection: connection, parameters: ["apple\u{0FF9D}0FF9D", 3, "banana€euro", -8]) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
            }

            let s1 = Select(from: t)
            executeQuery(query: s1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                XCTAssertNotNil(rows, "SELECT returned no rows")
                XCTAssertEqual(rows?.count, 3, "SELECT returned wrong number of rows: \(rows?.count) instead of 3")
                XCTAssertEqual(rows?[0][0] as? String, "apple\u{0FF9D}0FF9D", "Wrong value in row 0 column 0: \(rows?[0][0]) instead of 'apple\u{0FF9D}0FF9D'")
                XCTAssertEqual(rows?[1][0] as? String, "apricot", "Wrong value in row 0 column 0: \(rows?[1][0]) instead of 'apricot'")
                XCTAssertEqual(rows?[2][0] as? String, "banana€euro", "Wrong value in row 0 column 0: \(rows?[2][0]) instead of 'banana€euro'")
                XCTAssertEqual(rows?[0][1] as? Int32, 10, "Wrong value in row 0 column 0: \(rows?[0][1]) instead of 10")
                XCTAssertEqual(rows?[1][1] as? Int32, 3, "Wrong value in row 0 column 0: \(rows?[1][1]) instead of 3")
                XCTAssertEqual(rows?[2][1] as? Int32, -8, "Wrong value in row 0 column 0: \(rows?[2][1]) instead of -8")
            }

            let u1 = Update(t, set: [(t.a, Parameter()), (t.b, Parameter())], where: t.a == "banana€euro")
            executeQueryWithParameters(query: u1, connection: connection, parameters: ["peach", 2]) { result, rows in
                XCTAssertEqual(result.success, true, "UPDATE failed")
                XCTAssertNil(result.asError, "Error in UPDATE: \(result.asError!)")
            }

            executeQuery(query: s1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                XCTAssertNotNil(rows, "SELECT returned no rows")
                XCTAssertEqual(rows?.count, 3, "SELECT returned wrong number of rows: \(rows?.count) instead of 3")
                XCTAssertEqual(rows?[2][0] as? String, "peach", "Wrong value in row 0 column 0: \(rows?[2][0]) instead of 'peach'")
                XCTAssertEqual(rows?[2][1] as? Int32, 2, "Wrong value in row 0 column 0: \(rows?[2][1]) instead of 2")
            }

            let raw = "UPDATE " + t.tableName + " SET a = 'banana', b = ? WHERE a = ?"
            executeRawQueryWithParameters(raw, connection: connection, parameters: [4, "peach"]) { result, rows in
                XCTAssertEqual(result.success, true, "UPDATE failed")
                XCTAssertNil(result.asError, "Error in UPDATE: \(result.asError!)")

                executeQuery(query: s1, connection: connection) { result, rows in
                    XCTAssertEqual(result.success, true, "SELECT failed")
                    XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                    XCTAssertNotNil(rows, "SELECT returned no rows")
                    XCTAssertEqual(rows?.count, 3, "SELECT returned wrong number of rows: \(rows?.count) instead of 3")
                    XCTAssertEqual(rows?[2][0] as? String, "banana", "Wrong value in row 0 column 0: \(rows?[2][0]) instead of 'peach'")
                    XCTAssertEqual(rows?[2][1] as? Int32, 4, "Wrong value in row 0 column 0: \(rows?[2][1]) instead of 4")
                }
            }
        })
    }

    func testMultipleParameterSets() {
        performTest(asyncTasks: { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { _ in }
            defer {
                cleanUp(table: t.tableName, connection: connection) { _ in }
            }

            executeRawQuery("CREATE TABLE " +  t.tableName + " (a varchar(40), b integer)", connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
            }

            let i1 = "insert into " + t.tableName + " values(?, ?)"
            let parametersArray = [["apple", 10], ["apricot", 3], ["banana", -8]]
            executeRawQueryWithParameters(i1, connection: connection, parametersArray: parametersArray) { result, rows in
                XCTAssertEqual(result.success, true, "INSERT failed")
                XCTAssertNil(result.asError, "Error in INSERT: \(result.asError!)")
            }

            let s1 = Select(from: t)
            executeQuery(query: s1, connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "SELECT failed")
                XCTAssertNotNil(result.asResultSet, "SELECT returned no rows")
                XCTAssertNotNil(rows, "SELECT returned no rows")
                XCTAssertEqual(rows?.count, 3, "SELECT returned wrong number of rows: \(rows?.count) instead of 3")
                XCTAssertEqual(rows?[0][0] as? String, "apple", "Wrong value in row 0 column 0: \(rows?[0][0]) instead of 'apple'")
                XCTAssertEqual(rows?[1][0] as? String, "apricot", "Wrong value in row 0 column 0: \(rows?[1][0]) instead of 'apricot'")
                XCTAssertEqual(rows?[2][0] as? String, "banana", "Wrong value in row 0 column 0: \(rows?[2][0]) instead of 'banana'")
                XCTAssertEqual(rows?[0][1] as? Int32, 10, "Wrong value in row 0 column 0: \(rows?[0][1]) instead of 10")
                XCTAssertEqual(rows?[1][1] as? Int32, 3, "Wrong value in row 0 column 0: \(rows?[1][1]) instead of 3")
                XCTAssertEqual(rows?[2][1] as? Int32, -8, "Wrong value in row 0 column 0: \(rows?[2][1]) instead of -8")
            }
        })
    }

    func testNamedParameters() {
        performTest(asyncTasks: { connection in
            let t = MyTable()
            cleanUp(table: t.tableName, connection: connection) { _ in }
            defer {
                cleanUp(table: t.tableName, connection: connection) { _ in }
            }

            executeRawQuery("CREATE TABLE " +  t.tableName + " (a varchar(40), b integer)", connection: connection) { result, rows in
                XCTAssertEqual(result.success, true, "CREATE TABLE failed")
                XCTAssertNil(result.asError, "Error in CREATE TABLE: \(result.asError!)")
            }

            let i1 = Insert(into: t, rows: [[Parameter("p1"), 10], ["apricot", Parameter("p2")], [Parameter("p3"), Parameter("p4")]])
            let namedParameters: [String:Any] = ["p1": "apple", "p2": 3, "p3": "banana", "p4": -8]
            executeQueryWithParameters(query: i1, connection: connection, parameters: namedParameters) { result, rows in
                XCTAssertEqual(result.success, false, "Expected failure with named parameters, but returned success")
                XCTAssertNotNil(result.asError, "Expected error with named parameters, but no error returned")
            }

            do {
                let rawQuery = try connection.descriptionOf(query: i1)
                executeRawQueryWithParameters(rawQuery, connection: connection, parameters: namedParameters) { result, rows in
                    XCTAssertEqual(result.success, false, "Expected failure with named parameters, but returned success")
                    XCTAssertNotNil(result.asError, "Expected error with named parameters, but no error returned")
                }
            } catch {
                XCTFail("Error building query: \(error)")
            }
        })
    }
}