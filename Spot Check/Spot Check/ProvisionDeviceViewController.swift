//
//  ConnectDeviceToNetworkViewController.swift
//  Spot Check
//
//  Created by Brian Team on 10/28/20.
//

import Foundation
import UIKit
import ESPProvision

class ProvisionDeviceViewController : UIViewController {
    var device: ESPDevice!
    var visibleNetworksList: [ESPWifiNetwork] = []
    
    // MARK: - Overrides
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.title = "Device Configuration"
    }
    
    override func viewDidLoad() {
        scanNetworksButton.isHidden = false
        scanNetworksButton.isEnabled = true
        self.visibleNetworksTableView.isHidden = true
    }
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var scanNetworksButton: UIButton!
    @IBOutlet weak var visibleNetworksTableView: UITableView!
    
    // MARK: - IBActions
    
    @IBAction func scanNetworksButtonClicked(_ sender: Any) {
        scanNetworksButton.isEnabled = false
        // show spinner
        device.scanWifiList { foundNetworks, _ in
            DispatchQueue.main.async {
                self.visibleNetworksTableView.isHidden = false
                self.scanNetworksButton.isHidden = true
                // hide spinner
//                self.headerView.isHidden = false
                if let list = foundNetworks {
                    self.visibleNetworksList = list.sorted { $0.rssi > $1.rssi }
                }
                self.visibleNetworksTableView.reloadData()
            }
        }
    }
    
    // Mark: - ViewController functions
    
    private func provisionESPDevice(ssid: String, password: String) {
        device.provision(ssid: ssid, passPhrase: password) { status in
            DispatchQueue.main.async {
                // hide spinner
                var alertController: UIAlertController
                var action: UIAlertAction
                switch status {
                case .success:
                    let handler: ((UIAlertAction) -> Void)? = {_ in
                        // Some weirdness here:
                        //  - we save a local copy of the navigation vc because popToRootViewController nulls it out
                        //  - we're using a manual pop and push onto nav VC b/c if an unwind segue is used, it performs
                        //         the second segue (showing config) first, then clear is back to the main screen
                        let navigationVC = self.navigationController
                        navigationVC?.popToRootViewController(animated: false)
                        let vc = self.storyboard?.instantiateViewController(identifier: "configureSpotCheckVC") as! ConfigureSpotCheckViewController
                        navigationVC?.pushViewController(vc, animated: true)
                    }
                    action = UIAlertAction(title: "Continue", style: .default, handler: handler)
                    alertController = UIAlertController(title: "Success", message: "Spot Check device successfully connected to the '\(ssid)' network!", preferredStyle: .alert)
                    break
                case let .failure(error):
                    action = UIAlertAction(title: "OK", style: .default, handler: nil)
                    alertController = UIAlertController(title: "Configuration failed", message: nil, preferredStyle: .alert)
                    
                    switch error {
                    case .configurationError:
                        alertController.message = "Failed to apply network configuration to device, please close app and and restart process"
                    case .sessionError:
                        alertController.message = "Failed to establish session with device, please close app and and restart process"
                    case .wifiStatusDisconnected:
                        alertController.message = "Lost connection to device WiFi network, please close app and and restart process"
                    default:
                        alertController.message = "Failed connecting device to the '\(ssid)' network, please close app and and restart process"
                    }
                    break
                case .configApplied:
                fallthrough
                default:
                    return
                }
                
                alertController.addAction(action)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
}

extension ProvisionDeviceViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        visibleNetworksTableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row >= visibleNetworksList.count {
//            joinOtherNetwork()
        } else {
            let networkDetails = visibleNetworksList[indexPath.row]

            if networkDetails.auth != .open {
                let passwordInputAlert = UIAlertController(title: networkDetails.ssid, message: nil, preferredStyle: .alert)

                passwordInputAlert.addTextField { textField in
                    textField.placeholder = "Password"
                    textField.isSecureTextEntry = true
                }
                passwordInputAlert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { _ in

                }))
                passwordInputAlert.addAction(UIAlertAction(title: "Apply", style: .default, handler: { [weak passwordInputAlert] _ in
                    let textField = passwordInputAlert?.textFields![0]
                    guard let passphrase = textField?.text else {
                        return
                    }
                    if passphrase.count > 0 {
                        // show spinner
                        self.provisionESPDevice(ssid: networkDetails.ssid, password: passphrase)
                    }
                }))
                present(passwordInputAlert, animated: true, completion: nil)
            } else {
                provisionESPDevice(ssid: networkDetails.ssid, password: "")
            }
        }
    }
}

extension ProvisionDeviceViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return visibleNetworksList.count + 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "visibleNetworkCell", for: indexPath) as! VisibleNetworkTableViewCell

        if indexPath.row >= visibleNetworksList.count {
//            cell.ssidLabel.text = "Join Other Network"
//            cell.signalImageView.image = UIImage(named: "add_icon")
        } else {
            let networkDetails = visibleNetworksList[indexPath.row]
            cell.ssidLabel.text = networkDetails.ssid
            cell.networkStrengthLabel.text = String(networkDetails.rssi)
            cell.isPrivateLabel.isHidden = networkDetails.auth == .open
        }
        return cell
    }
}
