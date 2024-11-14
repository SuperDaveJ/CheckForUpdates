//
//  CheckAppUpdateStatus.swift
//
//  Created by David Johnson on 10/12/17.
//

import Foundation
import UIKit

// Enum used to keep keys for the UserDefault Dictionary
enum ChechAppVersionUserDefaultKeys: String {
  case skippedVersion = "skippedVersion"
}

class CheckAppVersionStatus {
  
  private var url: URL!
  private var defaultSession: URLSession = {
    let defaultSession = URLSession(configuration: .default)
    return defaultSession
  }()
  
  private var dataTask: URLSessionDataTask?
  private var appStoreVersion = "1.0"
  
  private var currentVersion: String = {
    let currentVersion: String = (Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String) ?? "1.0"
    return currentVersion
  }()
  
  private var lastSkippedVersion: String = {
    let lastSkippedVersion = UserDefaults.standard.string(forKey: ChechAppVersionUserDefaultKeys.skippedVersion.rawValue)
    return lastSkippedVersion ?? "1.0"
  }()
  
  private lazy var userDefaults: UserDefaults = {
    return UserDefaults.standard
  }()
  
  private var bundleIdentifier: String = {
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else { fatalError("Bundle Identifier was nil") }
    return bundleIdentifier
  }()
  
  init() {
    url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleIdentifier)")
  }
  
  func checkCurrentAppStoreVersionAndAlertIfBehind() {
  
    searchForCurrentAppStoreVersion(using: url) { result in
      
      if let result = result {
        self.appStoreVersion = result
        if self.appStoreVersion != self.currentVersion && self.lastSkippedVersion != self.appStoreVersion {
          self.prepareAndpresentAlertVC(with: self.appStoreVersion)
        }
      } else {
        // Handle occurence of when result is nil
      }
    }
    
  }
  
  // Call to present the alertVC
  private func prepareAndpresentAlertVC(with appStoreVersion: String) {
    let alertActions = createAlertActions()
    let alertController = createAppStoreUpdateAlert(using: alertActions)
    if let topController = UIApplication.topViewController() {
      topController.present(alertController, animated: true, completion: nil)
    }
  }
  
  // Create alert actions here to add to the app store update alert
  private func createAlertActions() -> [UIAlertAction] {
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
      self.userDefaults.set(self.appStoreVersion, forKey: ChechAppVersionUserDefaultKeys.skippedVersion.rawValue)
    }
    let remindMeLaterAction = UIAlertAction(title: "Remind Me Later", style: .default, handler: nil)
    let updateAction = UIAlertAction(title: "Update", style: .default) { action in
      let appStoreURL = URL(string: "https://itunes.apple.com/us/app/paycom/id1207929487?ls=1&mt=8")
      
      if let appStoreURL = appStoreURL {
        if UIApplication.shared.canOpenURL(appStoreURL) {
          UIApplication.shared.openURL(appStoreURL)
        }
      }
    }
    
    return [cancelAction, remindMeLaterAction, updateAction]
  }
  
  // Create app store alertVC using an array of UIAlertActions
  private func createAppStoreUpdateAlert(using actions: [UIAlertAction]) -> UIAlertController {
    let alertVC = UIAlertController(title: "Update to New Version",
                                    message: "Version \(self.appStoreVersion) is Available",
                                    preferredStyle: .alert)
    actions.forEach { alertVC.addAction($0) }
    return alertVC
  }
  
  // Networking call to the app store
  private func searchForCurrentAppStoreVersion(using url: URL, completion: @escaping (String?) -> Void) {
    // If any current dataTask (aka network calls) are happening then cancel before creating another
    dataTask?.cancel()
    
    dataTask = defaultSession.dataTask(with: url, completionHandler: { (data, response, error) in
      if let error = error {
        print(error.localizedDescription)
        completion(nil)
      } else if let data = data, let response = response as? HTTPURLResponse, response.statusCode == 200 {
        let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        if let json = json {
          let result: String? = self.parse(json)
          completion(result)
        }
      }
    })
    dataTask?.resume()
  }
  
  // Parse json from the networking call
  private func parse(_ json: [String: Any]?) -> String? {
    guard let response = json,
          let results = response["results"],
          let resultsArray = results as? [Any],
          let resultsDict = resultsArray.first as? [String: Any] else { return nil }
    
    let appStoreVersion = resultsDict["version"] as? String
    
    return appStoreVersion
  }
  
}


// MARK: - UIApplication Extension
extension UIApplication {
  class func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
    if let navigationController = controller as? UINavigationController {
      return topViewController(controller: navigationController.visibleViewController)
    }
    if let tabController = controller as? UITabBarController {
      if let selected = tabController.selectedViewController {
        return topViewController(controller: selected)
      }
    }
    if let presented = controller?.presentedViewController {
      return topViewController(controller: presented)
    }
    return controller
  }
}
