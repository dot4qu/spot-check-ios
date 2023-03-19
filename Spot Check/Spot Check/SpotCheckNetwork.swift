//
//  SpotCheckNetwork.swift
//  Spot Check
//
//  Created by Brian Team on 11/2/20.
//

import Foundation

public class SpotCheckNetwork {
    private static func sendRequest(`protocol`: String, host: String, path: String, body: Data?, method: String, contentType: String, completionHandler: @escaping (Data?, Error?) -> Swift.Void) -> URLSessionDataTask {
        let url = URL(string: "\(`protocol`)://\(host)/\(path)")!
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

            let httpResponse = response as? HTTPURLResponse
            if httpResponse?.statusCode != 200 {
                print("statusCode should be 200, but is \(String(describing: httpResponse?.statusCode))")
            }

            completionHandler(data, nil)
        }
        
        httpRequest.resume()
        return httpRequest
    }
    
    public static func sendHttpRequest(host: String, path: String, body: Data?, method: String, contentType: String, completionHandler: @escaping (Data?, Error?) -> Swift.Void) -> URLSessionDataTask {
        return sendRequest(protocol: "http", host: host, path: path, body: body, method: method, contentType: contentType, completionHandler: completionHandler)
    }
    
    public static func sendHttpsRequest(host: String, path: String, body: Data?, method: String, contentType: String = "application/json", accept: String = "application/json", completionHandler: @escaping (Data?, Error?) -> Swift.Void) -> URLSessionDataTask {
        return sendRequest(protocol: "https", host: host, path: path, body: body, method: method, contentType: contentType, completionHandler: completionHandler)
    }
}
