//
//  AppDelegate.swift
//  MediaCacheSwift
//
//  Created by zhangjianyun on 2022/4/12.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let root = storyboard.instantiateViewController(withIdentifier: "RootViewController")
        window?.rootViewController = UINavigationController(rootViewController: root)
        window?.makeKeyAndVisible()
        return true
    }
}
