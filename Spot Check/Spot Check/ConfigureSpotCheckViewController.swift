//
//  ConfigureSpotCheckViewController.swift
//  Spot Check
//
//  Created by Brian Team on 11/2/20.
//

import Foundation
import SystemConfiguration
import UIKit
import SQLite

class ConfigureSpotCheckViewController : UIViewController, UITextFieldDelegate, SetSpotDetailsDelegate, SetTimezoneObjDelegate {
    var httpRequest: URLSessionDataTask?
    private var selectedSpotDetails: SpotDetails? = nil
    private var selectedTimezoneObj: TimezoneObj? = nil
    private var manualTimeEpochSecs: UInt32 = 0
    var db: Connection? = nil
    var tzTable: Table? = nil
    var displayNameCol = Expression<String>("display_name")
    var tzStrCol = Expression<String>("tz_string")

    // MARK: - Overrides
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        do {
            let dbUrl = Bundle.main.url(forResource: "timezones", withExtension: "db")
            let dbPath = dbUrl!.absoluteString
            db = try Connection(dbPath)
            
            tzTable = Table("timezones")
            displayNameCol = Expression<String>("display_name")
            tzStrCol = Expression<String>("tz_string")

        } catch {
            print(error)
            exit(1)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        manualTimeDatePicker.timeZone = TimeZone.init(identifier: "UTC")
        
        configValuesChanged()
        getCurrentConfig()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    // MARK: - IBOutlets

    @IBOutlet weak var selectedSpotNameLabel: UILabel!
    @IBOutlet weak var selectedTimezoneLabel: UILabel!
    @IBOutlet weak var saveConfigButton: UIButton!
    @IBOutlet weak var saveManualTimeButton: UIButton!
    @IBOutlet weak var manualTimeDatePicker: UIDatePicker!
    
    // MARK: - IBActions

    @IBAction func editSpotButtonClicked(_ sender: Any) {
        let vc = storyboard?.instantiateViewController(withIdentifier: "spotSearchVC") as! SpotSearchViewController
        if (selectedSpotDetails != nil) {
            vc.initialSearchText = selectedSpotDetails!.name
        }

        vc.delegate = self
        navigationController?.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func editTimezoneButtonClicked(_ sender: Any) {
        let vc = storyboard?.instantiateViewController(withIdentifier: "timezoneSearchVC") as! TimezoneSearchViewController
        
        vc.db = db
        vc.tzTable = tzTable
        vc.displayNameCol = displayNameCol
        vc.tzStrCol = tzStrCol
        
        if (selectedTimezoneObj != nil) {
            vc.initialSearchText = selectedTimezoneObj?.displayName
        }
        
        vc.delegate = self
        navigationController?.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func manualTimeDatePickerChanged(_ sender: Any) {
        configValuesChanged()
    }
    
    @IBAction func saveConfigClicked(_ sender: Any) {
        applyConfig()
    }
    
    @IBAction func saveManualTimeClicked(_ sender: Any) {
        applyManualTime()
    }
    
    // MARK: - SetSpotDetailsDelegate impl
    
    func setSpotDetails(newSpotDetails: SpotDetails?) {
        selectedSpotDetails = newSpotDetails
        selectedSpotNameLabel.text = selectedSpotDetails?.name ?? "No spot selected"
        selectedSpotNameLabel.textColor = selectedSpotDetails == nil ? UIColor.opaqueSeparator : UIColor.label
        configValuesChanged()
    }
    
    // MARK: - SetTimezoneObjDelegate impl
    
    func setTimezoneObj(newTimezoneObj: TimezoneObj?) {
        selectedTimezoneObj = newTimezoneObj
        selectedTimezoneLabel.text = newTimezoneObj?.displayName ?? "No timezone selected"
        selectedTimezoneLabel.textColor = selectedTimezoneObj == nil ? UIColor.opaqueSeparator : UIColor.label
        configValuesChanged()
    }
    
    // MARK: - ViewController functions
    
//    func textFieldShouldReturn(_ userText: UITextField) -> Bool {
//        userText.resignFirstResponder()
//        return true;
//    }

    private func configValuesChanged() {
        let spotNameTextValid = selectedSpotDetails != nil && !selectedSpotDetails!.name.isEmpty && !selectedSpotDetails!.uid.isEmpty
        let timezoneValid = selectedTimezoneObj != nil && !selectedTimezoneObj!.displayName.isEmpty && !selectedTimezoneObj!.tzStr.isEmpty

        saveConfigButton.isEnabled = spotNameTextValid && timezoneValid
    }
    
    private func getCurrentConfig() {
        httpRequest?.cancel()
        saveConfigButton.isEnabled = false
        //spinner
        
        httpRequest = SpotCheckNetwork.sendHttpRequest(host: "spot-check.local.", path: "current_configuration", body: nil, method: "GET", contentType: "application/json") { data, error in
            DispatchQueue.main.async {
                // hide spinner
                self.saveConfigButton.isEnabled = true
            }

            if (error != nil) {
                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                let alertController = UIAlertController(title: "Error", message: "Could not retrieve current Spot Check configuration saved on device, functionality to save new configuration might be broken.", preferredStyle: .alert)
                alertController.addAction(action)
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: [])
                guard let deserialized = json as? [String: Any] else {
                    print("Could not deserialize json response when retrieving current config from device, check 'current_configuration' endpoint")
                    return
                }
                
                DispatchQueue.main.async {
                    let spotName = deserialized["spot_name"] as? String
                    let spotUid = deserialized["spot_uid"] as? String
                    let spotLat = deserialized["spot_lat"] as? String
                    let spotLon = deserialized["spot_lon"] as? String
                    let tzStr = deserialized["tz_str"] as? String
                    let tzDisplayName = deserialized["tz_display_name"] as? String
                    if (spotName != nil && spotUid != nil && spotLat != nil && spotLon != nil) {
                        let details = SpotDetails(name: spotName!, uid: spotUid!, lat: spotLat!, lon: spotLon!)
                        self.setSpotDetails(newSpotDetails: details)
                    } else {
                        print("Got invalid spot name / uid / lat / lon, setting selected details to nil (name: \(spotName ?? "nil") - uid: \(spotUid ?? "nil") - \(spotLat ?? "nil") - \(spotLon ?? "nil"))")
                        self.setSpotDetails(newSpotDetails: nil)
                    }

                    if (tzStr != nil && tzDisplayName != nil) {
                        let query = self.tzTable!.filter(self.displayNameCol.like(tzDisplayName!))
                        do {
                            if let rawObj = try self.db!.pluck(query) {
                                let obj = TimezoneObj(displayName: rawObj[self.displayNameCol], tzStr: rawObj[self.tzStrCol])
                                
                                // This assert technically isn't necessary, and we could also fall back to selecting based off received tz_str if display_name fails, but theoretically that should never happen
                                assert(obj.tzStr == tzStr)
                                
                                self.setTimezoneObj(newTimezoneObj: obj)
                            } else {
                                print("Got tz_str but query out of db failed, setting selected obj to nil (tz_str: \(tzStr ?? "nil"))")
                                self.setTimezoneObj(newTimezoneObj: nil)
                            }
                        } catch {
                            print(error)
                            exit(1)
                        }
                    } else {
                        print("Got invalid tz_str / tz_display_name, setting selected obj to nil (tz_str: \(tzStr ?? "nil") - tz_display_name: \(tzDisplayName ?? "nil")")
                        self.setTimezoneObj(newTimezoneObj: nil)
                    }
                }
            } catch {
                print("Could not deserialize json response when retrieving current config from device, check 'current_configuration' endpoint")
            }
        }
    }
    
    private func applyManualTime() {
        httpRequest?.cancel()
        // spinner
        saveConfigButton.isEnabled = false

        let body: [String: Any] = [
            "epoch_secs" : manualTimeDatePicker.date.timeIntervalSince1970
        ]

        var data: Data = Data("{}".utf8)
        do {
            data = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        } catch {
            print(error.localizedDescription)
            return
        }
        
        httpRequest = SpotCheckNetwork.sendHttpRequest(host: "spot-check.local.", path: "set_time", body: data, method: "POST", contentType: "application/json") { data, error in
            //hide spinner
            DispatchQueue.main.async {
                self.saveConfigButton.isEnabled = true
            }
            
            guard error == nil else {
                print(error!.localizedDescription)

                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                let alertController = UIAlertController(title: "Error", message: "Could not find Spot Check device on network, are you sure it is turned on and connected?", preferredStyle: .alert)
                alertController.addAction(action)
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }

                return
            }
            
            DispatchQueue.main.async {
                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                let alertController = UIAlertController(title: "Success", message: "Successfully set new time manually on Spot Check device", preferredStyle: .alert)
                alertController.addAction(action)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    private func applyConfig() {
        httpRequest?.cancel()
        // spinner
        saveConfigButton.isEnabled = false

        let body: [String: Any] = [
            "spot_name": selectedSpotDetails!.name,
            "spot_uid": selectedSpotDetails!.uid,
            "spot_lat": selectedSpotDetails!.lat,
            "spot_lon": selectedSpotDetails!.lon,
            "tz_str": selectedTimezoneObj!.tzStr,
            "tz_display_name": selectedTimezoneObj!.displayName
        ]

        var data: Data = Data("{}".utf8)
        do {
            data = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        } catch {
            print(error.localizedDescription)
            return
        }
        
        httpRequest = SpotCheckNetwork.sendHttpRequest(host: "spot-check.local.", path: "configure", body: data, method: "POST", contentType: "application/json") { data, error in
            //hide spinner
            DispatchQueue.main.async {
                self.saveConfigButton.isEnabled = true
            }
            
            guard error == nil else {
                print(error!.localizedDescription)

                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                let alertController = UIAlertController(title: "Error", message: "Could not find Spot Check device on network, are you sure it is turned on and connected?", preferredStyle: .alert)
                alertController.addAction(action)
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }

                return
            }
            
            DispatchQueue.main.async {
                let action = UIAlertAction(title: "OK", style: .default, handler: nil)
                let alertController = UIAlertController(title: "Success", message: "Successfully applied new configuration to Spot Check device", preferredStyle: .alert)
                alertController.addAction(action)
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
}
