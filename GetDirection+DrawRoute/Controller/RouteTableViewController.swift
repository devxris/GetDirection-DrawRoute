//
//  RouteTableViewController.swift
//  GetDirection+DrawRoute
//
//  Created by Chris Huang on 26/09/2017.
//  Copyright © 2017 Chris Huang. All rights reserved.
//

import UIKit
import MapKit

class RouteTableViewController: UITableViewController {

	// MARK: Model
	var routeSteps = [MKRouteStep]()
	
	@IBAction func done(_ sender: UIBarButtonItem) {
		dismiss(animated: true, completion: nil)
	}
	
	
	// MARK: UITableViewDataSource and UITableViewDelegate
	override func numberOfSections(in tableView: UITableView) -> Int { return 1 }
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return routeSteps.count
	}
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		cell.textLabel?.text = routeSteps[indexPath.row].instructions
		return cell
	}
}
