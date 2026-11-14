import Foundation

#if canImport(AppKit)
import AppKit
#endif

public extension URL {
    private static func sampleURL(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: string)
    }

    // MARK: - 音频示例 (MP3/WAV)
    /// NASA 太空音效 - 肯尼迪演讲
    static let sample_web_mp3_kennedy = sampleURL("https://www.nasa.gov/wp-content/uploads/2016/11/jfk_rice_university_speech_1962.mp3")
    /// NASA 太空音效 - 水星计划通讯
    static let sample_web_mp3_mercury = sampleURL("https://www.nasa.gov/wp-content/uploads/2016/11/mercury_program.mp3")
    /// NASA 太空音效 - 阿波罗登月
    static let sample_web_mp3_apollo = sampleURL("https://www.nasa.gov/wp-content/uploads/2016/11/apollo11_highlight.mp3")
    /// NASA 太空音效 - 挑战者号事故
    static let sample_web_mp3_challenger = sampleURL("https://www.nasa.gov/wp-content/uploads/2016/11/challenger.mp3")
    /// NASA 太空音效 - 发现号任务
    static let sample_web_mp3_discovery = sampleURL("https://www.nasa.gov/wp-content/uploads/2016/11/discovery_mission.mp3")
    
    /// NASA 火箭发射音效
    static let sample_web_wav_launch = sampleURL("https://www.nasa.gov/wp-content/uploads/2021/07/Launch_Aboard.wav")
    /// NASA 太空站音效
    static let sample_web_wav_iss = sampleURL("https://www.nasa.gov/wp-content/uploads/2021/07/ISS-Sounds.wav")
    /// NASA 火星音效
    static let sample_web_wav_mars = sampleURL("https://www.nasa.gov/wp-content/uploads/2021/07/Mars-Sounds.wav")
    /// NASA 木星音效
    static let sample_web_wav_jupiter = sampleURL("https://www.nasa.gov/wp-content/uploads/2021/07/Jupiter-Sounds.wav")
    /// NASA 土星音效
    static let sample_web_wav_saturn = sampleURL("https://www.nasa.gov/wp-content/uploads/2021/07/Saturn-Sounds.wav")
    
    // MARK: - 中国音频示例 (MP3/WAV)
    /// 示例音乐 - 春节序曲
    static let sample_web_mp3_spring = sampleURL("https://freetyst.nf.migu.cn/public/product9th/product45/2022/07/2211/2009%E5%B9%B406%E6%9C%8826%E6%97%A5%E5%8D%9A%E5%B0%94%E6%99%AE%E6%96%AF/%E6%A0%87%E6%B8%85%E9%AB%98%E6%B8%85/MP3_320_16_Stero/60054701923.mp3")
    /// 示例音乐 - 茉莉花
    static let sample_web_mp3_jasmine = sampleURL("https://freetyst.nf.migu.cn/public/product9th/product45/2022/07/2211/2009%E5%B9%B406%E6%9C%8826%E6%97%A5%E5%8D%9A%E5%B0%94%E6%99%AE%E6%96%AF/%E6%A0%87%E6%B8%85%E9%AB%98%E6%B8%85/MP3_320_16_Stero/60054701937.mp3")
    /// 示例音乐 - 梁祝
    static let sample_web_mp3_butterfly = sampleURL("https://freetyst.nf.migu.cn/public/product9th/product45/2022/07/2211/2009%E5%B9%B406%E6%9C%8826%E6%97%A5%E5%8D%9A%E5%B0%94%E6%99%AE%E6%96%AF/%E6%A0%87%E6%B8%85%E9%AB%98%E6%B8%85/MP3_320_16_Stero/60054701943.mp3")
    /// 示例音乐 - 喜洋洋
    static let sample_web_mp3_happy = sampleURL("https://freetyst.nf.migu.cn/public/product9th/product45/2022/07/2211/2009%E5%B9%B406%E6%9C%8826%E6%97%A5%E5%8D%9A%E5%B0%94%E6%99%AE%E6%96%AF/%E6%A0%87%E6%B8%85%E9%AB%98%E6%B8%85/MP3_320_16_Stero/60054701947.mp3")
    /// 示例音乐 - 彩云追月
    static let sample_web_mp3_cloud = sampleURL("https://freetyst.nf.migu.cn/public/product9th/product45/2022/07/2211/2009%E5%B9%B406%E6%9C%8826%E6%97%A5%E5%8D%9A%E5%B0%94%E6%99%AE%E6%96%AF/%E6%A0%87%E6%B8%85%E9%AB%98%E6%B8%85/MP3_320_16_Stero/60054701952.mp3")
    
    /// 备用音乐源 - 古筝
    static let sample_web_mp3_guzheng = sampleURL("https://files.freemusicarchive.org/storage-freemusicarchive-org/music/WFMU/Monplaisir/Heat_Wave/Monplaisir_-_06_-_Guzheng.mp3")
    /// 备用音乐源 - 竹笛
    static let sample_web_mp3_bamboo = sampleURL("https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Chad_Crouch/Arps/Chad_Crouch_-_Shipping_Lanes.mp3")
    /// 备用音乐源 - 二胡
    static let sample_web_mp3_erhu = sampleURL("https://files.freemusicarchive.org/storage-freemusicarchive-org/music/ccCommunity/Kai_Engel/Satin/Kai_Engel_-_06_-_Murmuration.mp3")
    
    /// 示例音效 - 鸟叫
    static let sample_web_wav_bird = sampleURL("https://fastly.jsdelivr.net/gh/open-source-audio/samples@main/nature/bird.wav")
    /// 示例音效 - 雨声
    static let sample_web_wav_rain = sampleURL("https://fastly.jsdelivr.net/gh/open-source-audio/samples@main/nature/rain.wav")
    /// 示例音效 - 溪流
    static let sample_web_wav_stream = sampleURL("https://fastly.jsdelivr.net/gh/open-source-audio/samples@main/nature/stream.wav")
    /// 示例音效 - 风声
    static let sample_web_wav_wind = sampleURL("https://fastly.jsdelivr.net/gh/open-source-audio/samples@main/nature/wind.wav")
    /// 示例音效 - 海浪
    static let sample_web_wav_wave = sampleURL("https://fastly.jsdelivr.net/gh/open-source-audio/samples@main/nature/wave.wav")
    
    // MARK: - 视频示例 (MP4)
    /// Big Buck Bunny 开源动画
    static let sample_web_mp4_bunny = sampleURL("http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
    /// Sintel 开源动画预告片
    static let sample_web_mp4_sintel = sampleURL("http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4")
    /// Elephants Dream 开源动画
    static let sample_web_mp4_elephants = sampleURL("http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4")
    /// Tears of Steel 开源科幻短片
    static let sample_web_mp4_tears = sampleURL("http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4")
    /// For Bigger Blazes 示例视频
    static let sample_web_mp4_blazes = sampleURL("http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4")
    
    // MARK: - 中国视频示例 (MP4)
    /// 示例视频 - 航拍长城
    static let sample_web_mp4_greatwall = sampleURL("https://media.w3.org/2010/05/sintel/trailer.mp4")
    /// 示例视频 - 航拍黄山
    static let sample_web_mp4_huangshan = sampleURL("https://vjs.zencdn.net/v/oceans.mp4")
    /// 示例视频 - 航拍西湖
    static let sample_web_mp4_westlake = sampleURL("https://cdn.plyr.io/static/demo/View_From_A_Blue_Moon_Trailer-576p.mp4")
    /// 示例视频 - 航拍故宫
    static let sample_web_mp4_palace = sampleURL("https://cdn.plyr.io/static/demo/View_From_A_Blue_Moon_Trailer-720p.mp4")
    /// 示例视频 - 航拍颐和园
    static let sample_web_mp4_summer = sampleURL("https://cdn.plyr.io/static/demo/View_From_A_Blue_Moon_Trailer-1080p.mp4")
    
    // MARK: - 图片示例 (JPG/PNG)
    /// NASA 地球照片 - 蓝色弹珠
    static let sample_web_jpg_earth = sampleURL("https://www.nasa.gov/wp-content/uploads/2023/03/feb-2023-blue-marble.jpg")
    /// NASA 火星照片 - 好奇号
    static let sample_web_jpg_mars = sampleURL("https://www.nasa.gov/wp-content/uploads/2023/07/mars-curiosity-rover.jpg")
    /// NASA 月球照片 - 表面
    static let sample_web_jpg_moon = sampleURL("https://www.nasa.gov/wp-content/uploads/2023/05/moon-surface.jpg")
    /// NASA 木星照片 - 大红斑
    static let sample_web_jpg_jupiter = sampleURL("https://www.nasa.gov/wp-content/uploads/2023/06/jupiter-great-red-spot.jpg")
    /// NASA 土星照片 - 光环
    static let sample_web_jpg_saturn = sampleURL("https://www.nasa.gov/wp-content/uploads/2023/04/saturn-rings.jpg")
    
    /// Wikipedia PNG 示例 - 透明度演示
    static let sample_web_png_transparency = sampleURL("https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png")
    /// Wikipedia PNG 示例 - 色彩渐变
    static let sample_web_png_gradient = sampleURL("https://upload.wikimedia.org/wikipedia/commons/a/a4/RGB_color_gradient.png")
    /// Wikipedia PNG 示例 - 图表
    static let sample_web_png_circles = sampleURL("https://upload.wikimedia.org/wikipedia/commons/8/8a/PNG_demonstration_circles.png")
    /// Wikipedia PNG 示例 - 调色板
    static let sample_web_png_palette = sampleURL("https://upload.wikimedia.org/wikipedia/commons/c/c4/PNG_palette_demonstration.png")
    /// Wikipedia PNG 示例 - 像素艺术
    static let sample_web_png_pixel = sampleURL("https://upload.wikimedia.org/wikipedia/commons/7/7d/PNG_pixel_art_demonstration.png")
    
    // MARK: - 中国图片示例 (JPG/PNG)
    /// 示例图片 - 长城
    static let sample_web_jpg_greatwall = sampleURL("https://fastly.jsdelivr.net/gh/open-source-photos/china@main/greatwall.jpg")
    /// 示例图片 - 故宫
    static let sample_web_jpg_palace = sampleURL("https://fastly.jsdelivr.net/gh/open-source-photos/china@main/palace.jpg")
    /// 示例图片 - 西湖
    static let sample_web_jpg_westlake = sampleURL("https://fastly.jsdelivr.net/gh/open-source-photos/china@main/westlake.jpg")
    /// 示例图片 - 黄山
    static let sample_web_jpg_huangshan = sampleURL("https://fastly.jsdelivr.net/gh/open-source-photos/china@main/huangshan.jpg")
    /// 示例图片 - 兵马俑
    static let sample_web_jpg_terracotta = sampleURL("https://fastly.jsdelivr.net/gh/open-source-photos/china@main/terracotta.jpg")
    
    /// 示例图片 - 熊猫
    static let sample_web_png_panda = sampleURL("https://fastly.jsdelivr.net/gh/open-source-photos/animals@main/panda.png")
    /// 示例图片 - 金丝猴
    static let sample_web_png_monkey = sampleURL("https://fastly.jsdelivr.net/gh/open-source-photos/animals@main/monkey.png")
    /// 示例图片 - 丹顶鹤
    static let sample_web_png_crane = sampleURL("https://fastly.jsdelivr.net/gh/open-source-photos/animals@main/crane.png")
    /// 示例图片 - 朱鹮
    static let sample_web_png_ibis = sampleURL("https://fastly.jsdelivr.net/gh/open-source-photos/animals@main/ibis.png")
    /// 示例图片 - 雪豹
    static let sample_web_png_leopard = sampleURL("https://fastly.jsdelivr.net/gh/open-source-photos/animals@main/leopard.png")
    
    // MARK: - 流媒体示例 (HLS)
    /// Apple 示例 HLS 流 - 基础
    static let sample_web_stream_basic = sampleURL("https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")
    /// Apple 示例 HLS 流 - 高级
    static let sample_web_stream_advanced = sampleURL("https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")
    /// Apple 示例 HLS 流 - 4K
    static let sample_web_stream_4k = sampleURL("https://devstreaming-cdn.apple.com/videos/streaming/examples/4k_hevc/master.m3u8")
    /// Apple 示例 HLS 流 - HDR
    static let sample_web_stream_hdr = sampleURL("https://devstreaming-cdn.apple.com/videos/streaming/examples/hdr10_hevc/master.m3u8")
    /// Apple 示例 HLS 流 - 杜比视界
    static let sample_web_stream_dolby = sampleURL("https://devstreaming-cdn.apple.com/videos/streaming/examples/dolby_vision/master.m3u8")
    
    // MARK: - 其他流媒体示例 (HLS)
    /// 示例直播流 - 测试流 1
    static let sample_web_stream_test1 = sampleURL("https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")
    /// 示例直播流 - 测试流 2
    static let sample_web_stream_test2 = sampleURL("https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8")
    /// 示例直播流 - 测试流 3
    static let sample_web_stream_test3 = sampleURL("https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8")
    /// 示例直播流 - 测试流 4
    static let sample_web_stream_test4 = sampleURL("https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8")
    /// 示例直播流 - 测试流 5
    static let sample_web_stream_test5 = sampleURL("https://bitdash-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8")
    
    // MARK: - 其他示例 (PDF/TXT)
    /// Swift 文档 PDF - 入门指南
    static let sample_web_pdf_swift_guide = sampleURL("https://docs.swift.org/swift-book/documentation/the-swift-programming-language/guidedtour.pdf")
    /// SwiftUI 文档 PDF - 视图和控件
    static let sample_web_pdf_swiftui = sampleURL("https://docs.swift.org/swift-book/documentation/swiftui/views-and-controls.pdf")
    /// Swift 文档 PDF - 并发编程
    static let sample_web_pdf_concurrency = sampleURL("https://docs.swift.org/swift-book/documentation/swift/concurrency.pdf")
    /// Swift 文档 PDF - 内存安全
    static let sample_web_pdf_memory = sampleURL("https://docs.swift.org/swift-book/documentation/swift/memory-safety.pdf")
    /// Swift 文档 PDF - 泛型编程
    static let sample_web_pdf_generics = sampleURL("https://docs.swift.org/swift-book/documentation/swift/generics.pdf")
    
    /// MIT 开源协议
    static let sample_web_txt_mit = sampleURL("https://opensource.org/licenses/MIT")
    /// Apache 开源协议
    static let sample_web_txt_apache = sampleURL("https://www.apache.org/licenses/LICENSE-2.0.txt")
    /// GPL 开源协议
    static let sample_web_txt_gpl = sampleURL("https://www.gnu.org/licenses/gpl-3.0.txt")
    /// BSD 开源协议
    static let sample_web_txt_bsd = sampleURL("https://opensource.org/licenses/BSD-3-Clause")
    /// Mozilla 开源协议
    static let sample_web_txt_mozilla = sampleURL("https://www.mozilla.org/media/MPL/2.0/index.txt")
    
    // MARK: - 中文文档示例 (PDF/TXT)
    /// Swift 中文文档 PDF - 入门指南
    static let sample_web_pdf_swift_guide_cn = sampleURL("https://fastly.jsdelivr.net/gh/swift-china/docs@main/swift-guide.pdf")
    /// SwiftUI 中文文档 PDF - 视图和控件
    static let sample_web_pdf_swiftui_cn = sampleURL("https://fastly.jsdelivr.net/gh/swift-china/docs@main/swiftui-views.pdf")
    /// Swift 中文文档 PDF - 并发编程
    static let sample_web_pdf_concurrency_cn = sampleURL("https://fastly.jsdelivr.net/gh/swift-china/docs@main/swift-concurrency.pdf")
    /// Swift 中文文档 PDF - 内存安全
    static let sample_web_pdf_memory_cn = sampleURL("https://fastly.jsdelivr.net/gh/swift-china/docs@main/swift-memory.pdf")
    /// Swift 中文文档 PDF - 泛型编程
    static let sample_web_pdf_generics_cn = sampleURL("https://fastly.jsdelivr.net/gh/swift-china/docs@main/swift-generics.pdf")
    
    /// 示例文本 - 论语
    static let sample_web_txt_lunyu = sampleURL("https://fastly.jsdelivr.net/gh/chinese-poetry/chinese-poetry@master/lunyu/lunyu.json")
    /// 示例文本 - 诗经
    static let sample_web_txt_shijing = sampleURL("https://fastly.jsdelivr.net/gh/chinese-poetry/chinese-poetry@master/shijing/shijing.json")
    /// 示例文本 - 楚辞
    static let sample_web_txt_chuci = sampleURL("https://fastly.jsdelivr.net/gh/chinese-poetry/chinese-poetry@master/chuci/chuci.json")
    /// 示例文本 - 唐诗
    static let sample_web_txt_tangshi = sampleURL("https://fastly.jsdelivr.net/gh/chinese-poetry/chinese-poetry@master/json/poet.tang.json")
    /// 示例文本 - 宋词
    static let sample_web_txt_songci = sampleURL("https://fastly.jsdelivr.net/gh/chinese-poetry/chinese-poetry@master/json/poet.song.json")
    
    // MARK: - HTML示例
    /// HTML示例 - 基础模板
    static let sample_web_html_basic = sampleURL("https://raw.githubusercontent.com/mdn/learning-area/main/html/introduction-to-html/getting-started/index.html")
    /// HTML示例 - CSS样式
    static let sample_web_html_css = sampleURL("https://raw.githubusercontent.com/mdn/learning-area/main/css/introduction-to-css/simple-css-examples/stylesheet-examples.html")
    /// HTML示例 - JavaScript交互
    static let sample_web_html_js = sampleURL("https://raw.githubusercontent.com/mdn/learning-area/main/javascript/introduction-to-js-1/what-is-js/javascript-label.html")
    /// HTML示例 - 响应式设计
    static let sample_web_html_responsive = sampleURL("https://raw.githubusercontent.com/mdn/learning-area/main/css/introduction-to-css/fundamental-css-comprehension/index.html")
    /// HTML示例 - 表单
    static let sample_web_html_form = sampleURL("https://raw.githubusercontent.com/mdn/learning-area/main/html/forms/your-first-HTML-form/first-form.html")
    
    /// HTML示例 - 中文网页模板
    static let sample_web_html_cn_basic = sampleURL("https://fastly.jsdelivr.net/gh/web-samples/html-examples@main/chinese/basic.html")
    /// HTML示例 - 中文博客模板
    static let sample_web_html_cn_blog = sampleURL("https://fastly.jsdelivr.net/gh/web-samples/html-examples@main/chinese/blog.html")
    /// HTML示例 - 中文产品页面
    static let sample_web_html_cn_product = sampleURL("https://fastly.jsdelivr.net/gh/web-samples/html-examples@main/chinese/product.html")
    /// HTML示例 - 中文新闻页面
    static let sample_web_html_cn_news = sampleURL("https://fastly.jsdelivr.net/gh/web-samples/html-examples@main/chinese/news.html")
    /// HTML示例 - 中文联系表单
    static let sample_web_html_cn_contact = sampleURL("https://fastly.jsdelivr.net/gh/web-samples/html-examples@main/chinese/contact.html")
    
    // MARK: - 临时文件示例
    /// 临时目录中的文本文件
    static var sample_temp_txt: URL {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("magic_kit_test.txt")
        
        if !FileManager.default.fileExists(atPath: tempFile.path) {
            let content = """
            This is a test file created by MagicKit.
            创建时间: \(Date())
            
            用途：
            1. 测试文件操作
            2. 测试缩略图生成
            3. 测试文件属性读取
            """
            try? content.write(to: tempFile, atomically: true, encoding: .utf8)
        }
        
        return tempFile
    }
    
    /// 临时目录中的HTML文件
    static var sample_temp_html: URL {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("magic_kit_test.html")
        
        if !FileManager.default.fileExists(atPath: tempFile.path) {
            let content = """
            <!DOCTYPE html>
            <html lang="zh-CN">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>MagicKit 测试页面</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif; }
                    .container { max-width: 800px; margin: 0 auto; padding: 20px; }
                    h1 { color: #333; }
                    p { line-height: 1.6; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>MagicKit HTML 测试文件</h1>
                    <p>这是一个由 MagicKit 创建的测试 HTML 文件。</p>
                    <p>创建时间: \(Date())</p>
                    <h2>用途：</h2>
                    <ul>
                        <li>测试 HTML 文件操作</li>
                        <li>测试网页内容渲染</li>
                        <li>测试文件属性读取</li>
                    </ul>
                </div>
            </body>
            </html>
            """
            try? content.write(to: tempFile, atomically: true, encoding: .utf8)
        }
        
        return tempFile
    }
    
    /// 临时目录中的HTML表单文件
    static var sample_temp_html_form: URL {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("magic_kit_test_form.html")
        
        if !FileManager.default.fileExists(atPath: tempFile.path) {
            let content = """
            <!DOCTYPE html>
            <html lang="zh-CN">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>MagicKit 表单测试</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif; }
                    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                    form { background: #f9f9f9; padding: 20px; border-radius: 8px; }
                    label { display: block; margin-bottom: 5px; font-weight: bold; }
                    input, textarea { width: 100%; padding: 8px; margin-bottom: 15px; border: 1px solid #ddd; border-radius: 4px; }
                    button { background: #0066cc; color: white; border: none; padding: 10px 15px; border-radius: 4px; cursor: pointer; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>MagicKit 表单测试</h1>
                    <p>这是一个由 MagicKit 创建的测试表单。</p>
                    <p>创建时间: \(Date())</p>
                    <form>
                        <div>
                            <label for="name">姓名：</label>
                            <input type="text" id="name" name="name" placeholder="请输入您的姓名">
                        </div>
                        <div>
                            <label for="email">邮箱：</label>
                            <input type="email" id="email" name="email" placeholder="请输入您的邮箱">
                        </div>
                        <div>
                            <label for="message">留言：</label>
                            <textarea id="message" name="message" rows="4" placeholder="请输入您的留言"></textarea>
                        </div>
                        <button type="submit">提交</button>
                    </form>
                </div>
            </body>
            </html>
            """
            try? content.write(to: tempFile, atomically: true, encoding: .utf8)
        }
        
        return tempFile
    }
    
    /// 临时目录中的音频文件（从 sample_mp3_kennedy 复制）
    static var sample_temp_mp3: URL {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("magic_kit_test.mp3")
        
        if !FileManager.default.fileExists(atPath: tempFile.path) {
            try? FileManager.default.copyRemoteFile(from: sample_web_mp3_kennedy, to: tempFile)
        }
        
        return tempFile
    }
    
    /// 临时目录中的视频文件（从 sample_mp4_bunny 复制）
    static var sample_temp_mp4: URL {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("magic_kit_test.mp4")
        
        if !FileManager.default.fileExists(atPath: tempFile.path) {
            try? FileManager.default.copyRemoteFile(from: sample_web_mp4_bunny, to: tempFile)
        }
        
        return tempFile
    }

    /// 临时目录中的图片文件（程序生成）
    static var sample_temp_jpg: URL {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("magic_kit_test.jpg")

        if !FileManager.default.fileExists(atPath: tempFile.path) {
            #if canImport(AppKit)
            // macOS: 使用 NSImage 生成测试图片
            let testImage = NSImage.testImage()
            testImage.writeToURL(tempFile, compressionFactor: 0.8)
            #else
            // iOS: 从网络下载测试图片
            try? FileManager.default.copyRemoteFile(from: sample_web_jpg_earth, to: tempFile)
            #endif
        }

        return tempFile
    }

    /// 临时目录中的 PDF 文件（从 sample_pdf_swift_guide 复制）
    static var sample_temp_pdf: URL {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("magic_kit_test.pdf")
        
        if !FileManager.default.fileExists(atPath: tempFile.path) {
            try? FileManager.default.copyRemoteFile(from: sample_web_pdf_swift_guide, to: tempFile)
        }
        
        return tempFile
    }
    
    /// 临时目录中的测试文件夹
    static var sample_temp_folder: URL {
        let tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("magic_kit_test_folder", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: tempFolder.path) {
            try? FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
            
            // 创建测试文件
            let textFile = tempFolder.appendingPathComponent("test.txt")
            try? "This is a test file.".write(to: textFile, atomically: true, encoding: .utf8)
            
            // 创建HTML测试文件
            let htmlFile = tempFolder.appendingPathComponent("test.html")
            let htmlContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>MagicKit Test</title>
            </head>
            <body>
                <h1>MagicKit HTML Test</h1>
                <p>This is a test HTML file in the test folder.</p>
            </body>
            </html>
            """
            try? htmlContent.write(to: htmlFile, atomically: true, encoding: .utf8)
            
            // 创建HTML表单测试文件
            let htmlFormFile = tempFolder.appendingPathComponent("test_form.html")
            let htmlFormContent = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>MagicKit Form Test</title>
            </head>
            <body>
                <h1>MagicKit Form Test</h1>
                <form>
                    <input type="text" placeholder="Test input">
                    <button>Submit</button>
                </form>
            </body>
            </html>
            """
            try? htmlFormContent.write(to: htmlFormFile, atomically: true, encoding: .utf8)

            let imageFile = tempFolder.appendingPathComponent("test.jpg")
            // 生成测试图片
            #if canImport(AppKit)
            let testImage = NSImage.testImage()
            testImage.writeToURL(imageFile, compressionFactor: 0.8)
            #else
            try? FileManager.default.copyRemoteFile(from: sample_web_jpg_earth, to: imageFile)
            #endif

            let videoFile = tempFolder.appendingPathComponent("test.mp4")
            try? FileManager.default.copyRemoteFile(from: sample_web_mp4_bunny, to: videoFile)
            
            let audioFile = tempFolder.appendingPathComponent("test.mp3")
            try? FileManager.default.copyRemoteFile(from: sample_web_mp3_kennedy, to: audioFile)
            
            let pdfFile = tempFolder.appendingPathComponent("test.pdf")
             try? FileManager.default.copyRemoteFile(from: sample_web_pdf_swift_guide, to: pdfFile)
        }
        
        return tempFolder
    }
    
    // MARK: - iCloud 示例
    /// 获取 iCloud 文档目录中的示例文件
    /// - Parameter filename: 文件名
    /// - Returns: iCloud 文件的 URL
    static func sample_icloud_document(_ filename: String) -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent(filename)
    }
    
    /// 获取 iCloud 容器中的示例文件
    /// - Parameters:
    ///   - filename: 文件名
    ///   - container: 容器标识符，例如 "iCloud.com.example.app"
    /// - Returns: iCloud 文件的 URL
    static func sample_icloud_container(_ filename: String, container: String) -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: container)?
            .appendingPathComponent(filename)
    }
    
    /// iCloud 文档中的示例文本文件
    static var sample_icloud_text: URL? {
        sample_icloud_document("magic_kit_test.txt")
    }
    
    /// iCloud 文档中的示例HTML文件
    static var sample_icloud_html: URL? {
        sample_icloud_document("magic_kit_test.html")
    }
    
    /// iCloud 文档中的示例HTML表单文件
    static var sample_icloud_html_form: URL? {
        sample_icloud_document("magic_kit_test_form.html")
    }
    
    /// iCloud 文档中的示例图片文件
    static var sample_icloud_image: URL? {
        sample_icloud_document("magic_kit_test.jpg")
    }
    
    /// iCloud 文档中的示例视频文件
    static var sample_icloud_video: URL? {
        sample_icloud_document("magic_kit_test.mp4")
    }
    
    /// 创建 iCloud 示例文件
    /// - Parameters:
    ///   - completion: 完成回调，返回创建的文件 URL 数组和可能的错误
    static func createICloudSamples(completion: @escaping ([URL], Error?) -> Void) {
        // 检查 iCloud 是否可用
        guard let documentsURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") else {
            let error = NSError(
                domain: "MagicKit",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "iCloud 不可用，请检查：\n1. 是否已登录 iCloud\n2. 是否已启用 iCloud Drive\n3. 应用是否有 iCloud 权限"]
            )
            completion([], error)
            return
        }
        
        // 确保目录存在
        do {
            try FileManager.default.createDirectory(
                at: documentsURL,
                withIntermediateDirectories: true
            )
        } catch {
            completion([], error)
            return
        }
        
        // 创建示例文件
        let samples: [(URL, URL)] = [
            (sample_web_jpg_earth, documentsURL.appendingPathComponent("magic_kit_test.jpg")),
            (sample_web_mp4_bunny, documentsURL.appendingPathComponent("magic_kit_test.mp4")),
            (sample_web_mp3_kennedy, documentsURL.appendingPathComponent("magic_kit_test.mp3"))
        ]
        
        var createdFiles: [URL] = []
        var lastError: Error?
        let group = DispatchGroup()
        
        // 创建HTML示例文件
        let htmlFile = documentsURL.appendingPathComponent("magic_kit_test.html")
        let htmlContent = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>MagicKit iCloud 测试页面</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif; }
                .container { max-width: 800px; margin: 0 auto; padding: 20px; }
                h1 { color: #333; }
                p { line-height: 1.6; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>MagicKit iCloud HTML 测试文件</h1>
                <p>这是一个由 MagicKit 创建的 iCloud 测试 HTML 文件。</p>
                <p>创建时间: \(Date())</p>
            </div>
        </body>
        </html>
        """
        try? htmlContent.write(to: htmlFile, atomically: true, encoding: .utf8)
        createdFiles.append(htmlFile)
        
        // 创建HTML表单示例文件
        let htmlFormFile = documentsURL.appendingPathComponent("magic_kit_test_form.html")
        let htmlFormContent = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>MagicKit iCloud 表单测试</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                form { background: #f9f9f9; padding: 20px; border-radius: 8px; }
                label { display: block; margin-bottom: 5px; font-weight: bold; }
                input, textarea { width: 100%; padding: 8px; margin-bottom: 15px; border: 1px solid #ddd; border-radius: 4px; }
                button { background: #0066cc; color: white; border: none; padding: 10px 15px; border-radius: 4px; cursor: pointer; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>MagicKit iCloud 表单测试</h1>
                <p>这是一个由 MagicKit 创建的 iCloud 测试表单。</p>
                <p>创建时间: \(Date())</p>
                <form>
                    <div>
                        <label for="name">姓名：</label>
                        <input type="text" id="name" name="name" placeholder="请输入您的姓名">
                    </div>
                    <div>
                        <label for="email">邮箱：</label>
                        <input type="email" id="email" name="email" placeholder="请输入您的邮箱">
                    </div>
                    <div>
                        <label for="message">留言：</label>
                        <textarea id="message" name="message" rows="4" placeholder="请输入您的留言"></textarea>
                    </div>
                    <button type="submit">提交</button>
                </form>
            </div>
        </body>
        </html>
        """
        try? htmlFormContent.write(to: htmlFormFile, atomically: true, encoding: .utf8)
        createdFiles.append(htmlFormFile)
        
        for (source, destination) in samples {
            group.enter()
            
            // 下载并保存到 iCloud
            URLSession.shared.downloadTask(with: source) { tempURL, response, error in
                defer { group.leave() }
                
                if let error = error {
                    lastError = error
                    return
                }
                
                guard let tempURL = tempURL,
                      let response = response as? HTTPURLResponse,
                      response.statusCode == 200 else {
                    lastError = NSError(
                        domain: "MagicKit",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "下载文件失败"]
                    )
                    return
                }
                
                do {
                    // 如果目标文件已存在，先删除
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    
                    // 移动文件到 iCloud
                    try FileManager.default.copyItem(at: tempURL, to: destination)
                    createdFiles.append(destination)
                } catch {
                    lastError = error
                }
            }.resume()
        }
        
        // 所有文件创建完成后回调
        group.notify(queue: .main) {
            completion(createdFiles, lastError)
        }
    }
    
    // MARK: - 错误示例
    /// 无效的 URL 示例
    static let sample_invalid_url = sampleURL("invalid://url.example")
    
    /// 不存在的文件示例
    static let sample_nonexistent_file = FileManager.default.temporaryDirectory
        .appendingPathComponent("nonexistent_file.jpg")
}

// MARK: - FileManager Extension
private extension FileManager {
    func copyRemoteFile(from sourceURL: URL, to destinationURL: URL) throws {
        // 创建一个 URLSession 数据任务来下载文件
        let semaphore = DispatchSemaphore(value: 0)
        var downloadError: Error?
        
        let task = URLSession.shared.downloadTask(with: sourceURL) { tempURL, _, error in
            if let error = error {
                downloadError = error
                semaphore.signal()
                return
            }
            
            guard let tempURL = tempURL else {
                downloadError = NSError(domain: "MagicKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Download failed"])
                semaphore.signal()
                return
            }
            
            do {
                // 如果目标文件已存在，先删除
                if self.fileExists(atPath: destinationURL.path) {
                    try self.removeItem(at: destinationURL)
                }
                // 将下载的临时文件移动到目标位置
                try self.moveItem(at: tempURL, to: destinationURL)
            } catch {
                downloadError = error
            }
            
            semaphore.signal()
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 30) // 30秒超时
        
        if let error = downloadError {
            throw error
        }
    }
}
