//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Petrik on 13/11/15.
//  Copyright © 2015 Peter Krajcir. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, MKMapViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var photoActionBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var newCollectionBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var overlayActivityIndicator: UIActivityIndicatorView!
    
    var pin: Pin!
    var map: Map = Map()
    var selectedPhotos: [Photo]? {
        didSet {
            print("added item to selectedPhotos, count: \(selectedPhotos?.count)")
            if selectedPhotos == nil || selectedPhotos!.count == 0 {
                photoActionBarButtonItem.title = "New Collection"
            } else {
                photoActionBarButtonItem.title = "Remove Selected Pictures"
            }
        }
    }
    
    @IBAction func loadNewCollection(sender: AnyObject) {
        if selectedPhotos == nil || selectedPhotos!.count == 0 {
            // the user clicked on "New Collection" action
            for photo in fetchedResultsController.fetchedObjects as! [Photo] {
                // remove photo
                FlickrClient.Caches.imageCache.storeImage(nil, withIdentifier: photo.imagePath!)
                sharedContext.deleteObject(photo)
                CoreDataStackManager.sharedInstance().saveContext()
            }

            selectedPhotos = nil
            getImagesForPin(pin)
            collectionView.reloadData()
        } else {
            // the user clicked on "Remove Selected Pictures" action
            print("pictures to delete: \(selectedPhotos!.count)")
            for selectedPhoto in selectedPhotos! {
                let photo = selectedPhoto
                FlickrClient.Caches.imageCache.storeImage(nil, withIdentifier: photo.imagePath!)
                sharedContext.deleteObject(photo)
                CoreDataStackManager.sharedInstance().saveContext()
            }

            selectedPhotos = nil
        }
    }
    
    func getImagesForPin(pin:Pin) {
        newCollectionBarButtonItem.enabled = false
        overlayView.hidden = false
        FlickrClient.sharedInstance().searchPhotosByLatLon(pin) { (JSONResult, errorString) in
            dispatch_async(dispatch_get_main_queue()) {
                self.overlayView.hidden = true
            }
            if let errorString = errorString {
                print(errorString)
            } else {
                if let photos = JSONResult as [[String: AnyObject?]]? {
                    
                    for photoParsed in photos {
                        if let photoUrl = photoParsed["url_m"] as? String {
                            let dictionary: [String : AnyObject] = [
                                Photo.Keys.ImageUrl: photoUrl
                            ]
                            
                            let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                            photo.pin = self.pin
                            self.sharedContext.insertObject(photo)
                            CoreDataStackManager.sharedInstance().saveContext()
                        }
                    }

                    print("Photos in fetchedResultsController: \(self.fetchedResultsController.fetchedObjects?.count)")
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        self.collectionView.reloadData()
                    }
                } else {
                    print("No pictures found")
                }
            }
            dispatch_async(dispatch_get_main_queue()) {
                self.newCollectionBarButtonItem.enabled = true
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // set the back button name to "OK"
        let backButton = UIBarButtonItem()
        backButton.title = "OK"
        navigationController?.navigationBar.topItem?.backBarButtonItem = backButton
        
        // initial flow layout settings for the Collection view based on the device rotation
        setFlowLayout()
        
        // add listener for device rotation notification so we can set different flow layout for
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "deviceRotated", name: UIDeviceOrientationDidChangeNotification, object: nil)
        
        fetchedResultsController.delegate = self
    }
    
    func deviceRotated() {
        // set the flow layout for the Collection view based on the device rotation
        setFlowLayout()
    }
    
    deinit {
        // remove listener for device rotation notification
        NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
    }
    
    func setFlowLayout() {
        let space: CGFloat = 3.0
        var dimension: CGFloat = 0.0
        
        if (UIDeviceOrientationIsLandscape(UIDevice.currentDevice().orientation)) {
            dimension = (self.view.frame.size.width - (5 * space)) / 6.0
        }
        
        if(UIDeviceOrientationIsPortrait(UIDevice.currentDevice().orientation)) {
            dimension = (self.view.frame.size.width - (2 * space)) / 3.0
        }
        
        flowLayout.minimumInteritemSpacing = space
        flowLayout.minimumLineSpacing = space
        flowLayout.itemSize = CGSizeMake(dimension, dimension)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        print("view loaded with pin lat: \(pin.latitude) long: \(pin.longitude)")
        
        mapView.addAnnotation(pin)
        
        let span = MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        let region = MKCoordinateRegion(center: pin.coordinate, span: span)
        mapView.setRegion(region, animated: true)
    
        do {
            try fetchedResultsController.performFetch()
        } catch {}

        if let photos = fetchedResultsController.fetchedObjects as? [Photo] {
            print("Fetched photos")
            for photo in photos {
                print("Photo url: \(photo.imageUrl)")
            }
        }
        
        if fetchedResultsController.fetchedObjects == nil || fetchedResultsController.fetchedObjects?.count == 0 {
            print("fetched photos are empty, need to download them")
            getImagesForPin(pin)
        } else {
            self.overlayView.hidden = true
        }
    }

    
    // MARK: - Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // Mark: - Fetched Results Controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: Photo.Keys.EntityName)
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Photo.Keys.ImageUrl, ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        
    }()
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        print("count from sectionInfo fetchedResultsController: \(sectionInfo.numberOfObjects)")
        let count: Int
        if sectionInfo.numberOfObjects == 0 {
            count = 0
        } else {
            count = sectionInfo.numberOfObjects
        }
        return count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let CellIdentifier = "CellId"
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(CellIdentifier, forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        if let photo = fetchedResultsController.objectAtIndexPath(indexPath) as? Photo {
            if let localImage = photo.image {
                print("Local image found, getting from photo.image")
                let imageView = UIImageView(image: localImage)
                cell.backgroundView = imageView
                cell.loadingIndicator.stopAnimating()
            } else if photo.imageUrl == nil || photo.imageUrl == "" {
                print("There is no URL defined for the picture, should display blank image")
                cell.loadingIndicator.stopAnimating()
            } else {
                let url = photo.imageUrl!
                print("Photo hasn't been downloaded yet, downloading..")
                let _ = FlickrClient.sharedInstance().getImageWithPath(url) { (imageData, errorString) in
                    if let errorString = errorString {
                        print("Error returned from getImageWithPath(\(url)): \(errorString)")
                        dispatch_async(dispatch_get_main_queue()) {
                            cell.loadingIndicator.stopAnimating()
                        }
                    }
                    if let data = imageData {
                        dispatch_async(dispatch_get_main_queue()) {
                            cell.loadingIndicator.stopAnimating()
                            let image = UIImage(data: data)
                            photo.image = image
                            let imageView = UIImageView(image: image)
                            cell.backgroundView = imageView
                        }
                    } else {
                        print("No image data received from call getImageWithPath(\(url)), can't draw a picture")
                        dispatch_async(dispatch_get_main_queue()) {
                            cell.loadingIndicator.stopAnimating()
                        }
                    }
                }
            }
        } else {
            let imageView = UIImageView(image: nil)
            cell.backgroundView = imageView
            cell.loadingIndicator.startAnimating()
        }
        
        if selectedPhotos == nil || selectedPhotos!.count == 0 {
            cell.contentView.backgroundColor = nil
            cell.highlighted = false
            cell.selected = false
            collectionView.deselectItemAtIndexPath(indexPath, animated: false)            
        }
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        print("select")
        if let photo = fetchedResultsController.objectAtIndexPath(indexPath) as? Photo {
            let cell = collectionView.cellForItemAtIndexPath(indexPath)!
            if selectedPhotos == nil {
                // we haven't selected any picture yet
                selectedPhotos = [photo]
                cell.contentView.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.7)
                cell.highlighted = true
                cell.selected = true
                collectionView.selectItemAtIndexPath(indexPath, animated: false, scrollPosition: .None)
            } else {
                // let's search if the picture already exists in the selectedPhotos array
                var found = -1
                for var i = 0; i < selectedPhotos!.count; i++ {
                    if photo === selectedPhotos![i] {
                        found = i
                        break
                    }
                }
                if found == -1 {
                    // item is not selected yet, let's add it to the array and highlight it
                    selectedPhotos!.append(photo)
                    cell.contentView.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.7)
                    cell.highlighted = true
                    cell.selected = true
                    collectionView.selectItemAtIndexPath(indexPath, animated: false, scrollPosition: .None)
                } else {
                    // selected item is tapped again, remove it from the array and unhighlight it
                    selectedPhotos!.removeAtIndex(found)
                    cell.contentView.backgroundColor = nil
                    cell.highlighted = false
                    cell.selected = false
                    collectionView.deselectItemAtIndexPath(indexPath, animated: false)
                }
            }
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
            case .Insert:
                print("NSFetchedResultsController - didChangeObject - Insert")
                collectionView.insertItemsAtIndexPaths([newIndexPath!])
            case .Delete:
                print("NSFetchedResultsController - didChangeObject - Delete")
                collectionView.deleteItemsAtIndexPaths([indexPath!])
            case .Update:
                print("NSFetchedResultsController - didChangeObject - Update")
                let cell = collectionView.cellForItemAtIndexPath(indexPath!) as! PhotoCollectionViewCell
                let photo = controller.objectAtIndexPath(indexPath!) as! Photo
            case .Move:
                print("NSFetchedResultsController - didChangeObject - Move")
                collectionView.deleteItemsAtIndexPaths([indexPath!])
                collectionView.insertItemsAtIndexPaths([newIndexPath!])
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        print("controllerDidChangeContent called")
    }
}
