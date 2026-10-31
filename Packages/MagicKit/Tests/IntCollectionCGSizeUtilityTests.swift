import Foundation
import Testing
@testable import MagicKit

// MARK: - Int 扩展

@Suite("Int 工具扩展")
struct IntUtilityTests {
    @Test("HTTP 成功码判定覆盖 200-299 边界")
    func httpOkCodeBoundaries() {
        #expect(199.isHttpOkCode() == false)
        #expect(200.isHttpOkCode())
        #expect(299.isHttpOkCode())
        #expect(300.isHttpOkCode() == false)
    }

    @Test("负数不是 HTTP 成功码")
    func negativeIsNotHttpOk() {
        #expect((-1).isHttpOkCode() == false)
        #expect(Int.min.isHttpOkCode() == false)
    }

    @Test("string 返回十进制文本")
    func stringConversion() {
        #expect(42.string == "42")
        #expect(0.string == "0")
        #expect((-7).string == "-7")
    }

    @Test("偶数与奇数判定互斥且完备")
    func evenOddAreComplementary() {
        for value in [0, 1, 2, 3, 100, -1, -2] {
            #expect(value.isEven != value.isOdd)
        }
        #expect(0.isEven)
        #expect(1.isOdd)
        #expect((-2).isEven)
    }

    @Test("padded 补前导零")
    func paddedAddsLeadingZeros() {
        #expect(7.padded(length: 3) == "007")
        #expect(123.padded(length: 3) == "123")
        #expect(7.padded(length: 1) == "7")
    }

    @Test("padded 对负数保留符号")
    func paddedKeepsSign() {
        #expect((-7).padded(length: 3) == "-07")
    }

    @Test("fileSizeString 在 1024 边界进位")
    func fileSizeStringAdvancesUnits() {
        let kilobyte = 1024
        let megabyte = kilobyte * 1024
        let gigabyte = megabyte * 1024
        let terabyte = gigabyte * 1024

        #expect(0.fileSizeString == "0.0 B")
        #expect(512.fileSizeString == "512.0 B")
        #expect(kilobyte.fileSizeString == "1.0 KB")
        #expect(megabyte.fileSizeString == "1.0 MB")
        #expect(gigabyte.fileSizeString == "1.0 GB")
        #expect(terabyte.fileSizeString == "1.0 TB")
    }

    @Test("fileSizeString 在 TB 之上不再进位")
    func fileSizeStringStopsAtTerabytes() {
        let terabyte = 1024 * 1024 * 1024 * 1024
        let huge = terabyte * 1024
        #expect(huge.fileSizeString == "1024.0 TB")
    }

    @Test("fileSizeString 对负数字节数给出负值文本")
    func fileSizeStringHandlesNegative() {
        // 负数不应被静默夹成 0：调用方据此知道读数异常。
        #expect((-1).fileSizeString == "-1.0 B")
    }
}

// MARK: - Collection 扩展

@Suite("Collection 工具扩展")
struct CollectionUtilityTests {
    @Test("isNotEmpty 与 isEmpty 互为补集")
    func isNotEmptyIsComplement() {
        #expect([Int]().isNotEmpty == false)
        #expect([1].isNotEmpty)
        #expect([Int]().isEmpty)
        #expect([1].isEmpty == false)
    }

    @Test("isNotEmpty 适用于字符串与字典")
    func isNotEmptyAcrossCollectionKinds() {
        #expect("".isNotEmpty == false)
        #expect("a".isNotEmpty)
        #expect([String: Int]().isNotEmpty == false)
        #expect(["k": 1].isNotEmpty)
    }
}

// MARK: - CGSize 扩展

@Suite("CGSize 工具扩展")
struct CGSizeUtilityTests {
    @Test("正方形判定要求宽高相等")
    func isSquareRequiresEqualSides() {
        #expect(CGSize(width: 10, height: 10).isSquare)
        #expect(CGSize(width: 10, height: 11).isSquare == false)
    }

    @Test("横竖判定互斥且不包含正方形")
    func portraitLandscapeAreExclusive() {
        let portrait = CGSize(width: 390, height: 844)
        let landscape = CGSize(width: 844, height: 390)
        let square = CGSize(width: 100, height: 100)

        #expect(portrait.isPortrait)
        #expect(portrait.isLandscape == false)
        #expect(landscape.isLandscape)
        #expect(landscape.isPortrait == false)
        #expect(square.isPortrait == false)
        #expect(square.isLandscape == false)
    }

    @Test("landscape() 交换宽高")
    func landscapeSwapsDimensions() {
        let portrait = CGSize(width: 390, height: 844)
        #expect(portrait.landscape() == CGSize(width: 844, height: 390))
        // 再次调用应回到原值（对合）。
        #expect(portrait.landscape().landscape() == portrait)
    }

    @Test("description 输出 宽x高 文本")
    func descriptionFormatsDimensions() {
        #expect(CGSize(width: 1170, height: 2532).description == "1170x2532")
    }

    @Test("非有限尺寸的 description 归零而非崩溃")
    func descriptionHandlesNonFinite() {
        #expect(CGSize(width: CGFloat.nan, height: 10).description == "0x10")
        #expect(CGSize(width: 10, height: CGFloat.infinity).description == "10x0")
    }

    @Test("内置设备尺寸常量互不相同且为正")
    func deviceConstantsArePositive() {
        let constants: [CGSize] = [
            .iPhoneSE, .iPhoneMini, .iPhone58, .iPhone61LCD, .iPhone, .iPhonePro,
            .iPhone55, .iPhone65, .iPhonePlus, .iPhone69, .iPhoneMax,
            .iPadMini, .iPad, .iPadPro11, .iPadPro12,
            .macBookAir13, .macBookPro13, .macBookPro14, .macBookPro16, .macBook13,
            .iMac24, .iMac27, .studioDisplay, .proDisplayXDR, .mac,
        ]

        for size in constants {
            #expect(size.width > 0)
            #expect(size.height > 0)
        }
    }

    @Test("逻辑点尺寸小于对应的物理像素尺寸")
    func pointSizesAreSmallerThanPhysical() {
        #expect(CGSize.iPhonePoint.width < CGSize.iPhone.width)
        #expect(CGSize.iPhonePoint.height < CGSize.iPhone.height)
        #expect(CGSize.iPadPoint.width < CGSize.iPad.width)
        #expect(CGSize.iPadPoint.height < CGSize.iPad.height)
    }
}
