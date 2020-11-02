//
//  SpotCheckNetwork.swift
//  Spot Check
//
//  Created by Brian Team on 11/2/20.
//

import Foundation

public class SpotCheckNetwork {
    public static func sendHttpRequest(host: String, path: String, body: Data?, method: String, contentType: String, completionHandler: @escaping (Data?, Error?) -> Swift.Void) -> URLSessionDataTask {
        let url = URL(string: "http://\(host)/\(path)")!
        var request = URLRequest(url: url)

        request.setValue(contentType, forHTTPHeaderField: "Content-type")
        request.setValue("text/plain", forHTTPHeaderField: "Accept")

        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 10.0
        let httpRequest = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completionHandler(nil, error)
                return
            }

            let httpStatus = response as? HTTPURLResponse
            if httpStatus?.statusCode != 200 {
                print("statusCode should be 200, but is \(String(describing: httpStatus?.statusCode))")
            }

            completionHandler(data, nil)
        }
        
        httpRequest.resume()
        return httpRequest
    }
}
