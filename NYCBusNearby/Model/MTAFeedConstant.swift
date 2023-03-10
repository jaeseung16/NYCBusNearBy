//
//  MTABusFeedConstant.swift
//  NYCBusNearby
//
//  Created by Jae Seung Lee on 1/13/23.
//

import Foundation

struct MTAFeedConstant {
    static let apiKey = "?key=6f4e9937-3e81-4752-8dbe-aa088e5a133d"
    
    static let contentType = "Content-Type"
    static let accept = "Accept"
    static let applicationJson = "application/json"
    static let applicationXWWWFormUrlencoded = "application/x-www-form-urlencoded"
    static let post = "POST"
    
    static let restUrlString = "http://ec2-18-218-113-91.us-east-2.compute.amazonaws.com:8080/busfeedmonitor/json"
}
