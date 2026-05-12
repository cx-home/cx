import XCTest
import CXLib
import Foundation

final class TableTests: XCTestCase {

    func testFromCxSimple() throws {
        let src = """
        [users :table[name age:int]
          alice 30
          bob 25
        ]
        """
        let t = try Table.fromCx(src)
        XCTAssertEqual(t.rowCount, 2)
        XCTAssertEqual(t.colCount, 2)
    }

    func testFromCxNoTableThrows() {
        XCTAssertThrowsError(try Table.fromCx("[product name=alice]")) { err in
            XCTAssertTrue("\(err)".contains("no :table"))
        }
    }

    func testCreateValidatesLen() {
        XCTAssertThrowsError(try Table.create(cols: ["a", "b"], types: ["int"], rows: [])) { err in
            XCTAssertTrue("\(err)".contains("len(cols)"))
        }
    }

    func testCreateValidatesUnique() {
        XCTAssertThrowsError(try Table.create(cols: ["a", "a"], types: ["int", "int"], rows: [])) { err in
            XCTAssertTrue("\(err)".contains("duplicate"))
        }
    }

    func testRowAndColumn() throws {
        let t = try Table.create(
            cols: ["a", "b"],
            types: ["int", "string"],
            rows: [[1, "x"], [2, "y"]]
        )
        let row = try t.row(0)
        XCTAssertEqual(row["a"] as? Int, 1)
        XCTAssertEqual(row["b"] as? String, "x")
        let col = try t.column("b")
        XCTAssertEqual(col[0] as? String, "x")
        XCTAssertEqual(col[1] as? String, "y")
    }

    func testSliceHeadTail() throws {
        let t = try Table.create(
            cols: ["v"],
            types: ["int"],
            rows: [[1], [2], [3], [4], [5]]
        )
        XCTAssertEqual(try t.head(2).rowCount, 2)
        XCTAssertEqual(try t.tail(2).rowCount, 2)
        XCTAssertEqual(try t.slice(1, 4).rowCount, 3)
    }

    func testSelectColsReorders() throws {
        let t = try Table.create(
            cols: ["a", "b", "c"],
            types: ["int", "int", "int"],
            rows: [[1, 2, 3]]
        )
        let sel = try t.selectCols(["c", "a"])
        XCTAssertEqual(sel.cols, ["c", "a"])
    }

    func testIteration() throws {
        let t = try Table.create(
            cols: ["a"],
            types: ["int"],
            rows: [[1], [2]]
        )
        var sum = 0
        for row in t {
            sum += (row["a"] as? Int) ?? 0
        }
        XCTAssertEqual(sum, 3)
    }

    func testToCx() throws {
        let t = try Table.create(
            cols: ["a"],
            types: ["int"],
            rows: [[1]]
        )
        XCTAssertTrue(t.toCx().contains(":table[a:int]"))
    }

    func testToJson() throws {
        let t = try Table.create(
            cols: ["a"],
            types: ["int"],
            rows: [[1], [2]]
        )
        let js = try t.toJson()
        XCTAssertTrue(js.contains("\"a\":1"))
    }

    func testEquals() throws {
        let a = try Table.create(cols: ["a"], types: ["int"], rows: [[1]])
        let b = try Table.create(cols: ["a"], types: ["int"], rows: [[1]])
        XCTAssertTrue(a.equals(b))
    }

    func testFromCxCollectionCells() throws {
        let src = """
        [u :table[name tags]
          alice [admin, user,]
        ]
        """
        let t = try Table.fromCx(src)
        let row = try t.row(0)
        let tags = row["tags"]
        if case let .some(unwrapped) = tags {
            XCTAssertTrue(unwrapped is [Any], "tags should be a List, got: \(String(describing: unwrapped))")
        } else {
            XCTFail("tags missing")
        }
    }
}
