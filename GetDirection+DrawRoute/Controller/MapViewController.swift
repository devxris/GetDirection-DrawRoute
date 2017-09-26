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
		
		guard let currentPlacemark = currentPlacemark else { return }
		
		// configure directionRequest
		let directionRequest = MKDirectionsRequest()
		directionRequest.source = MKMapItem.forCurrentLocation()
		let destinationPlacemark = MKPlacemark(placemark: currentPlacemark)
		directionRequest.destination = MKMapItem(placemark: destinationPlacemark)
		directionRequest.transportType = .automobile
		
		// calculate the direction
		let directions = MKDirections(request: directionRequest)
		directions.calculate { (routeResponse, routeError) in
			guard let response = routeResponse else {
				if let error = routeError {
					print(error.localizedDescription)
				}
				return
			}
			let route = response.routes[0]
			// add route on the mapView
			self.mapView.add(route.polyline, level: .aboveRoads) // need to implement delegate method
			
			// scale the map to fit the route perfectly
			let rect = route.polyline.boundingMapRect
			self.mapView.setRegion(MKCoordinateRegionForMapRect(rect), animated: true)
		}
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
		
		// Configure leftCalloutAccessoryView
		let leftIconView = UIImageView(frame: CGRect(x: 0, y: 0, width: 53, height: 53))
		leftIconView.image = UIImage(named: restaurant.image)
		annotationView?.leftCalloutAccessoryView = leftIconView
		
		// Pin color customization
		if #available(iOS 9.0, *) {
			annotationView?.pinTintColor = .orange
		}
		
		return annotationView
	}
	
	func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
		let renderer = MKPolylineRenderer(overlay: overlay)
		renderer.lineWidth = 3.0
		renderer.strokeColor = .blue
		return renderer
	}
}
