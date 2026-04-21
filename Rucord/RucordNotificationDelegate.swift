import UserNotifications

let alertedKeyPrefix = "alerted_14days_"
let readingAlertedKeyPrefix = "alerted_reading_"
let wofAlertedKeyPrefix = "alerted_wof_"
let registrationAlertedKeyPrefix = "alerted_registration_"

final class RucordNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RucordNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        markAlertedTokens(from: notification.request.content.userInfo)
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        markAlertedTokens(from: response.notification.request.content.userInfo)
        completionHandler()
    }

    private func markAlertedTokens(from userInfo: [AnyHashable: Any]) {
        if let token = userInfo["rucToken"] as? String {
            UserDefaults.standard.set(true, forKey: alertedKeyPrefix + token)
        }
        if let token = userInfo["readingToken"] as? String {
            UserDefaults.standard.set(true, forKey: readingAlertedKeyPrefix + token)
        }
        if let token = userInfo["wofToken"] as? String {
            UserDefaults.standard.set(true, forKey: wofAlertedKeyPrefix + token)
        }
        if let token = userInfo["registrationToken"] as? String {
            UserDefaults.standard.set(true, forKey: registrationAlertedKeyPrefix + token)
        }
    }
}
