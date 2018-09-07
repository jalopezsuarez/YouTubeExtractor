//
//  YouTubeExtractor.swift
//  YouTubeExtractor
//
//  Created by Jose Antonio Lopez on 07/09/2018.
//  Copyright © 2018 Jose Antonio Lopez <jalopezsuarez@gmail.com. All rights reserved.
//

import Foundation
import AVFoundation

enum YouTubeExtractorAttempType: String {
    case Embedded = "embedded"
    case DetailPage = "detailpage"
    case Vevo = "vevo"
    case Blank = ""
    
    static var allValues: [YouTubeExtractorAttempType] = [.Embedded, .DetailPage, .Vevo, .Blank]
}

enum YouTubeExtractorVideoQuality: Int {
    case Small240 = 36
    case Medium360 = 18
    case HD720 = 22
}

class YouTubeExtractor {
    
    static let instance = YouTubeExtractor()
    
    // MARK : -
    // =======================================================
    
    let YoutubeGetVideoInfoURL = "https://www.youtube.com/get_video_info"
    
    // MARK : -
    // =======================================================
    
    func info(id: String?, quality: YouTubeExtractorVideoQuality, resource: String? = nil, completion: @escaping (_ url: URL?) -> Void) {
        var extraction: URL? = nil
        
        let synchronous = DispatchSemaphore(value: 0)
        
        if let videoResource = resource, !videoResource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let videoURL = URL(string: videoResource.trimmingCharacters(in: .whitespacesAndNewlines))
            if let resource = videoURL {
                var request = URLRequest(url: resource)
                request.httpMethod = "GET"
                let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            
                            if let streamURL = URL(string: videoResource) {
                                extraction = streamURL
                            }
                            
                        }
                    }
                    synchronous.signal()
                }
                task.resume()
                _ = synchronous.wait(timeout: .now() + 60)
            }
        }
        
        // ----------------------------------------------------
        
        if extraction == nil {
            
            if let videoId = id, !videoId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                
                var params: [String : String?] = [ : ]
                params["video_id"] = videoId
                params["ps"] = "default"
                params["eurl"] = ""
                params["gl"] = "US"
                params["hl"] = "en"
                
                for item in YouTubeExtractorAttempType.allValues {
                    params["el"] = item.rawValue
                    
                    var data = Data()
                    for (param, value) in params {
                        let body = "&" + param + "=" + (value ?? "")
                        data.append(body.data(using: String.Encoding.utf8)!)
                    }
                    var requestURL: String = YoutubeGetVideoInfoURL
                    let requestData = String(data: data, encoding: String.Encoding.utf8) ?? ""
                    if (requestData.first == "&") {
                        let requestParams = requestData.replacingCharacters(in: requestData.startIndex..<requestData.index(after: requestData.startIndex), with: "?")
                        requestURL += requestParams
                    }
                    if let url = URL(string:requestURL) {
                        var request = URLRequest(url: url)
                        request.httpMethod = "GET"
                        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                            
                            // ----------------------------------------------------
                            
                            if let responseData = data {
                                let body = String(data: responseData, encoding: String.Encoding.utf8) ?? ""
                                let parse = self.parse(body)
                                
                                var streams: [String] = []
                                if let value = parse["url_encoded_fmt_stream_map"] as? String, !value.isEmpty {
                                    streams.append(contentsOf: value.components(separatedBy: ","))
                                }
                                if let value = parse["adaptive_fmts"] as? String, !value.isEmpty {
                                    streams.append(contentsOf: value.components(separatedBy: ","))
                                }
                                
                                // ----------------------------------------------------
                                
                                for stream in streams {
                                    let raw = self.parse(stream)
                                    
                                    if let rawQuality = raw["itag"] as? String {
                                        if let streamQuality = Int(rawQuality), streamQuality == quality.rawValue {
                                            
                                            if let rawType = raw["type"] as? String, !rawType.isEmpty {
                                                if AVURLAsset.isPlayableExtendedMIMEType(rawType) {
                                                    
                                                    if var rawURL = raw["url"] as? String, !rawURL.isEmpty {
                                                        if !self.parse(rawURL).keys.contains("signature") {
                                                            if let rawSignature = raw["sig"] as? String, !rawSignature.isEmpty {
                                                                rawURL = String(format:"%@signature=%@", rawURL, rawSignature)
                                                            }
                                                        }
                                                        if let streamURL = URL(string: rawURL) {
                                                            extraction = streamURL
                                                        }
                                                    }
                                                    
                                                }
                                            }
                                            
                                        }
                                    }
                                    
                                    if let completion = extraction, !completion.absoluteString.isEmpty {
                                        break
                                    }
                                }
                            }
                            
                            // ----------------------------------------------------
                            
                            synchronous.signal()
                        }
                        task.resume()
                        _ = synchronous.wait(timeout: .now() + 60)
                    }
                    
                    if let completion = extraction, !completion.absoluteString.isEmpty {
                        break
                    }
                }
            }
        }
        
        // ----------------------------------------------------
        
        // Background Thread
        //DispatchQueue.global(qos: .background).async { }
        
        // Run UI Updates or call completion block
        //DispatchQueue.main.async { }
        
        DispatchQueue.global(qos: .background).async {
            completion(extraction)
        }
    }
    
    private func parse(_ string: String?) -> [String:String?] {
        var response: [String:String?] = [:]
        
        if let raw = string {
            let fields = raw.components(separatedBy: "&")
            for field in fields {
                let pairs = field.components(separatedBy: "=")
                if pairs.count > 1 {
                    let key = pairs[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    if key.count > 0 {
                        if var value = pairs[1].removingPercentEncoding {
                            value = value.replacingOccurrences(of: "+", with: " ")
                            value = value.trimmingCharacters(in: .whitespacesAndNewlines)
                            response[key] = value
                        }
                    }
                }
            }
        }
        
        return response
    }
}
