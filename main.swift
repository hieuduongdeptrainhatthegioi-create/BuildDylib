import UIKit
import WebKit

@objc(KeyChecker)
public class KeyChecker: NSObject, WKScriptMessageHandler {
    
    static let shared = KeyChecker()
    static let apiURL = "https://uchihav4.hieuduongreallife.workers.dev"
    var webView: WKWebView?
    var containerView: UIView?
    
    @objc public static func loadPlugin() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let isActivated = UserDefaults.standard.string(forKey: "AppActivated")
            if isActivated != "YES" {
                shared.showWebPopup()
            }
        }
    }
    
    func showWebPopup() {
        guard let topVC = KeyChecker.getTopViewController() else { return }
        
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // Đăng ký nhận tin nhắn từ JavaScript ("keyHandler")
        contentController.add(self, name: "keyHandler")
        config.userContentController = contentController
        
        let bounds = topVC.view.bounds
        containerView = UIView(frame: bounds)
        containerView?.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        webView = WKWebView(frame: bounds, configuration: config)
        webView?.isOpaque = false
        webView?.backgroundColor = .clear
        webView?.scrollView.isScrollEnabled = false
        
        if let container = containerView, let web = webView {
            container.addSubview(web)
            topVC.view.addSubview(container)
            
            // Mã HTML/JS giao diện Popup
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>
                    body { font-family: -apple-system, sans-serif; background: transparent; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
                    .card { background: #fff; border-radius: 16px; padding: 24px; width: 80%; max-width: 300px; text-align: center; box-shadow: 0 10px 25px rgba(0,0,0,0.3); }
                    h3 { margin: 0 0 8px 0; color: #1c1c1e; font-size: 18px; }
                    p { color: #8e8e93; font-size: 13px; margin-bottom: 16px; }
                    input { width: 100%; padding: 12px; border: 1px solid #e5e5ea; border-radius: 10px; font-size: 15px; box-sizing: border-box; text-align: center; outline: none; margin-bottom: 12px; }
                    button { width: 100%; padding: 12px; background: #007aff; color: #fff; border: none; border-radius: 10px; font-size: 16px; font-weight: bold; cursor: pointer; }
                    #status { margin-top: 10px; font-size: 13px; color: #ff3b30; }
                </style>
            </head>
            <body>
                <div class="card">
                    <h3>XÁC THỰC BẢN QUYỀN</h3>
                    <p>Nhập Key để kích hoạt ứng dụng</p>
                    <input type="text" id="keyInput" placeholder="Nhập Key tại đây...">
                    <button onclick="submitKey()">Kích Hoạt</button>
                    <div id="status"></div>
                </div>
                <script>
                    function submitKey() {
                        var key = document.getElementById("keyInput").value;
                        if(!key) { document.getElementById("status").innerText = "Vui lòng nhập Key!"; return; }
                        document.getElementById("status").style.color = "#8e8e93";
                        document.getElementById("status").innerText = "Đang kiểm tra...";
                        window.webkit.messageHandlers.keyHandler.postMessage({ action: "verifyKey", key: key });
                    }
                    function onResult(success, msg) {
                        document.getElementById("status").style.color = success ? "#34c759" : "#ff3b30";
                        document.getElementById("status").innerText = msg;
                    }
                </script>
            </body>
            </html>
            """
            web.loadHTMLString(html, baseURL: nil)
        }
    }
    
    // Nhận dữ liệu gửi từ JavaScript
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "keyHandler", let body = message.body as? [String: Any], let key = body["key"] as? String {
            verifyKeyWithServer(key: key)
        }
    }
    
    // Kiểm tra Key trên Server
    func verifyKeyWithServer(key: String) {
        guard let url = URL(string: KeyChecker.apiURL) else { return }
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN_ID"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyParams: [String: Any] = ["key": key, "udid": deviceID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParams)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    self.sendJSResponse(success: false, message: "Lỗi kết nối Server!")
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String, status == "success" {
                    
                    UserDefaults.standard.set("YES", forKey: "AppActivated")
                    UserDefaults.standard.synchronize()
                    
                    self.sendJSResponse(success: true, message: "Kích hoạt thành công!")
                    
                    // Tự động ẩn Popup sau 1.5 giây
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.containerView?.removeFromSuperview()
                    }
                } else {
                    self.sendJSResponse(success: false, message: "Key không chính xác!")
                }
            }
        }.resume()
    }
    
    // Trả kết quả ngược lại cho giao diện JavaScript
    func sendJSResponse(success: Bool, message: String) {
        let jsScript = "onResult(\(success ? "true" : "false"), '\(message)');"
        webView?.evaluateJavaScript(jsScript, completionHandler: nil)
    }
    
    static func getTopViewController() -> UIViewController? {
        var topVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = topVC?.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}

// Chèn tự động khi Dylib nạp vào ứng dụng
@_cdecl("initPlugin")
public func initPlugin() {
    KeyChecker.loadPlugin()
}
