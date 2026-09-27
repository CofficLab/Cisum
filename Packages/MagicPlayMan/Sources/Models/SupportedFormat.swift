import Foundation
import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

/// 支持的媒体格式
public struct SupportedFormat {
    /// 格式名称
    public let name: String
    /// 文件扩展名
    public let extensions: [String]
    /// MIME 类型
    public let mimeTypes: [String]
    /// 示例资源
    public let samples: [Sample]

    /// 示例资源
    public struct Sample {
        public let name: String
        public let asset: MagicAsset

        public init(name: String, asset: MagicAsset) {
            self.name = name
            self.asset = asset
        }
    }

    /// 所有支持的格式
    public static let allFormats: [SupportedFormat] = [
        // MP3
        SupportedFormat(
            name: "MP",
            extensions: ["mp3"],
            mimeTypes: ["audio/mpeg"],
            samples: [
                // NASA 音效
                Sample(
                    name: "肯尼迪演讲",
                    asset: MagicAsset(
                        url: .sample_web_mp3_kennedy,
                        metadata: MagicAsset.Metadata(
                            title: "Rice University Speech",
                            artist: "JFK",
                            album: "NASA Archives"
                        )
                    )
                ),
                Sample(
                    name: "水星计划通讯",
                    asset: MagicAsset(
                        url: .sample_web_mp3_mercury,
                        metadata: MagicAsset.Metadata(
                            title: "Mercury Program",
                            artist: "NASA",
                            album: "NASA Archives"
                        )
                    )
                ),
                Sample(
                    name: "阿波罗登月",
                    asset: MagicAsset(
                        url: .sample_web_mp3_apollo,
                        metadata: MagicAsset.Metadata(
                            title: "Apollo 11 Highlight",
                            artist: "NASA",
                            album: "NASA Archives"
                        )
                    )
                ),
                // 中国传统音乐
                Sample(
                    name: "春节序曲",
                    asset: MagicAsset(
                        url: .sample_web_mp3_spring,
                        metadata: MagicAsset.Metadata(
                            title: "春节序曲",
                            artist: "李焕之",
                            album: "中国传统音乐"
                        )
                    )
                ),
                Sample(
                    name: "茉莉花",
                    asset: MagicAsset(
                        url: .sample_web_mp3_jasmine,
                        metadata: MagicAsset.Metadata(
                            title: "茉莉花",
                            artist: "民乐合奏",
                            album: "中国传统音乐"
                        )
                    )
                ),
                Sample(
                    name: "梁祝",
                    asset: MagicAsset(
                        url: .sample_web_mp3_butterfly,
                        metadata: MagicAsset.Metadata(
                            title: "梁祝",
                            artist: "何占豪",
                            album: "中国传统音乐"
                        )
                    )
                ),
                // 中国音乐
                Sample(
                    name: "古筝",
                    asset: MagicAsset(
                        url: .sample_web_mp3_guzheng,
                        metadata: MagicAsset.Metadata(
                            title: "古筝",
                            artist: "Monplaisir",
                            album: "中国传统音乐"
                        )
                    )
                ),
                Sample(
                    name: "竹笛",
                    asset: MagicAsset(
                        url: .sample_web_mp3_bamboo,
                        metadata: MagicAsset.Metadata(
                            title: "竹笛",
                            artist: "Chad Crouch",
                            album: "中国传统音乐"
                        )
                    )
                ),
                Sample(
                    name: "二胡",
                    asset: MagicAsset(
                        url: .sample_web_mp3_erhu,
                        metadata: MagicAsset.Metadata(
                            title: "二胡",
                            artist: "Kai Engel",
                            album: "中国传统音乐"
                        )
                    )
                ),
            ]
        ),

        // WAV
        SupportedFormat(
            name: "WA",
            extensions: ["wav"],
            mimeTypes: ["audio/wav", "audio/x-wav"],
            samples: [
                // NASA 音效
                Sample(
                    name: "火箭发射",
                    asset: MagicAsset(
                        url: .sample_web_wav_launch,
                        metadata: MagicAsset.Metadata(
                            title: "Launch Aboard",
                            artist: "NASA",
                            album: "Space Sounds"
                        )
                    )
                ),
                Sample(
                    name: "国际空间站",
                    asset: MagicAsset(
                        url: .sample_web_wav_iss,
                        metadata: MagicAsset.Metadata(
                            title: "ISS Sounds",
                            artist: "NASA",
                            album: "Space Sounds"
                        )
                    )
                ),
                Sample(
                    name: "火星声音",
                    asset: MagicAsset(
                        url: .sample_web_wav_mars,
                        metadata: MagicAsset.Metadata(
                            title: "Mars Sounds",
                            artist: "NASA",
                            album: "Space Sounds"
                        )
                    )
                ),
                // 自然音效
                Sample(
                    name: "鸟叫",
                    asset: MagicAsset(
                        url: .sample_web_wav_bird,
                        metadata: MagicAsset.Metadata(
                            title: "鸟叫",
                            artist: "大自然",
                            album: "自然音效"
                        )
                    )
                ),
                Sample(
                    name: "雨声",
                    asset: MagicAsset(
                        url: .sample_web_wav_rain,
                        metadata: MagicAsset.Metadata(
                            title: "雨声",
                            artist: "大自然",
                            album: "自然音效"
                        )
                    )
                ),
                Sample(
                    name: "溪流",
                    asset: MagicAsset(
                        url: .sample_web_wav_stream,
                        metadata: MagicAsset.Metadata(
                            title: "溪流",
                            artist: "大自然",
                            album: "自然音效"
                        )
                    )
                ),
            ]
        ),

        // MP4
        SupportedFormat(
            name: "MP4",
            extensions: ["mp4", "m4v"],
            mimeTypes: ["video/mp4"],
            samples: [
                // 开源动画
                Sample(
                    name: "Big Buck Bunny",
                    asset: MagicAsset(
                        url: .sample_web_mp4_bunny,
                        metadata: MagicAsset.Metadata(
                            title: "Big Buck Bunny",
                            artist: "Blender Foundation",
                            album: "开源动画"
                        )
                    )
                ),
                Sample(
                    name: "Tears of Steel",
                    asset: MagicAsset(
                        url: .sample_web_mp4_tears,
                        metadata: MagicAsset.Metadata(
                            title: "Tears of Steel",
                            artist: "Blender Foundation",
                            album: "开源动画"
                        )
                    )
                ),
                // 中国风光
                Sample(
                    name: "航拍长城",
                    asset: MagicAsset(
                        url: .sample_web_mp4_greatwall,
                        metadata: MagicAsset.Metadata(
                            title: "航拍长城",
                            artist: "中国风光",
                            album: "航拍系列"
                        )
                    )
                ),
                Sample(
                    name: "航拍西湖",
                    asset: MagicAsset(
                        url: .sample_web_mp4_westlake,
                        metadata: MagicAsset.Metadata(
                            title: "航拍西湖",
                            artist: "中国风光",
                            album: "航拍系列"
                        )
                    )
                ),
                // 开源视频
                Sample(
                    name: "Sintel",
                    asset: MagicAsset(
                        url: .sample_web_mp4_sintel,
                        metadata: MagicAsset.Metadata(
                            title: "Sintel",
                            artist: "Blender Foundation",
                            album: "开源动画"
                        )
                    )
                ),
                Sample(
                    name: "Elephants Dream",
                    asset: MagicAsset(
                        url: .sample_web_mp4_elephants,
                        metadata: MagicAsset.Metadata(
                            title: "Elephants Dream",
                            artist: "Blender Foundation",
                            album: "开源动画"
                        )
                    )
                ),
            ]
        ),

        // HLS
        SupportedFormat(
            name: "HLS",
            extensions: ["m3u8"],
            mimeTypes: ["application/x-mpegURL"],
            samples: [
                // Apple 示例流
                Sample(
                    name: "基础流",
                    asset: MagicAsset(
                        url: .sample_web_stream_basic,
                        metadata: MagicAsset.Metadata(
                            title: "Basic Stream",
                            artist: "Apple",
                            album: "HLS Samples"
                        )
                    )
                ),
                Sample(
                    name: "高级流",
                    asset: MagicAsset(
                        url: .sample_web_stream_advanced,
                        metadata: MagicAsset.Metadata(
                            title: "Advanced Stream",
                            artist: "Apple",
                            album: "HLS Samples"
                        )
                    )
                ),
                Sample(
                    name: "4K 流",
                    asset: MagicAsset(
                        url: .sample_web_stream_4k,
                        metadata: MagicAsset.Metadata(
                            title: "4K Stream",
                            artist: "Apple",
                            album: "HLS Samples"
                        )
                    )
                ),
                Sample(
                    name: "测试流 1",
                    asset: MagicAsset(
                        url: .sample_web_stream_test1,
                        metadata: MagicAsset.Metadata(
                            title: "测试流 1",
                            artist: "Mux",
                            album: "测试直播"
                        )
                    )
                ),
                Sample(
                    name: "测试流 2",
                    asset: MagicAsset(
                        url: .sample_web_stream_test2,
                        metadata: MagicAsset.Metadata(
                            title: "测试流 2",
                            artist: "Akamai",
                            album: "测试直播"
                        )
                    )
                ),
                Sample(
                    name: "测试流 3",
                    asset: MagicAsset(
                        url: .sample_web_stream_test3,
                        metadata: MagicAsset.Metadata(
                            title: "测试流 3",
                            artist: "Unified Streaming",
                            album: "测试直播"
                        )
                    )
                ),
            ]
        ),
    ]

    /// 获取所有音频示例
    public static var audioSamples: [Sample] {
        allFormats
//            .filter { true }
            .flatMap(\.samples)
    }

    /// 获取所有视频示例
    public static var videoSamples: [Sample] {
        allFormats
//            .filter { true }
            .flatMap(\.samples)
    }

    /// 获取所有示例
    public static var allSamples: [Sample] {
        allFormats.flatMap(\.samples)
    }
}

#Preview("With Logs") {
    MagicPlayMan.getPreviewView()
}
