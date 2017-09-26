//
//  MapViewController.swift
//  GetDirection+DrawRoute
//
//  Created by Chris Huang on 25/09/2017.
//  Copyright © 2017 Chris Huang. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController {

	@IBOutlet weak var mapView: MKMapView! {
		didSet {
			mapView.delegate = self
			if #available(iOS 9.0, *) {
				mapView.showsCompass = true
				mapView.showsScale = true
				mapView.showsTraffic = true
			}
		}
	}
	
	var restaurant: Restaurant!
	var currentPlacemark: CLPlacemark?
	
	@IBOutlet weak var segmentedControl: UISegmentedControl! {
		didSet {
			segmentedControl.addTarget(self, action: #selector(self.showDirection(_:)), for: .valueChanged)
		}
	}
	var currentTransportType = MKDirectionsTransportType.automobile
	var currentRoute: MKRoute?
	
	private func geoCode(from restaurant: Restaurant) {
		// Convert address to coordinate and annotate it on map
		let geoCoder = CLGeocoder()
		geoCoder.geocodeAddressString(restaurant.location) { [weak self] (placemarks, error) in
			
			if let error = error { print(error.localizedDescription); return }
			guard let placemarks = placemarks else { return }
			
			// get the first placemark
			let placemark = placemarks[0]
			self?.currentPlacemark = placemark
			// add annotation
			let annotation = MKPointAnnotation()
			annotation.title = restaurant.name
			annotation.subtitle = restaurant.type
			guard let location = placemark.location else { return }
			annotation.coordinate = location.coordinate
			// show the annotation
			self?.mapView.showAnnotations([annotation], animated: true)
			self?.mapView.selectAnnotation(annotation, animated: true)
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		geoCode(from: restaurant)
		accessLocationAuthorization { (granted) in
			if granted {
				mapView.showsUserLocation = true // need authorization
			}
		}
		
		segmentedControl.isHidden = true
	}
	
	let locationManager = CLLocationManager()
	
	private func accessLocationAuthorization(completion: (_ granted: Bool) ->()) {
		let status = CLLocationManager.authorizationStatus()
		switch status {
		case .authorizedWhenInUse: completion(true)
		case .notDetermined, .denied:
			locationManager.requestWhenInUseAuthorization()
			if status == .denied { DispatchQueue.main.async { self.remindUserToAuthorize() } }
		case .restricted : completion(false)
		default: break
		}
	}
	
	private func remindUserToAuthorize() {
		let alert = UIAlertController(title: "Need your authorization", message: "Please authorized to use your current location.", preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: { (action) in
			guard let settingsURL = URL(string: UIApplicationOpenSettingsURLString) else { return }
			if UIApplication.shared.canOpenURL(settingsURL) {
				UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
			}
		}))
		alert.addAction(UIAlertAction(title: "Later", style: .cancel, handler: nil))
		present(alert, animated: true, completion: nil)
	}
	
	@IBAction func showDirection(_ sender: UIButton) {
		
		// display segmented control
		segmentedControl.isHidden = false
		switch segmentedControl.selectedSegmentIndex {
		case 0 : currentTransportType = .automobile
		case 1 : currentTransportType = .walking
		default: break
		}
		
		guard let currentPlacemark = currentPlacemark else { return }
		
		// configure directionRequest
		let directionRequest = MKDirectionsRequest()
		directionRequest.source = MKMapItem.forCurrentLocation()
		let destinationPlacemark = MKPlacemark(placemark: currentPlacemark)
		directionRequest.destination = MKMapItem(placemark: destinationPlacemark)
		directionRequest.transportType = currentTransportType
		
		// calculate the direction
		let directions = MKDirections(request: directionRequest)
		directions.calculate { (routeResponse, routeError) in
			guard let response = routeResponse else {
				if let error = routeError {
					print(error.localizedDescription)
				}
				return
			}
			// get routes from response
			let route = response.routes[0]
			// add route to current route
			self.currentRoute = route
			// remove previous overlays in advance
			self.mapView.removeOverlays(self.mapView.overlays)
			// add route on the mapView
			self.mapView.add(route.polyline, level: .aboveRoads) // need to implement delegate method
			
			// scale the map to fit the route perfectly
			let rect = route.polyline.boundingMapRect
			self.mapView.setRegion(MKCoordinateRegionForMapRect(rect), animated: true)
		}
	}
	
	@IBAction func showNearby(_ sender: UIButton) {
		
		// Configure MKLocationSearchRequest
		let searchRequest = MKLocalSearchRequest()
		searchRequest.naturalLanguageQuery = restaurant.type
		searchRequest.region = mapView.region
		
		// Start MKLocalSearch
		let search = MKLocalSearch(request: searchRequest)
		search.start { (response, error) in
			guard let response = response else { if let error = error { print(error) }; return }
			// Get mapItems from response
			let mapItems = response.mapItems
			var nearbyAnnotations: [MKAnnotation] = []
			guard mapItems.count > 0 else { return }
			mapItems.forEach { (item) in
				// Configure each annotation
				let annotation = MKPointAnnotation()
				annotation.title = item.name
				annotation.subtitle = item.phoneNumber
				if let location = item.placemark.location {
					annotation.coordinate = location.coordinate
				}
				nearbyAnnotations.append(annotation)
			}
			// show the annotations
			self.mapView.showAnnotations(nearbyAnnotations, animated: true)
		}
	}
	
	// MARK: Navigation
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "ShowSteps" {
			guard let routeTableViewController = segue.destination.contentViewController as? RouteTableViewController else { return }
			guard let steps = currentRoute?.steps else { return }
			routeTableViewController.routeSteps = steps
		}
	}
}

extension UIViewController {
	var contentViewController: UIViewController? {
		guard let naviController = self as? UINavigationController else { return self }
		return naviController.visibleViewController ?? self
	}
}

extension MapViewController: MKMapViewDelegate {
	
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		let identifier = "Pins"
		if annotation.isKind(of: MKUserLocation.self) { return nil }
		
		// Reuse annotations
		var annotationView: MKPinAnnotationView? = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKPinAnnotationView
		
		if annotationView == nil {
			annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
			annotationView?.canShowCallout = true
		}
		
		// Pin color customization based on type of annotation
		if let currentPlacemarkCoordinate = currentPlacemark?.location?.coordinate {
			if currentPlacemarkCoordinate.latitude == annotation.coordinate.latitude &&
				currentPlacemarkCoordinate.longitude == annotation.coordinate.longitude {
				// Configure leftCalloutAccessoryView
				let leftIconView = UIImageView(frame: CGRect(x: 0, y: 0, width: 53, height: 53))
				leftIconView.image = UIImage(named: restaurant.image)
				annotationView?.leftCalloutAccessoryView = leftIconView
				// Customize pin color
				if #available(iOS 9.0, *) { annotationView?.pinTintColor = .orange }
			} else {
				if #available(iOS 9.0, *) { annotationView?.pinTintColor = .red }
			}
		}
		
		// Configure rightCalloutAccessoryView to show route steps
		annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
		
		return annotationView
	}
	
	func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
		let renderer = MKPolylineRenderer(overlay: overlay)
		renderer.lineWidth = 3.0
		renderer.strokeColor = currentTransportType == .automobile ? .blue : .orange
		return renderer
	}
	
	func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
		performSegue(withIdentifier: "ShowSteps", sender: view)
	}
}
