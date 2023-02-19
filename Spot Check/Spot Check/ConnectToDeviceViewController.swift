//
//  LaunchSettingsViewController.swift
//  Spot Check
//
//  Created by Brian Team on 10/28/20.
//

import Foundation
import UIKit
import ESPProvision
import CoreLocation

class ConnectToDeviceViewController : UIViewController, ESPDeviceConnectionDelegate {

    var httpRequest: URLSessionDataTask?
    let locationManager = CLLocationManager()
    
    // MARK: - Overrides
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(appEnteredForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appEnteredBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    override func viewDidLoad() {
        getLocationPermission()
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var launchSettingsButton: UIButton!
    
    // MARK: - IBActions
    
    @IBAction func launchSettingsClicked(_ sender: Any) {
        launchSettingsButton.isEnabled = false
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            // Tell user to open settings manually
            return
        }

        if (UIApplication.shared.canOpenURL(settingsUrl)) {
            UIApplication.shared.open(settingsUrl, completionHandler: nil)
        } else {
            // Tell user to open settings manually
        }
    }
    
    // MARK: - Lifecycle functions
    
    @objc func appEnteredForeground() {
        // show loader
        // Will create and attempt to an ESPDevice if initial version request succeeds
        getDeviceVersionInfo()
        // hide loader
    }
    
    @objc func appEnteredBackground() {
        httpRequest?.cancel()
    }
    
    // MARK: - ViewController functions
    
    func getLocationPermission()  {
            let locStatus = CLLocationManager.authorizationStatus()
            switch locStatus {
               case .notDetermined:
                  locationManager.requestWhenInUseAuthorization()
               return
               case .denied, .restricted:
                  let alert = UIAlertController(title: "Location Services are disabled", message: "Please enable Location Services in your Settings", preferredStyle: .alert)
                  let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                  alert.addAction(okAction)
                  present(alert, animated: true, completion: nil)
               case .authorizedAlways, .authorizedWhenInUse:
               break
            @unknown default:
                print("unknown")
            }
        }
    
    func getDeviceVersionInfo() {
        httpRequest = SpotCheckNetwork.sendHttpRequest(host: "192.168.4.1", path: "proto-ver", body: Data("ESP".utf8), method: "POST", contentType: "application/x-www-form-urlencoded") { response, error in
            DispatchQueue.main.async {
                if error == nil {
//                    if self.deviceStatusTimer!.isValid {
//                        self.deviceStatusTimer?.
                    self.createESPDevice()
//                    }
                } else {
                    let action = UIAlertAction(title: "Connection Failed", style: .default, handler: nil)
                    let alertController = UIAlertController(title: "Connection failed", message: "Could not find Spot Check device. Are you sure you're connected to the 'Spot Check configuration' natwork and the device is plugged in?", preferredStyle: .alert)
                    alertController.addAction(action)
                    self.present(alertController, animated: true) {
                        self.launchSettingsButton.isEnabled = true
                    }
                }
            }
        }
    }
    
    private func createESPDevice() {
        let ssid = "Spot Check configuration"
        ESPProvisionManager.shared.createESPDevice(deviceName: ssid, transport: .softap, security: .unsecure, completionHandler: { device, _ in
            if device != nil {
                self.connectToESPDevice(device: device!)
            } else {
                print("Failed creating device")
                self.launchSettingsButton.isEnabled = true
            }
        })
    }
    
    private func connectToESPDevice(device: ESPDevice) {
        device.connect(delegate: self) { status in
            DispatchQueue.main.async {
                switch status {
                case .connected:
                    let action = UIAlertAction(title: "Continue", style: .default) {_ in self.showConnectDeviceToNetworkVC(device: device) }
                    let alertController = UIAlertController(title: "Success!", message: "Successfully connected to Spot Check device. Continue to device network connection setup", preferredStyle: .alert)
                    alertController.addAction(action)
                    self.present(alertController, animated: true, completion: nil)
                    break
                case let .failedToConnect(error):
                    self.launchSettingsButton.isEnabled = true
//                    let action = UIAlertAction(title: "OK", style: .default, handler: nil)
//                    let alertController = UIAlertController(title: "Connection failed", message: "Could not find Spot Check device (\(error)). Are you sure you're connected to the 'Spot Check configuration' network and the device is plugged in?", preferredStyle: .alert)
//                    alertController.addAction(action)
//                    self.present(alertController, animated: true, completion: nil)
                    break
                default:
                    let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                    let alertController = UIAlertController(title: "Error", message: "Unknown error ocurred, please try again", preferredStyle: .alert)
                    alertController.addAction(action)
                    self.present(alertController, animated: true, completion: nil)
                    break
                }
                
                self.launchSettingsButton.isEnabled = true
            }
        }
    }
    
    private func showConnectDeviceToNetworkVC(device: ESPDevice) {
        let vc = storyboard?.instantiateViewController(withIdentifier: "provisionDeviceVC") as! ProvisionDeviceViewController
        vc.device = device
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func getProofOfPossesion(forDevice: ESPDevice, completionHandler: @escaping (String) -> Void) {
        completionHandler("")
    }
}
