import UIKit
import SynheartBehavior

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var behavior: SynheartBehavior?
    var currentSessionId: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize SDK
        let config = BehaviorConfig(
            enableInputSignals: true,
            enableAttentionSignals: true,
            enableMotionLite: false
        )
        
        behavior = SynheartBehavior(config: config)
        
        do {
            try behavior?.initialize()
            
            // Set up event handler
            behavior?.setEventHandler { _ in
                // Event handler for debugging if needed
            }
            
            // Start a session
            currentSessionId = try behavior?.startSession()
        } catch {
            // Failed to initialize SDK
        }
        
        // Create window and root view controller
        window = UIWindow(frame: UIScreen.main.bounds)
        let mainVC = MainViewController()
        mainVC.behavior = behavior
        mainVC.sessionId = currentSessionId
        window?.rootViewController = UINavigationController(rootViewController: mainVC)
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Don't auto-end session - let user control it from the UI
        // This prevents session ID mismatches
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Don't auto-start session - let user control it from the UI
        // This prevents session ID mismatches
    }
}

