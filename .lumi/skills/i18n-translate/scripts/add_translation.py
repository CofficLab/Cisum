#!/usr/bin/env python3
"""为指定 key 添加翻译"""

import json
import sys

# 简体到繁体转换映射（简化版，常见词汇）
ZH_S_TO_T_MAP = {
    "拷贝": "拷貝",
    "复制": "複製",
    "连接": "連接",
    "设置": "設定",
    "文档": "文檔",
    "目录": "目錄",
    "系统": "系統",
    "打开": "打開",
    "保存": "儲存",
    "删除": "刪除",
    "编辑": "編輯",
    "视图": "檢視",
    "窗口": "視窗",
    "帮助": "協助",
    "选项": "選項",
    "偏好": "偏好設定",
    "插件": "外掛",
    "网络": "網絡",
    "加载": "載入",
    "下载": "下載",
    "上传": "上傳",
    "服务器": "伺服器",
    "客户端": "客戶端",
    "数据库": "資料庫",
    "信息": "資訊",
    "确认": "確認",
    "取消": "取消",
    "关闭": "關閉",
    "退出": "退出",
    "重启": "重新啟動",
    "后台": "後台",
    "前台": "前景",
    "进程": "進程",
    "线程": "線程",
    "内存": "記憶體",
    "磁盘": "磁盤",
    "显示": "顯示",
    "隐藏": "隱藏",
    "搜索": "搜尋",
    "替换": "替換",
    "查找": "尋找",
    "项目": "專案",
    "文件": "檔案",
    "文件夹": "資料夾",
    "计算机": "電腦",
    "软件": "軟體",
    "硬件": "硬體",
    "程序": "程式",
    "应用": "應用",
    "界面": "介面",
    "用户": "用戶",
    "账户": "賬戶",
    "登录": "登錄",
    "注销": "註銷",
    "注册": "註冊",
    "在线": "線上",
    "离线": "離線",
    "状态": "狀態",
    "错误": "錯誤",
    "警告": "警告",
    "提示": "提示",
    "通知": "通知",
    "消息": "消息",
    "内容": "內容",
    "标题": "標題",
    "主题": "主題",
    "样式": "樣式",
    "格式": "格式",
    "类型": "類型",
    "大小": "大小",
    "长度": "長度",
    "宽度": "寬度",
    "高度": "高度",
    "位置": "位置",
    "路径": "路徑",
    "名称": "名稱",
    "版本": "版本",
    "更新": "更新",
    "升级": "升級",
    "安装": "安裝",
    "卸载": "卸載",
    "配置": "配置",
    "测试": "測試",
    "调试": "調試",
    "运行": "運行",
    "停止": "停止",
    "暂停": "暫停",
    "继续": "繼續",
    "开始": "開始",
    "结束": "結束",
    "完成": "完成",
    "失败": "失敗",
    "成功": "成功",
    "加载趋势": "載入趨勢",
    "负载": "負載",
    "使用率": "使用率",
    "导航": "導航",
    "入口": "入口",
    "终端": "終端",
    "控制台": "控制台",
    "命令行": "命令列",
    "脚本": "腳本",
    "代码": "代碼",
    "数据": "數據",
    "流量": "流量",
    "带宽": "頻寬",
    "延迟": "延遲",
    "响应": "響應",
    "请求": "請求",
    "响应时间": "響應時間",
    "超时": "超時",
    "重试": "重試",
    "跳过": "跳過",
    "忽略": "忽略",
    "记住": "記住",
    "忘记": "忘記",
    "清除": "清除",
    "刷新": "重新整理",
    "同步": "同步",
    "异步": "異步",
    "阻塞": "阻塞",
    "非阻塞": "非阻塞",
    "并发": "並發",
    "并行": "並行",
    "串行": "串行",
    "序列化": "序列化",
    "反序列化": "反序列化",
    "编码": "編碼",
    "解码": "解碼",
    "加密": "加密",
    "解密": "解密",
    "压缩": "壓縮",
    "解压": "解壓",
    "备份": "備份",
    "恢复": "恢復",
    "导入": "導入",
    "导出": "導出",
    "打印": "打印",
    "预览": "預覽",
    "全屏": "全螢幕",
    "最小化": "最小化",
    "最大化": "最大化",
    "还原": "還原",
    "移动": "移動",
    "复制": "複製",
    "粘贴": "貼上",
    "剪切": "剪下",
    "撤销": "還原",
    "重做": "重做",
    "全选": "全選",
    "反选": "反選",
    "排序": "排序",
    "筛选": "篩選",
    "分组": "分組",
    "合并": "合併",
    "拆分": "拆分",
    "锁定": "鎖定",
    "解锁": "解鎖",
    "保护": "保護",
    "共享": "共享",
    "发布": "發布",
    "订阅": "訂閱",
    "收藏": "收藏",
    "历史": "歷史",
    "记录": "記錄",
    "日志": "日誌",
    "缓存": "快取",
    "Cookie": "Cookie",
    "Session": "Session",
    "Token": "Token",
    "API": "API",
    "URL": "URL",
    "HTTP": "HTTP",
    "HTTPS": "HTTPS",
    "FTP": "FTP",
    "SSH": "SSH",
    "SSL": "SSL",
    "TLS": "TLS",
    "TCP": "TCP",
    "UDP": "UDP",
    "IP": "IP",
    "DNS": "DNS",
    "DHCP": "DHCP",
    "NAT": "NAT",
    "VPN": "VPN",
    "Proxy": "Proxy",
    "Firewall": "防火牆",
    "Router": "路由器",
    "Switch": "交換器",
    "Hub": "集線器",
    "Modem": "數據機",
    "Wireless": "無線",
    "Wired": "有線",
    "Bluetooth": "藍牙",
    "Wi-Fi": "Wi-Fi",
    "Hotspot": "熱點",
    "Tethering": "網絡共享",
    "Data": "數據",
    "Signal": "信號",
    "Strength": "強度",
    "Quality": "品質",
    "Network": "網絡",
    "Connection": "連接",
    "Disconnect": "斷開",
    "Reconnect": "重新連接",
    "Available": "可用",
    "Unavailable": "不可用",
    "Enabled": "已啟用",
    "Disabled": "已停用",
    "Active": "啟用中",
    "Inactive": "未啟用",
    "Online": "線上",
    "Offline": "離線",
    "Busy": "忙碌",
    "Idle": "閒置",
    "Ready": "就緒",
    "Loading": "載入中",
    "Saving": "儲存中",
    "Processing": "處理中",
    "Completed": "已完成",
    "Failed": "失敗",
    "Cancelled": "已取消",
    "Pending": "等待中",
    "Scheduled": "已排程",
    "Running": "執行中",
    "Stopped": "已停止",
    "Paused": "已暫停",
}

