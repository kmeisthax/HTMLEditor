import SwiftUI

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(OldschoolAppDelegate.self) var appDelegate;
    
    @StateObject var shoebox: Shoebox = Shoebox.fromState(state: ShoeboxState.restoreFromDisk());
    
    var body: some Scene {
        WindowGroup {
            ShoeboxSelector(shoebox: shoebox)
        }
    }
}

class OldschoolAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role);
        
        sceneConfig.delegateClass = OldschoolSceneDelegate.self
        
        return sceneConfig
    }
}

class OldschoolSceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject {
    var scene: UIWindowScene?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        self.scene = windowScene
    }
}
