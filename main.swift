import UIKit

// Khai báo class để khởi chạy mã ngầm khi dylib được nạp vào ứng dụng
class KeyChecker: NSObject {
    
    // Đổi link này thành link API máy chủ Node.js / Render của bạn
    static let apiURL = "https://uchihav4.hieuduongreallife.workers.dev"
    
    @objc static func loadPlugin() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let isActivated = UserDefaults.standard.string(forKey: "AppActivated")
            if isActivated != "YES" {
                showKeyDialog()
            }
        }
    }
    
    static func showKeyDialog() {
        guard let topVC = getTopViewController() else { return }
        
        let alert = UIAlertController(title: "XÁC THỰC BẢN QUYỀN", 
                                      message: "Vui lòng nhập Key để kích hoạt ứng dụng:", 
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Nhập Key của bạn..."
            textField.isSecureTextEntry = false
        }
        
        let submitAction = UIAlertAction(title: "Kích Hoạt", style: .default) { _ in
            guard let keyInput = alert.textFields?.first?.text, !keyInput.isEmpty else {
                showKeyDialog()
                return
            }
            verifyKeyWithServer(key: keyInput)
        }
        
        alert.addAction(submitAction)
        topVC.present(alert, animated: true, completion: nil)
    }
    
    static func verifyKeyWithServer(key: String) {
        guard let url = URL(string: apiURL) else { return }
        
        // Lấy Device ID (UDID) của thiết bị
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN_ID"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyParams: [String: Any] = [
            "key": key,
            "udid": deviceID
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParams)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    showAlertAndRetry(message: "Không thể kết nối đến Server!")
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String, status == "success" {
                    
                    // Lưu trạng thái đã kích hoạt vào thiết bị
                    UserDefaults.standard.set("YES", forKey: "AppActivated")
                    UserDefaults.standard.synchronize()
                    
                    showSuccessAlert()
                } else {
                    showAlertAndRetry(message: "Key không hợp lệ hoặc đã hết hạn!")
                }
            }
        }
        task.resume()
    }
    
    static func showAlertAndRetry(message: String) {
        guard let topVC = getTopViewController() else { return }
        let alert = UIAlertController(title: "Lỗi", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Thử lại", style: .default) { _ in showKeyDialog() })
        topVC.present(alert, animated: true)
    }
    
    static func showSuccessAlert() {
        guard let topVC = getTopViewController() else { return }
        let alert = UIAlertController(title: "Thành Công", message: "Kích hoạt bản quyền thành công!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Bắt đầu dùng", style: .cancel))
        topVC.present(alert, animated: true)
    }
    
    // Hàm phụ hỗ trợ tìm Controller đang hiển thị trên màn hình
    static func getTopViewController() -> UIViewController? {
        var topVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = topVC?.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}

// Constructor nạp ứng dụng ngầm
@_cdecl("initPlugin")
public func initPlugin() {
    KeyChecker.loadPlugin()
}
