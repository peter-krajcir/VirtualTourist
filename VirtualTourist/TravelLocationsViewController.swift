//
//  TravelLocationsViewController.swift
//  VirtualTourist
//
//  Created by Petrik on 13/11/15.
//  Copyright © 2015 Peter Krajcir. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var infoAboutDeleteView: UIView!
    @IBOutlet weak var editBarButtonItem: UIBarButtonItem!
    
    var shouldDeletePinOnTouch = false
    
    @IBAction func editPinsPressed(sender: AnyObject) {
        shouldDeletePinOnTouch = !shouldDeletePinOnTouch
        
        if shouldDeletePinOnTouch {
            infoAboutDeleteView.hidden = false
            editBarButtonItem.title = "Done"
        } else {
            infoAboutDeleteView.hidden = true
            editBarButtonItem.title = "Edit"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let longPress = UILongPressGestureRecognizer(target: self, action: "addAnnotation:")
        longPress.minimumPressDuration = 1.0
        mapView.addGestureRecognizer(longPress)
        
        do {
            try fetchedResultsController.performFetch()
        } catch {}
        
        fetchedResultsController.delegate = self
        
        if let pins = fetchedResultsController.fetchedObjects as? [Pin] {
            print("Fetched pins")
            for pin in pins {
                print("Pin lat: \(pin.latitude), Pin long: \(pin.longitude)")
                mapView.addAnnotation(pin)
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        shouldDeletePinOnTouch = false
        infoAboutDeleteView.hidden = true
        editBarButtonItem.title = "Edit"
    }
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: Pin.Keys.EntityName)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Pin.Keys.Longitude, ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        
    }()

    func addAnnotation(gestureRecognizer:UIGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizerState.Began {
            let touchPoint = gestureRecognizer.locationInView(mapView)
            let newCoord = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
            
            let dictionary: [String : AnyObject] = [
                Pin.Keys.Latitude: newCoord.latitude,
                Pin.Keys.Longitude: newCoord.longitude
            ]
            
            let pin = Pin(dictionary: dictionary, context: sharedContext)
            
            mapView.addAnnotation(pin)
            
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }

    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        let pin = view.annotation as! Pin
        print("lat: \(pin.latitude)")
        print("long: \(pin.longitude)")

        if shouldDeletePinOnTouch {
            print("deleting annotation")
            mapView.removeAnnotation(pin)
            sharedContext.deleteObject(pin)
            CoreDataStackManager.sharedInstance().saveContext()
        } else {
            performSegueWithIdentifier("showPhotoAlbum", sender: pin)
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showPhotoAlbum" {
            let pin = sender as! Pin
            let map = Map()
            map.latitudeDelta = mapView.region.span.latitudeDelta
            map.longitudeDelta = mapView.region.span.longitudeDelta
            
            let photoAlbumView = segue.destinationViewController as! PhotoAlbumViewController
            photoAlbumView.pin = pin
            photoAlbumView.map = map
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        print("controllerDidChangeContent called")
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let AnnotationId = "AnnotationId"
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(AnnotationId) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: AnnotationId)
            pinView!.animatesDrop = true
        } else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
}

