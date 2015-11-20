//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Petrik on 13/11/15.
//  Copyright © 2015 Peter Krajcir. All rights reserved.
//

import Foundation

class FlickrClient: NSObject {
    
    let SecureUrl = "https://api.flickr.com/services/rest/"
    let ApiKey = "d2cbf57d0a827317a6f35cdbfc6c8e89"
    let MethodName = "flickr.photos.search"
    let Extras = "url_m"
    let SafeSearch = "1"
    let DataFormat = "json"
    let NoJsonCallback = "1"
    let BoundingBoxHalfWidth = 0.1
    let BoundingBoxHalfHeight = 0.1
    let SearchRadius = "10"
    let NumberOfPhotosInCollection = 15
    
    var session: NSURLSession
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    func searchPhotosByLatLon(pin: Pin, callback: (JSONResult: [[String: AnyObject?]]!, errorString: String?)->Void) {
        let methodArguments = [
            "method": MethodName,
            "api_key": ApiKey,
            "bbox": createBoundingBoxString(latitude: pin.latitude, longitude: pin.longitude),
            "safe_search": SafeSearch,
            "extras": Extras,
            "format": DataFormat,
            "nojsoncallback": NoJsonCallback
        ]
        
        let urlString = SecureUrl + escapedParameters(methodArguments)
        print(urlString)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                callback(JSONResult: nil, errorString: "There was an error with your request: \(error)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {

                if let response = response as? NSHTTPURLResponse {
                    callback(JSONResult: nil, errorString: "Your request returned an invalid response! Status code: \(response.statusCode)!")
                } else if let response = response {
                    callback(JSONResult: nil, errorString: "Your request returned an invalid response! Response: \(response)!")
                } else {
                    callback(JSONResult: nil, errorString: "Your request returned an invalid response!")
                }
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                callback(JSONResult: nil, errorString: "No data was returned by the request!")
                return
            }
            
            /* Parse the data! */
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                callback(JSONResult: nil, errorString: "Could not parse the data as JSON!")
                print("\(data)")
                return
            }
            
            /* GUARD: Did Flickr return an error? */
            guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                callback(JSONResult: nil, errorString: "Flickr API returned an error.")
                print("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Is "photos" key in our result? */
            guard let photosDictionary = parsedResult["photos"] as? NSDictionary else {
                callback(JSONResult: nil, errorString: "Flickr API returned an error.")
                print("Cannot find keys 'photos' in \(parsedResult)")
                return
            }
            
            /* GUARD: Is "pages" key in the photosDictionary? */
            guard let totalPages = photosDictionary["pages"] as? Int else {
                callback(JSONResult: nil, errorString: "Flickr API returned an error.")
                print("Cannot find key 'pages' in \(photosDictionary)")
                return
            }
            
            /* Pick a random page! */
            let pageLimit = min(totalPages, 40)
            let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            // self.getImageFromFlickrBySearchWithPage(methodArguments, pageNumber: randomPage)
            self.searchPhotosByLatLonForPage(pin, page: randomPage, callback: callback)
        }
        
        task.resume()
    }
 
    func searchPhotosByLatLonForPage(pin: Pin, page: Int, callback: (JSONResult: [[String: AnyObject?]]!, errorString: String?)->Void) {
        let methodArguments = [
            "method": MethodName,
            "api_key": ApiKey,
            "bbox": createBoundingBoxString(latitude: pin.latitude, longitude: pin.longitude),
            "safe_search": SafeSearch,
            "extras": Extras,
            "format": DataFormat,
            "nojsoncallback": NoJsonCallback,
            "page": String(page)
        ]
        
        let urlString = SecureUrl + escapedParameters(methodArguments)
        print(urlString)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                callback(JSONResult: nil, errorString: "There was an error with your request: \(error)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                
                if let response = response as? NSHTTPURLResponse {
                    callback(JSONResult: nil, errorString: "Your request returned an invalid response! Status code: \(response.statusCode)!")
                } else if let response = response {
                    callback(JSONResult: nil, errorString: "Your request returned an invalid response! Response: \(response)!")
                } else {
                    callback(JSONResult: nil, errorString: "Your request returned an invalid response!")
                }
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                callback(JSONResult: nil, errorString: "No data was returned by the request!")
                return
            }
            
            /* Parse the data! */
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                callback(JSONResult: nil, errorString: "Could not parse the data as JSON!")
                print("\(data)")
                return
            }
            
            /* GUARD: Did Flickr return an error? */
            guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                callback(JSONResult: nil, errorString: "Flickr API returned an error.")
                print("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Is "photos" key in our result? */
            guard let photosDictionary = parsedResult["photos"] as? NSDictionary else {
                callback(JSONResult: nil, errorString: "Flickr API returned an error.")
                print("Cannot find keys 'photos' in \(parsedResult)")
                return
            }
            
            /* GUARD: Is the "total" key in photosDictionary? */
            guard let totalPhotosVal = (photosDictionary["total"] as? NSString)?.integerValue else {
                callback(JSONResult: nil, errorString: "Flickr API returned an error.")
                print("Cannot find key 'total' in \(photosDictionary)")
                return
            }
            
            if totalPhotosVal > 0 {
                
                /* GUARD: Is the "photo" key in photosDictionary? */
                guard var photosArray = photosDictionary["photo"] as? [[String: AnyObject]] else {
                    callback(JSONResult: nil, errorString: "Flickr API returned an error.")
                    print("Cannot find key 'photo' in \(photosDictionary)")
                    return
                }
                
                var photosForPin:[[String: AnyObject?]] = []
                for _ in 1...self.NumberOfPhotosInCollection {
                    let randomImageIndex = Int(arc4random_uniform(UInt32(photosArray.count)))
                    let photo = photosArray.removeAtIndex(randomImageIndex)
                    photosForPin.append(photo)
                }
                
//                print(photosForPin)
                callback(JSONResult: photosForPin, errorString: nil)
            }
        }
        
        task.resume()
    }
    
    func getImageWithPath(path: String, callback: (imageData: NSData?, errorString: String?)-> Void) {
        print("Getting image for url: \(path)")
        
        guard let url = NSURL(string: path) else {
            callback(imageData: nil, errorString:"Invalid URL for the image from Flickr")
            return
        }
        
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in

            /* GUARD: Was there an error? */
            guard (error == nil) else {
                callback(imageData: nil, errorString: "There was an error with your request: \(error)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                
                if let response = response as? NSHTTPURLResponse {
                    callback(imageData: nil, errorString: "Your request returned an invalid response! Status code: \(response.statusCode)!")
                } else if let response = response {
                    callback(imageData: nil, errorString: "Your request returned an invalid response! Response: \(response)!")
                } else {
                    callback(imageData: nil, errorString: "Your request returned an invalid response!")
                }
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                callback(imageData: nil, errorString: "No data was returned by the request!")
                return
            }
            
            callback(imageData: data, errorString: nil)
        }
        
        task.resume()
        
    }
    
    func createBoundingBoxString(latitude latitude: Double, longitude: Double) -> String {
        
        let bottom_left_lon = longitude - BoundingBoxHalfWidth
        let bottom_left_lat = latitude - BoundingBoxHalfHeight
        let top_right_lon = longitude + BoundingBoxHalfWidth
        let top_right_lat = latitude + BoundingBoxHalfHeight
            
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
    
    
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        var urlVars = [String]()
        
        for (key, value) in parameters {
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
        }
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    // MARK: Shared Instance
    
    class func sharedInstance() -> FlickrClient {
        
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        
        return Singleton.sharedInstance
    }
    
    struct Caches {
        static let imageCache = ImageCache()
    }
}