import Foundation

extension String {
    static var htmlExample: String {
        """
        <h1>示例文档</h1>
        <p>这是一个包含多种元素的 HTML 示例：</p>
        <h2>图片示例</h2>
        <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=" alt="示例图片">
        <h2>格式化文本</h2>
        <p>这是一段包含<strong>粗体</strong>和<em>斜体</em>的文本。</p>
        <h2>列表示例</h2>
        <ul>
            <li>无序列表项 1</li>
            <li>无序列表项 2</li>
        </ul>
        <h2>链接示例</h2>
        <p>这是一个<a href="https://www.example.com">示例链接</a></p>
        """
    }
}