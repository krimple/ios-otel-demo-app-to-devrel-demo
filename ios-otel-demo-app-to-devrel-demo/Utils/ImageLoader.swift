//
//  ImageLoader.swift
//  ios-otel-demo-app-to-devrel-demo
//
//  Image URL utilities for remote image loading.
//

import Foundation

/**
 * Image URL utilities for remote image loading.
 * 
 * This utility constructs proper image URLs from the picture field in Product models.
 * Images are served from the same base endpoint as the API but under /images/products/.
 */
class ImageLoader {
    
    /**
     * Constructs the full image URL from the picture field.
     * If the picture field already contains a full URL, returns it as-is.
     * Otherwise, constructs URL using the same base endpoint as the API.
     */
    static func getImageUrl(picture: String, apiEndpoint: String) -> String {
        if picture.hasPrefix("http://") || picture.hasPrefix("https://") {
            return picture
        } else {
            // Use the same base endpoint as the API, but replace /api with /images/products
            // This ensures images are served from the same local/remote environment as the API
            let baseUrl = apiEndpoint.hasSuffix("/api") ? 
                String(apiEndpoint.dropLast(4)) : apiEndpoint
            return "\(baseUrl)/images/products/\(picture)"
        }
    }
}