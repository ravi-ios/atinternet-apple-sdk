/*
 This SDK is licensed under the MIT license (MIT)
 Copyright (c) 2015- Applied Technologies Internet SAS (registration number B 403 261 258 - Trade and Companies Register of Bordeaux – France)
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */





//
//  AVEvent.swift
//  Tracker
//
import Foundation

public class AVEvent : Event {

    @objc public var media : RequiredPropertiesDataObject
    @objc public var content : RequiredPropertiesDataObject
    @objc public var player : RequiredPropertiesDataObject
   
    override var data: [String : Any] {
        get {
            var m = [String : Any]()
            if !content.properties.isEmpty {
                m["content"] = content.properties
            }
            if !player.properties.isEmpty {
                m["player"] = player.properties
            }
            for (k, v) in media.properties {
                m[k] = v
            }
            _data["av"] = m
            return super.data
        }
    }
   
    init(name: String, media: RequiredPropertiesDataObject, content: RequiredPropertiesDataObject, player: RequiredPropertiesDataObject) {
        self.media = media
        self.content = content
        self.player = player
        super.init(name: name)
    }
}
