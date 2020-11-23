//
//  SpotSearchViewController.swift
//  Spot Check
//
//  Created by Brian Team on 11/3/20.
//

import Foundation
import UIKit

class SpotSearchViewController : UITableViewController, UISearchResultsUpdating {
    
    var initialSearchText: String? = nil
    var searchController: UISearchController!
    var filteredSpotDetails: [SpotDetails] = []
    var httpsRequest: URLSessionDataTask?
    
    weak var delegate: SetSpotDetailsDelegate?
    
    // MARK: - IBOutlets
    
    // MARK: - Overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Start typing to search available locations..."
        searchController.searchBar.text = initialSearchText
        tableView.tableHeaderView = searchController.searchBar

        definesPresentationContext = true
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "surflineSpotCell", for: indexPath) as? SurflineSpotTableViewCell
        
        if (cell == nil) {
            cell = SurflineSpotTableViewCell(style: .default, reuseIdentifier: "surflineSpotCell")
        }
        
        let spotDetails = filteredSpotDetails[indexPath.row]
        cell!.spotNameTextField.text = spotDetails.name
        
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredSpotDetails.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let spotDetails = filteredSpotDetails[indexPath.row]
        delegate?.setSpotDetails(newSpotDetails: spotDetails)

        // Without this, the first dismiss call dismisses the search controller (aka hides the keyboard)
        // and a second tap would be required to fully dismiss search modal
        searchController.isActive = false
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - UISearchResultsUpdating impl
    func updateSearchResults(for searchController: UISearchController) {
        let enteredText = searchController.searchBar.text
        if (enteredText?.isEmpty ?? true) {
            return
        }

        let encodedText = enteredText!.lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        httpsRequest?.cancel()
        httpsRequest = SpotCheckNetwork.sendHttpsRequest(host: "services.surfline.com", path: "search/site?q=\(encodedText)&querySize=10&suggestionSize=10&newsSearch=false", body: nil, method: "GET", contentType: "application/json") { data, error in
            if (error != nil) {
                print(error!.localizedDescription)
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: [])
                guard let deserialized = json as? [[String: Any]] else {
                    print("error casting json to string:any dict")
                    return
                }
                
                self.filteredSpotDetails = []
                deserialized.lazy
                    .filter { topLevelObject in
                        let topLevelHitsDict = topLevelObject["hits"] as? [String: Any]
                        let innerHitsList = topLevelHitsDict?["hits"] as? [[String: Any]]
                        return innerHitsList?.contains { x in (x["_type"] as? String) == "spot" } ?? false
                    }
                    .forEach { topLevelObject in
                        guard let topLevelHitsDict = topLevelObject["hits"] as? [String: Any],
                              let innerHitsList = topLevelHitsDict["hits"] as? [[String: Any]] else {
                            return
                        }
                        innerHitsList.forEach { x in
                            guard let sourceObject = x["_source"] as? [String: Any],
                                  let locationObject = sourceObject["location"] as? [String: Any],
                                  let lat = locationObject["lat"] as? Double,
                                  let lon = locationObject["lon"] as? Double else {
                                return
                            }
                            
                            let latStr = String(format: "%.10f", lat)
                            let lonStr = String(format: "%.10f", lon)
                            let details = SpotDetails(
                                name: sourceObject["name"] as! String,
                                uid: x["_id"] as! String,
                                lat: latStr,
                                lon: lonStr)
                            self.filteredSpotDetails.append(details)
                        }
                    }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            } catch {
                print("Could not deserialize json response when retrieving current config from device, check 'current_configuration' endpoint")
            }
        }
        
        httpsRequest?.resume()
    }
}

protocol SetSpotDetailsDelegate : AnyObject {
    func setSpotDetails(newSpotDetails: SpotDetails?)
}

class SpotDetails {
    let name: String
    let uid: String
    
    // lat/lon stored as strings so we can just parse them as strings on the esp rather than
    // having to pull in floating point
    let lat: String
    let lon: String
    
    init(name: String, uid: String, lat: String, lon: String) {
        self.name = name
        self.uid = uid
        self.lat = lat
        self.lon = lon
    }
}
