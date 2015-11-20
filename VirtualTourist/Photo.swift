//
//  Photo.swift
//  VirtualTourist
//
//  Created by Petrik on 13/11/15.
//  Copyright © 2015 Peter Krajcir. All rights reserved.
//

import UIKit
import CoreData

@objc(Photo)

class Photo: NSManagedObject {

    struct Keys {
        static let EntityName = "Photo"
        
        static let ImageUrl = "imageUrl"
        static let Pin = "pin"
    }
    
    @NSManaged var imageUrl: String?
    @NSManaged var pin: Pin?
    
    var imagePath: String? {
        get {
            return imageUrl!.stringByReplacingOccurrencesOfString("/", withString: "_").stringByReplacingOccurrencesOfString(":", withString: "_")
        }
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        let entity =  NSEntityDescription.entityForName(Keys.EntityName, inManagedObjectContext: context)!

        super.init(entity: entity,insertIntoManagedObjectContext: context)
        
        imageUrl = dictionary[Keys.ImageUrl] as? String
    }
    
    var image: UIImage? {
        get {
            return FlickrClient.Caches.imageCache.imageWithIdentifier(imagePath)
        }
        set {
            FlickrClient.Caches.imageCache.storeImage(newValue, withIdentifier: imagePath!)
        }
    }
}