def simplify_to_traditional(text: str) -> str:
    """简体中文转繁体中文（简单版）"""
    # 简单替换已知词汇，未知词汇保持原样
    for s, t in ZH_S_TO_T_MAP.items():
        text = text.replace(s, t)
    return text

def add_translation(file_path: str, key: str, zh_hans: str, zh_hk: str = None):
    """为指定 key 添加翻译"""
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    if key not in data["strings"]:
        print(f"错误: key '{key}' 不存在")
        return False

    if zh_hk is None:
        zh_hk = simplify_to_traditional(zh_hans)

    data["strings"][key]["localizations"] = {
        "zh-Hans": {
            "stringUnit": {
                "state": "translated",
                "value": zh_hans
            }
        },
        "zh-HK": {
            "stringUnit": {
                "state": "translated",
                "value": zh_hk
            }
        }
    }

    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"已更新翻译:")
    print(f"  Key: {key}")
    print(f"  zh-Hans: {zh_hans}")
    print(f"  zh-HK: {zh_hk}")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("用法: python3 add_translation.py <file> <key> <zh-Hans> [zh-HK]")
        sys.exit(1)

    file_path = sys.argv[1]
    key = sys.argv[2]
    zh_hans = sys.argv[3]
    zh_hk = sys.argv[4] if len(sys.argv) > 4 else None

    add_translation(file_path, key, zh_hans, zh_hk)
