import XCTest
@testable import MagicKit

final class CoAuthoredByTest: XCTestCase {
    func testCoAuthorsParsing() throws {
        // 测试用例1: 包含Co-Authored-By的提交消息
        let commitWithCoAuthor = MagicGitCommit(
            id: "abc123",
            hash: "abc123",
            author: "John Doe",
            email: "john@example.com",
            date: Date(),
            message: "Add new feature",
            body: """
            Add new feature implementation

            This commit adds a new feature that allows users to...

            Co-Authored-By: Jane Smith <jane@example.com>
            Co-Authored-By: Bob Johnson <bob@example.com>
            """
        )

        XCTAssertEqual(commitWithCoAuthor.coAuthors, ["Jane Smith", "Bob Johnson"])
        XCTAssertEqual(commitWithCoAuthor.allAuthors, "John Doe + Jane Smith + Bob Johnson")
    }

    func testNoCoAuthors() throws {
        // 测试用例2: 不包含Co-Authored-By的提交消息
        let commitWithoutCoAuthor = MagicGitCommit(
            id: "def456",
            hash: "def456",
            author: "Alice",
            email: "alice@example.com",
            date: Date(),
            message: "Fix bug",
            body: "Fixed a critical bug in the system"
        )

        XCTAssertEqual(commitWithoutCoAuthor.coAuthors, [])
        XCTAssertEqual(commitWithoutCoAuthor.allAuthors, "Alice")
    }

    func testCoAuthorWithoutEmail() throws {
        // 测试用例3: Co-Authored-By没有邮箱格式
        let commitWithSimpleCoAuthor = MagicGitCommit(
            id: "ghi789",
            hash: "ghi789",
            author: "Tom",
            email: "tom@example.com",
            date: Date(),
            message: "Update documentation",
            body: """
            Update documentation

            Co-Authored-By: Jerry
            """
        )

        XCTAssertEqual(commitWithSimpleCoAuthor.coAuthors, ["Jerry"])
        XCTAssertEqual(commitWithSimpleCoAuthor.allAuthors, "Tom + Jerry")
    }

    func testGitCommitDetailCoAuthors() throws {
        // 测试MagicGitCommitDetail的Co-Authored-By功能
        let detail = MagicGitCommitDetail(
            id: "xyz123",
            author: "Mike",
            email: "mike@example.com",
            date: Date(),
            message: "Refactor code",
            body: """
            Refactor code for better performance

            Co-Authored-By: Sarah Wilson <sarah@example.com>
            """,
            files: [],
            diff: ""
        )

        XCTAssertEqual(detail.coAuthors, ["Sarah Wilson"])
        XCTAssertEqual(detail.allAuthors, "Mike + Sarah Wilson")
    }

    func testGitCommitFromDetail() throws {
        // 测试从MagicGitCommitDetail创建MagicGitCommit
        let detail = MagicGitCommitDetail(
            id: "test123",
            author: "Test Author",
            email: "test@example.com",
            date: Date(),
            message: "Test message",
            body: "Test body\n\nCo-Authored-By: Co Author <co@example.com>",
            files: [],
            diff: ""
        )

        let commit = MagicGitCommit(from: detail)

        XCTAssertEqual(commit.id, detail.id)
        XCTAssertEqual(commit.author, detail.author)
        XCTAssertEqual(commit.email, detail.email)
        XCTAssertEqual(commit.message, detail.message)
        XCTAssertEqual(commit.body, detail.body)
        XCTAssertEqual(commit.coAuthors, ["Co Author"])
        XCTAssertEqual(commit.allAuthors, "Test Author + Co Author")
    }
}
