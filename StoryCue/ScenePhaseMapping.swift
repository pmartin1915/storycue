import SwiftUI

/// Maps SwiftUI scene-phase transitions to the SessionEvents the reducer already
/// understands (S1 tests cover the pair a home press delivers: resign-active then
/// did-enter-background).
enum ScenePhaseMapping {
    static func event(from old: ScenePhase, to new: ScenePhase) -> SessionEvent? {
        if old == .active, new == .inactive { return .sceneWillResignActive }
        if new == .background { return .sceneDidEnterBackground }
        if new == .active, old == .inactive || old == .background { return .sceneDidBecomeActive }
        return nil
    }
}
