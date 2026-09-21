import Foundation

/// The one place that knows whether this binary carries the iPhone Duo path.
/// Every Duo symbol lives under `#if DUO_SDK`; every use is also guarded by
/// `if #available(iOS 27.1, *)`. Neither alone is enough (docs/PLAN.md section 4.2).
enum DuoSupport {
    static let compiledWithDuoSDK: Bool = {
        #if DUO_SDK
        return true
        #else
        return false
        #endif
    }()

    static var duoAPIsAvailable: Bool {
        #if DUO_SDK
        if #available(iOS 27.1, *) {
            return true
        }
        #endif
        return false
    }

    static var buildDescription: String {
        switch (compiledWithDuoSDK, duoAPIsAvailable) {
        case (false, _):
            return "Baseline build (compiled without the iPhone Duo SDK)"
        case (true, false):
            return "Duo-capable build, running on an OS without the Duo APIs"
        case (true, true):
            return "Duo-capable build, Duo APIs available"
        }
    }
}
