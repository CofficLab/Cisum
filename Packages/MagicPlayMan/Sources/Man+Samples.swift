import Foundation
import CisumUIComponents
import LumiUI
import MagicKit
import SwiftUI

public extension MagicPlayMan {
    var samples: [URL] { [
        // MP3 - NASA 音效
        .sample_web_mp3_kennedy, // 肯尼迪演讲
        .sample_web_mp3_mercury, // 水星计划通讯
        .sample_web_mp3_apollo, // 阿波罗登月

        // MP3 - 中国传统音乐
        .sample_web_mp3_spring, // 春节序曲
        .sample_web_mp3_jasmine, // 茉莉花
        .sample_web_mp3_butterfly, // 梁祝

        // MP3 - 中国音乐
        .sample_web_mp3_guzheng, // 古筝
        .sample_web_mp3_bamboo, // 竹笛
        .sample_web_mp3_erhu, // 二胡

        // WAV - NASA 音效
        .sample_web_wav_launch, // 火箭发射
        .sample_web_wav_iss, // 国际空间站
        .sample_web_wav_mars, // 火星声音

        // WAV - 自然音效
        .sample_web_wav_bird, // 鸟叫
        .sample_web_wav_rain, // 雨声
        .sample_web_wav_stream, // 溪流

        // MP4 视频
        .sample_web_mp4_bunny, // Big Buck Bunny
        .sample_web_mp4_tears, // Tears of Steel
        .sample_web_mp4_greatwall, // 航拍长城
        .sample_web_mp4_westlake, // 航拍西湖
        .sample_web_mp4_sintel, // Sintel
        .sample_web_mp4_elephants, // Elephants Dream

        // HLS 流媒体
        .sample_web_stream_basic, // 基础流
        .sample_web_stream_advanced, // 高级流
        .sample_web_stream_4k, // 4K 流
        .sample_web_stream_test1, // 测试流 1
        .sample_web_stream_test2, // 测试流 2
        .sample_web_stream_test3, // 测试流 3
    ]
    }
}

// MARK: - Preview

#Preview("MagicPlayMan") {
    MagicPlayMan.getPreviewView()
}
