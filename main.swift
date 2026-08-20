import UIKit

@objc(KeyChecker)
public class KeyChecker: NSObject {
    
    // Đường link API Cloudflare Worker của bạn đã được cập nhật thành công
    static let apiURL = "https://uchihav4.hieuduongreallife.workers.dev"
    
    @objc public static func loadPlugin() {
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
                                      message: "Vui lòng nhập Key để kích hoạt:", 
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Nhập Key tại đây..."
        }
        
        let submitAction = UIAlertAction(title: "Kích Hoạt", style: .default) { _ in
            guard let keyInput = alert.textFields?.first?.text, !keyInput.isEmpty else {
                showKeyDialog()
                return
            }
            verifyKeyWithServer(key: keyInput)
        }
        
        alert.addAction(submitAction)
        topVC.present(alert, animated: true)
    }
    
    static func verifyKeyWithServer(key: String) {
        guard let url = URL(string: apiURL) else { return }
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "UNKNOWN_ID"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyParams: [String: Any] = ["key": key, "udid": deviceID]
        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParams)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    showAlertAndRetry(message: "Lỗi kết nối Server!")
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String, status == "success" {
                    UserDefaults.standard.set("YES", forKey: "AppActivated")
                    UserDefaults.standard.synchronize()
                    showSuccessAlert()
                } else {
                    showAlertAndRetry(message: "Key không chính xác hoặc đã hết hạn!")
                }
            }
        }.resume()
    }
    
    static func showAlertAndRetry(message: String) {
        guard let topVC = getTopViewController() else { return }
        let alert = UIAlertController(title: "Thất Bại", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Thử lại", style: .default) { _ in showKeyDialog() })
        topVC.present(alert, animated: true)
    }
    
    static func showSuccessAlert() {
        guard let topVC = getTopViewController() else { return }
        let alert = UIAlertController(title: "Thành Công", message: "Kích hoạt bản quyền thành công!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Sử dụng ứng dụng", style: .cancel))
        topVC.present(alert, animated: true)
    }
    
    static func getTopViewController() -> UIViewController? {
        var topVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = topVC?.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}

// Chèn tự động khi ứng dụng iOS vừa khởi chạy
@_cdecl("initPlugin")
public func initPlugin() {
    KeyChecker.loadPlugin()
}
