import Foundation
import Testing
@testable import MagicKit

// MARK: - 字符串 JSON 键路径读取

/// JSON 键路径读取是「点号分隔的嵌套路径」，且对数组有「取首项」的兜底语义。
///
/// 这条链路被仓库导入、商店回执解析等流程依赖，读错会静默返回 nil，
/// 因此必须锁定：类型不匹配返回 nil、缺键返回 nil、数组首项可被读取。
@Suite("String JSON 键路径读取")
struct StringJSONPathTests {
    private let json = """
    {
      "user": {
        "id": 123,
        "name": "Ada",
        "profile": { "city": "London" },
        "tags": ["a", "b"]
      },
      "items": [
        { "sku": "A1", "qty": 2 },
        { "sku": "B1", "qty": 9 }
      ],
      "count": 7,
      "ratio": 0.5,
      "flag": true,
      "nothing": null
    }
    """

    @Test("读取嵌套整数")
    func readsNestedInt() {
        #expect(json.getIntFromJSON(for: "user.id") == 123)
    }

    @Test("读取嵌套字符串")
    func readsNestedString() {
        #expect(json.getStringFromJSON(for: "user.name") == "Ada")
    }

    @Test("读取三层嵌套")
    func readsThreeLevelPath() {
        #expect(json.getStringFromJSON(for: "user.profile.city") == "London")
    }

    @Test("类型不匹配时返回 nil")
    func returnsNilOnTypeMismatch() {
        // `user.name` 是字符串，不能当整数读。
        #expect(json.getIntFromJSON(for: "user.name") == nil)
        // `user.id` 是整数，不能当字符串读。
        #expect(json.getStringFromJSON(for: "user.id") == nil)
    }

    @Test("缺失的键返回 nil")
    func returnsNilForMissingKey() {
        #expect(json.getValueFromJSON(for: "user.missing") == nil)
        #expect(json.getValueFromJSON(for: "missing.deeply.nested") == nil)
        #expect(json.getValueFromJSON(for: "") == nil)
    }

    @Test("对象数组可读取首项的字段")
    func readsFirstItemOfObjectArray() {
        #expect(json.getStringFromJSON(for: "items.sku") == "A1")
        #expect(json.getIntFromJSON(for: "items.qty") == 2)
    }

    @Test("标量数组不可按字典下标读取")
    func scalarArrayDoesNotResolveByKey() {
        // `user.tags` 是字符串数组，没有 `tags.foo` 这个键。
        #expect(json.getValueFromJSON(for: "user.tags.name") == nil)
    }

    @Test("布尔值不会被读成整数")
    func booleanIsNotInt() {
        #expect(json.getIntFromJSON(for: "flag") == nil)
        #expect(json.getValueFromJSON(for: "flag") as? Bool == true)
    }

    @Test("整数 0 不会被误判成布尔值")
    func zeroIsNotBoolean() {
        // `NSNumber(value: 0)` 同样能桥接成 `Bool`，
        // 因此「排除布尔」的实现必须用 CoreFoundation 类型标识，
        // 否则整数 0 会被误伤成 nil。
        let payload = #"{ "zero": 0, "negative": -3, "one": 1 }"#
        #expect(payload.getIntFromJSON(for: "zero") == 0)
        #expect(payload.getIntFromJSON(for: "negative") == -3)
        #expect(payload.getIntFromJSON(for: "one") == 1)
    }

    @Test("浮点数不会被读成整数")
    func doubleIsNotInt() {
        #expect(json.getIntFromJSON(for: "ratio") == nil)
        #expect(json.getValueFromJSON(for: "ratio") as? Double == 0.5)
    }

    @Test("null 值返回 nil")
    func nullValueIsNil() {
        #expect(json.getValueFromJSON(for: "nothing") == nil)
    }

    @Test("非法 JSON 返回 nil 而不抛出")
    func invalidJSONReturnsNil() {
        #expect("not json at all".getValueFromJSON(for: "a") == nil)
        #expect("".getValueFromJSON(for: "a") == nil)
    }

    @Test("顶层数组不会被当作字典解析")
    func topLevelArrayIsNotSupported() {
        #expect("[1,2,3]".getValueFromJSON(for: "0") == nil)
    }
}

// MARK: - 字符串基础编码

@Suite("String 基础编码")
struct StringEncodingTests {
    @Test("toData 返回 UTF-8 字节")
    func toDataUsesUTF8() {
        #expect("Hi".toData() == Data("Hi".utf8))
        #expect("中文".toData() == Data("中文".utf8))
    }

    @Test("toBase64 编码可往返")
    func toBase64RoundTrips() {
        let original = "Hello World"
        let encoded = original.toBase64()
        #expect(encoded == "SGVsbG8gV29ybGQ=")
        #expect(String(data: Data(base64Encoded: encoded) ?? Data(), encoding: .utf8) == original)
    }

    @Test("toBase64 对空串返回空串")
    func toBase64OfEmptyString() {
        #expect("".toBase64() == "")
    }
}

// MARK: - 上下文 Emoji

@Suite("String 上下文 Emoji")
struct StringContextEmojiTests {
    @Test("已知关键词返回对应 emoji")
    func knownKeywordMapsToEmoji() {
        #expect("error".generateContextEmoji() == "❌")
        #expect("Loading data".generateContextEmoji() == "💾")
        #expect("Ready".generateContextEmoji() == "✅")
    }

    @Test("匹配忽略大小写")
    func matchingIsCaseInsensitive() {
        #expect("ERROR".generateContextEmoji() == "❌")
        #expect("Error".generateContextEmoji() == "❌")
    }

    @Test("中文关键词同样命中")
    func chineseKeywordMatches() {
        #expect("加载".generateContextEmoji() == "💾")
        #expect("错误".generateContextEmoji() == "❌")
    }

    @Test("未知关键词回退为通用 emoji")
    func unknownKeywordFallsBack() {
        #expect("zzz-完全没见过的词".generateContextEmoji() == "📝")
    }

    @Test("withContextEmoji 把 emoji 前置到原文前")
    func withContextEmojiPrefixesOriginal() {
        #expect("error".withContextEmoji == "❌ error")
    }
}
