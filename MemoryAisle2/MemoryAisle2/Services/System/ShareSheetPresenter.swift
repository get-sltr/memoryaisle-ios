import UIKit

enum ShareSheetPresenter {
    static func present(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        let scenes = UIApplication.shared.connectedScenes
        guard let windowScene = scenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? scenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
              let rootVC = keyWindow.rootViewController else {
            return
        }

        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        top.present(activityVC, animated: true)
    }
}

