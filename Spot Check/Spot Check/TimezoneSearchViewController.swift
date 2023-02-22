//
//  TimezoneSearchViewController.swift
//  Spot Check
//
//  Created by Brian Team on 22.02.23.
//

import Foundation
import UIKit
import SQLite

class TimezoneSearchViewController : UITableViewController, UISearchResultsUpdating {
    var initialSearchText: String? = nil
    var searchController: UISearchController!
    var filteredTimezoneObjs: [TimezoneObj] = []
    var db: Connection? = nil
    var tzTable: Table? = nil
    var displayNameCol = Expression<String>("display_name")
    var tzStrCol = Expression<String>("tz_string")
    
    
    weak var delegate: SetTimezoneObjDelegate?
    
    // MARK: - IBOutlets
    
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
        
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Start typing to filter available timezones"
        searchController.searchBar.text = initialSearchText
        tableView.tableHeaderView = searchController.searchBar
        
        definesPresentationContext = true
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "timezoneObjCell", for: indexPath) as? TimezoneObjTableViewCell
        
        if (cell == nil) {
            cell = TimezoneObjTableViewCell(style: .default, reuseIdentifier: "timezoneObjCell")
        }
        
        let timezoneObj = filteredTimezoneObjs[indexPath.row]
        cell!.displayNameTextField.text = timezoneObj.displayName
        
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredTimezoneObjs.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let timezoneObj = filteredTimezoneObjs[indexPath.row]
        delegate?.setTimezoneObj(newTimezoneObj: timezoneObj)
        
        searchController.isActive = false
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - UISearchResultsUpdating impl
    
    func updateSearchResults(for searchController: UISearchController) {
        let enteredText = searchController.searchBar.text
        if (enteredText?.isEmpty ?? true) {
            return
        }
        
        do {
            let query = tzTable!.filter(displayNameCol.like("%\(enteredText!)%"))
            
            filteredTimezoneObjs = []
            for tzObj in try db!.prepare(query) {
                let obj = TimezoneObj(displayName: tzObj[displayNameCol], tzStr: tzObj[tzStrCol])
                filteredTimezoneObjs.append(obj)
            }
        } catch {
            print(error)
            exit(1)
        }
        
        tableView.reloadData()
    }
}

protocol SetTimezoneObjDelegate: AnyObject {
    func setTimezoneObj(newTimezoneObj: TimezoneObj?)
}

class TimezoneObj {
    let displayName: String
    let tzStr: String
    
    init(displayName: String, tzStr: String) {
        self.displayName = displayName
        self.tzStr = tzStr
    }
}
