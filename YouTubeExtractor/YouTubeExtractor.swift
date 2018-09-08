//
//  YouTubeExtractor.swift
//  YouTubeExtractor
//
//  Created by Jose Antonio Lopez on 07/09/2018.
//  Copyright © 2018 Jose Antonio Lopez <jalopezsuarez@gmail.com>. All rights reserved.
//

import Foundation
import AVFoundation

enum YouTubeExtractorAttempType: String {
    case embedded = "embedded"
    case detailPage = "detailpage"
    case vevo = "vevo"
    case blank = ""
    
    static var values: [YouTubeExtractorAttempType] = [.embedded, .detailPage, .vevo, .blank]
}

enum YouTubeExtractorVideoQuality: Int {
    case x1080, x720, x480, x360, x240, x144, none
    
    init(rawValue: Int) {
        switch rawValue {
        case 37, 46, 85, 96: self = .x1080
        case 22, 45, 84, 95, 102: self = .x720
        case 35, 44, 59, 78, 83, 94, 101: self = .x480
        case 18, 34, 43, 82, 93, 100: self = .x360
        case 6, 36, 92, 132: self = .x240
        case 5, 13, 17, 91, 151: self = .x144
        default: self = .none
        }
    }
    
    static var values: [YouTubeExtractorVideoQuality] = [.none, .x144, .x240, .x360, .x480, .x720, .x1080]
    var order: Int {
        return type(of: self).values.index(of:self)!
    }
}


class YouTubeExtractor {
    
    static let instance = YouTubeExtractor()
    
    // MARK : -
    // =======================================================
    
    let YoutubeGetVideoInfoURL = "https://www.youtube.com/get_video_info"
    
    // MARK : -
    // =======================================================
    
    func info(id: String?, quality: YouTubeExtractorVideoQuality, completion: @escaping (_ url: URL?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            self.parse(id: id, quality: quality, completion: completion)
        }
    }
    
    private func parse(id: String?, quality: YouTubeExtractorVideoQuality, resource: String? = nil, completion: @escaping (_ url: URL?) -> Void) {
        var extractionQuality: YouTubeExtractorVideoQuality = .none
        var extractionURL: URL? = nil
        
        let synchronous = DispatchSemaphore(value: 0)
        
        // ----------------------------------------------------
        
        if let videoId = id, !videoId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            
            var params: [String : String?] = [:]
            params["video_id"] = videoId
            params["ps"] = "default"
            params["eurl"] = ""
            params["gl"] = "US"
            params["hl"] = "en"
            
            for item in YouTubeExtractorAttempType.values {
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
                                if let rawType = raw["type"] as? String, !rawType.isEmpty {
                                    if AVURLAsset.isPlayableExtendedMIMEType(rawType) {
                                        if let rawQuality = raw["itag"] as? String {
                                            if let streamQuality = Int(rawQuality) {
                                                let enumQuality = YouTubeExtractorVideoQuality(rawValue: streamQuality)
                                                if enumQuality != .none && (enumQuality == quality || enumQuality.order > extractionQuality.order) {
                                                    if var rawURL = raw["url"] as? String, !rawURL.isEmpty {
                                                        if !self.parse(rawURL).keys.contains("signature") {
                                                            if let rawSignature = raw["sig"] as? String, !rawSignature.isEmpty {
                                                                rawURL = String(format:"%@signature=%@", rawURL, rawSignature)
                                                            }
                                                        }
                                                        if let streamURL = URL(string: rawURL) {
                                                            extractionQuality = enumQuality
                                                            extractionURL = streamURL
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // ----------------------------------------------------
                        
                        synchronous.signal()
                    }
                    task.resume()
                    _ = synchronous.wait(timeout: .now() + 60)
                }
                
                if let extraction = extractionURL, !extraction.absoluteString.isEmpty, extractionQuality.order > YouTubeExtractorVideoQuality.none.order {
                    break
                }
            }
        }
        
        // ----------------------------------------------------
        
        // Background Thread
        //DispatchQueue.global(qos: .background).async { }
        
        // Run UI Updates or call completion block
        //DispatchQueue.main.async { }
        
        print(extractionURL)
        print(extractionQuality)
        completion(extractionURL)
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
