import Foundation

struct Constants {
    static let apiBaseURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String else {
            fatalError("API_BASE_URL not set in Info.plist")
        }
        return url
    }()

    static let apiKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String else {
            fatalError("API_KEY not set in Info.plist")
        }
        return key
    }()

    struct Storage {
        static let accessTokenKey = "rmh_access_token"
        static let refreshTokenKey = "rmh_refresh_token"
        static let userKey = "rmh_user"
        static let deviceIdKey = "rmh_device_id"
    }

    struct UI {
        static let cornerRadius: CGFloat = 12
        static let buttonHeight: CGFloat = 56
        static let spacing: CGFloat = 16
    }

    struct Currency {
        static let code = "UGX"
        static let symbol = "UGX"
    }
}
