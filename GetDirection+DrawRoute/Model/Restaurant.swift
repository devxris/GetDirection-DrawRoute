//
//  Restaurant.swift
//  GetDirection+DrawRoute
//
//  Created by Chris Huang on 25/09/2017.
//  Copyright © 2017 Chris Huang. All rights reserved.
//

import Foundation

struct Restaurant {
	var name = ""
	var type = ""
	var location = ""
	var image = ""
	var isVisited = false
	var phone = ""
	var rating = ""
	
	init(name: String, type: String, location: String, phone: String, image: String, isVisited: Bool) {
		self.name = name
		self.type = type
		self.location = location
		self.phone = phone
		self.image = image
		self.isVisited = isVisited
	}
}
