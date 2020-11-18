//
//  ViewController.swift
//  Spot Check
//
//  Created by Brian Team on 10/28/20.
//

import UIKit

class ViewController: UIViewController {
    var httpRequest: URLSessionDataTask?
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var spotCheckSettingsButton: UIButton!
    @IBOutlet weak var disabledPopupButton: UIButton!
    
    // MARK: - Overrides
    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//
//        NotificationCenter.default.addObserver(self, selector: #selector(appEnteredForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(appEnteredBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
//    }

    override func viewDidLoad() {
        super.viewDidLoad()
        spotCheckSettingsButton.isEnabled = false
        self.disabledPopupButton.isHidden = true
        
        testDeviceInternetConnection()
    }
    
    // MARK: - IBActions

    @IBAction func disabledPopupButtonClicked(_ sender: Any) {
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        let retry = UIAlertAction(title: "Retry", style: .default) { _ in self.testDeviceInternetConnection() }
        let alertController = UIAlertController(title: "Device not found", message: "Could not find Spot Check device. You must configure the device's network connection using the top button before you can alter the Spot Check settings.", preferredStyle: .alert)
        alertController.addAction(retry)
        alertController.addAction(action)
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - ViewController functions
    private func testDeviceInternetConnection() {
        httpRequest?.cancel()
        httpRequest = SpotCheckNetwork.sendHttpRequest(host: "spot-check.local.", path: "health", body: nil, method: "GET", contentType: "application/json") { data, error in
            DispatchQueue.main.async {
                self.spotCheckSettingsButton.isEnabled = error == nil
                self.disabledPopupButton.isHidden = error == nil
            }
        }
        httpRequest?.resume()
    }
}

