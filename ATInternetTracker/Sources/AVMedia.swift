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
//  AVMedia.swift
//  Tracker
//
import Foundation

public class AVMedia: RequiredPropertiesDataObject {
    
    fileprivate let DefaultHeartbeatDuration = 5.0
    fileprivate let avSynchronizer = DispatchQueue(label: "AVSynchronizer")
    var heartbeatDurations = [0:5, 1:15, 5:30, 10: 60]

    var heartbeatTimer : Timer? = nil
    
    var sessionId: String = Foundation.UUID().uuidString
    var previousEvent: String = ""
    var previousCursorPositionMillis: Int = 0
    var currentCursorPositionMillis: Int = 0
    var eventDurationMillis: Int = 0
    var sessionDurationMillis: Int = 0
    var startSessionTimeMillis: Int = 0
    var bufferTimeMillis: Int = 0
    var isPlaying: Bool = false
    
    var events : Events?
    
    @objc public lazy var content : Content = Content()
    
    @objc public lazy var player : Player = Player()
    
    init(events: Events?) {
        self.events = events
        super.init()
    
        /// STRING
        propertiesPrefixMap["broadcasting_type"] = "s"
        propertiesPrefixMap["ad_type"] = "s"
        propertiesPrefixMap["position"] = "s"
        propertiesPrefixMap["show"] = "s"
        propertiesPrefixMap["show_season"] = "s"
        propertiesPrefixMap["episode_id"] = "s"
        propertiesPrefixMap["episode"] = "s"
        propertiesPrefixMap["channel"] = "s"
        propertiesPrefixMap["author"] = "s"
        propertiesPrefixMap["broadcaster"] = "s"
        
        /// DATE
        propertiesPrefixMap["publication_date"] = "d"

        /// BOOLEAN
        propertiesPrefixMap["auto_mode"] = "b"
    }
    
    @objc public func setHeartbeat(heartbeat: Int) -> AVMedia {
        self.avSynchronizer.sync {
            if heartbeat < 5 {
                self.heartbeatDurations = [0:5]
            } else {
                self.heartbeatDurations = [0:heartbeat]
            }
            return self
        }
    }
    
    @objc(setHeartbeatWithDictionary:)
    public func setHeartbeat(heartbeat: [Int: Int]) -> AVMedia {
        guard heartbeat.count > 0 else { return self }
        self.avSynchronizer.sync {
            self.heartbeatDurations.removeAll()
            for (k,v) in heartbeat {
                if v < 5 {
                    self.heartbeatDurations[k] = 5
                } else {
                    self.heartbeatDurations[k] = v
                }
            }
            if !self.heartbeatDurations.keys.contains(0) {
               self.heartbeatDurations[0] = 5
            }
        }
        return self
    }
    
    @objc public func heartbeat() {
        self.avSynchronizer.sync {
            self.startSessionTimeMillis = self.startSessionTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.startSessionTimeMillis
            
            if self.isPlaying {
                self.updateDuration()
                
                self.previousCursorPositionMillis = self.currentCursorPositionMillis
                self.currentCursorPositionMillis += self.eventDurationMillis
                
                stopHeartbeatTimer()
                
                let diffMin = (Int(Date().timeIntervalSince1970 * 1000) - self.startSessionTimeMillis) / 60000
                if let duration = self.heartbeatDurations[diffMin] {
                    heartbeatTimer = Timer.scheduledTimer(timeInterval: TimeInterval(duration), target: self, selector: #selector(self.heartbeat), userInfo: nil, repeats: false)
                } else {
                    heartbeatTimer = Timer.scheduledTimer(timeInterval: DefaultHeartbeatDuration, target: self, selector: #selector(self.heartbeat), userInfo: nil, repeats: false)
                }
                sendEvent(name: "av.heartbeat", withOptions: true)
            }
        }
    }
    
    @objc public func bufferHeartbeat() {
        self.avSynchronizer.sync {
            self.startSessionTimeMillis = self.startSessionTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.startSessionTimeMillis
            
            if !self.isPlaying {
                self.updateDuration()
                
                stopHeartbeatTimer()
                
                self.bufferTimeMillis = self.bufferTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.bufferTimeMillis
                let diffMin = (Int(Date().timeIntervalSince1970 * 1000) - self.bufferTimeMillis) / 60000
                if let duration = self.heartbeatDurations[diffMin] {
                    heartbeatTimer = Timer.scheduledTimer(timeInterval: TimeInterval(duration), target: self, selector: #selector(self.bufferHeartbeat), userInfo: nil, repeats: false)
                } else {
                    heartbeatTimer = Timer.scheduledTimer(timeInterval: DefaultHeartbeatDuration, target: self, selector: #selector(self.bufferHeartbeat), userInfo: nil, repeats: false)
                }
                sendEvent(name: "av.buffer.heartbeat", withOptions: true)
            }
        }
    }
    
    @objc public func rebufferHeartbeat() {
        self.avSynchronizer.sync {
            self.startSessionTimeMillis = self.startSessionTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.startSessionTimeMillis
            
            if self.isPlaying {
                self.updateDuration()
                
                self.previousCursorPositionMillis = self.currentCursorPositionMillis
                
                stopHeartbeatTimer()
                
                self.bufferTimeMillis = self.bufferTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.bufferTimeMillis
                let diffMin = (Int(Date().timeIntervalSince1970 * 1000) - self.bufferTimeMillis) / 60000
                if let duration = self.heartbeatDurations[diffMin] {
                    heartbeatTimer = Timer.scheduledTimer(timeInterval: TimeInterval(duration), target: self, selector: #selector(self.bufferHeartbeat), userInfo: nil, repeats: false)
                } else {
                    heartbeatTimer = Timer.scheduledTimer(timeInterval: DefaultHeartbeatDuration, target: self, selector: #selector(self.bufferHeartbeat), userInfo: nil, repeats: false)
                }
                sendEvent(name: "av.rebuffer.heartbeat", withOptions: true)
            }
        }
    }
    
    @objc public func play(cursorPosition: Int) {
        self.avSynchronizer.sync {
            self.startSessionTimeMillis = self.startSessionTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.startSessionTimeMillis
            
            self.eventDurationMillis = 0
            
            self.previousCursorPositionMillis = cursorPosition
            self.currentCursorPositionMillis = cursorPosition
            
            self.isPlaying = false
            
            stopHeartbeatTimer()
            
            sendEvent(name: "av.play", withOptions: true)
        }
    }
    
    @objc public func bufferStart(cursorPosition: Int) {
        self.avSynchronizer.sync {
            self.startSessionTimeMillis = self.startSessionTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.startSessionTimeMillis
            
            self.updateDuration()
            self.previousCursorPositionMillis = self.currentCursorPositionMillis
            self.currentCursorPositionMillis = cursorPosition
            
            self.bufferTimeMillis = Int(Date().timeIntervalSince1970 * 1000)
            
            stopHeartbeatTimer()
            
            if self.isPlaying {
                heartbeatTimer = Timer.scheduledTimer(timeInterval: DefaultHeartbeatDuration, target: self, selector: #selector(self.rebufferHeartbeat), userInfo: nil, repeats: false)
                sendEvent(name: "av.rebuffer.start", withOptions: true)
            } else {
                heartbeatTimer = Timer.scheduledTimer(timeInterval: DefaultHeartbeatDuration, target: self, selector: #selector(self.bufferHeartbeat), userInfo: nil, repeats: false)
                sendEvent(name: "av.buffer.start", withOptions: true)
            }
        }
    }
    
    @objc public func playbackStart(cursorPosition: Int) {
        self.avSynchronizer.sync {
            self.startSessionTimeMillis = self.startSessionTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.startSessionTimeMillis
            
            self.updateDuration()
            self.previousCursorPositionMillis = cursorPosition
            self.currentCursorPositionMillis = cursorPosition
            
            self.isPlaying = true
            
            stopHeartbeatTimer()
            heartbeatTimer = Timer.scheduledTimer(timeInterval: DefaultHeartbeatDuration, target: self, selector: #selector(self.heartbeat), userInfo: nil, repeats: false)
            sendEvent(name: "av.start", withOptions: true)
        }
    }
    
    @objc public func playbackResumed(cursorPosition: Int) {
        self.avSynchronizer.sync {
            self.startSessionTimeMillis = self.startSessionTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.startSessionTimeMillis
            
            self.updateDuration()
            self.previousCursorPositionMillis = self.currentCursorPositionMillis
            self.currentCursorPositionMillis = cursorPosition
            
            self.isPlaying = true
            
            stopHeartbeatTimer()
            heartbeatTimer = Timer.scheduledTimer(timeInterval: DefaultHeartbeatDuration, target: self, selector: #selector(self.heartbeat), userInfo: nil, repeats: false)
            sendEvent(name: "av.resume", withOptions: true)
        }
    }
    
    @objc public func playbackPaused(cursorPosition: Int) {
        self.avSynchronizer.sync {
            self.startSessionTimeMillis = self.startSessionTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.startSessionTimeMillis
            
            self.updateDuration()
            self.previousCursorPositionMillis = self.currentCursorPositionMillis
            self.currentCursorPositionMillis = cursorPosition
            
            self.isPlaying = false
            
            stopHeartbeatTimer()
            sendEvent(name: "av.pause", withOptions: true)
        }
    }
    
    @objc public func playbackStopped(cursorPosition: Int) {
        self.avSynchronizer.sync {
            self.startSessionTimeMillis = self.startSessionTimeMillis == 0 ? Int(Date().timeIntervalSince1970 * 1000) : self.startSessionTimeMillis
            
            self.updateDuration()
            self.previousCursorPositionMillis = self.currentCursorPositionMillis
            self.currentCursorPositionMillis = cursorPosition
            
            self.isPlaying = false
            
            stopHeartbeatTimer()
            self.startSessionTimeMillis = 0
            self.sessionDurationMillis = 0
            self.bufferTimeMillis = 0
            
            sendEvent(name: "av.stop", withOptions: true)
            
            self.resetState()
        }
    }
    
    @objc public func seek(oldCursorPosition: Int, newCursorPosition: Int) {
        if oldCursorPosition > newCursorPosition {
            self.seekBackward(oldCursorPosition: oldCursorPosition, newCursorPosition: newCursorPosition)
        } else {
            self.seekForward(oldCursorPosition: oldCursorPosition, newCursorPosition: newCursorPosition)
        }
    }
    
    @objc public func seekBackward(oldCursorPosition: Int, newCursorPosition: Int) {
        self.avSynchronizer.sync {
            self.processSeek(seekDirection: "backward", oldCursorPosition: oldCursorPosition, newCursorPosition: newCursorPosition)
        }
    }
    
    @objc public func seekForward(oldCursorPosition: Int, newCursorPosition: Int) {
        self.avSynchronizer.sync {
            self.processSeek(seekDirection: "forward", oldCursorPosition: oldCursorPosition, newCursorPosition: newCursorPosition)
        }
    }
    
    @objc public func seekStart(oldCursorPosition: Int) {
        self.avSynchronizer.sync {
            if self.isPlaying && self.startSessionTimeMillis == 0 {
                self.startSessionTimeMillis = Int(Date().timeIntervalSince1970 * 1000)
            }
            
            self.previousCursorPositionMillis = self.currentCursorPositionMillis
            self.currentCursorPositionMillis = oldCursorPosition
            
            if isPlaying {
                self.updateDuration()
            } else {
                self.eventDurationMillis = 0
            }
            
            self.sendEvent(name: "av.seek.start", withOptions: true)
        }
    }
    
    @objc public func adClick() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.ad.click", withOptions: false)
       }
    }
    
    @objc public func adSkip() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.ad.skip", withOptions: false)
       }
    }
    
    @objc public func error(message: String) {
       self.avSynchronizer.sync {
            _ = self.player.set(key: "error", value: message, propertyType: RequiredPropertiesDataObjectPropertyType.string )
            self.sendEvent(name: "av.error", withOptions: false)
       }
    }
    
    @objc public func display() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.display", withOptions: false)
       }
    }
    
    @objc public func close() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.close", withOptions: false)
       }
    }
    
    @objc public func volume() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.volume", withOptions: false)
       }
    }
    
    @objc public func subtitleOn() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.subtitle.on", withOptions: false)
       }
    }
    
    @objc public func subtitleOff() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.subtitle.off", withOptions: false)
       }
    }
    
    @objc public func fullscreenOn() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.fullscreen.on", withOptions: false)
       }
    }
    
    @objc public func fullscreenOff() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.fullscreen.off", withOptions: false)
       }
    }
    
    @objc public func quality() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.quality", withOptions: false)
       }
    }
    
    @objc public func speed() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.speed", withOptions: false)
       }
    }
    
    @objc public func share() {
       self.avSynchronizer.sync {
           self.sendEvent(name: "av.share", withOptions: false)
       }
    }
    
    private func processSeek(seekDirection: String, oldCursorPosition: Int, newCursorPosition: Int) {
        if self.isPlaying && self.startSessionTimeMillis == 0 {
            self.startSessionTimeMillis = Int(Date().timeIntervalSince1970 * 1000)
        }
        
        self.seekStart(oldCursorPosition: oldCursorPosition)
        
        self.eventDurationMillis = 0
        self.previousCursorPositionMillis = oldCursorPosition
        self.currentCursorPositionMillis = newCursorPosition
        
        self.sendEvent(name: "av." + seekDirection, withOptions: true)
    }
    
    private func updateDuration() {
        self.eventDurationMillis = Int(Date().timeIntervalSince1970 * 1000) - self.startSessionTimeMillis - self.sessionDurationMillis
        self.sessionDurationMillis += self.eventDurationMillis
    }
    
    private func stopHeartbeatTimer() {
        guard heartbeatTimer != nil else { return }
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func resetState() {
        self.sessionId = Foundation.UUID().uuidString
        self.previousEvent = ""
        self.previousCursorPositionMillis = 0
        self.currentCursorPositionMillis = 0
        self.eventDurationMillis = 0
    }
    
    private func sendEvent(name: String, withOptions: Bool) {
        if withOptions{
            _ = set(key: "previous_position", value: self.previousCursorPositionMillis, propertyType: RequiredPropertiesDataObjectPropertyType.number)
                .set(key: "position", value: self.currentCursorPositionMillis, propertyType: RequiredPropertiesDataObjectPropertyType.number)
                .set(key: "duration", value: self.eventDurationMillis, propertyType: RequiredPropertiesDataObjectPropertyType.number)
                .set(key: "previous_event", value: self.previousEvent, propertyType: RequiredPropertiesDataObjectPropertyType.string)
            
            self.previousEvent = name
        }
        _ = set(key: "session_id", value: self.sessionId, propertyType: RequiredPropertiesDataObjectPropertyType.string)
        _ = self.events!.add(event: AVEvent(name: name, media: AVMedia(events: nil).copyAll(src: self), content: Content().copyAll(src: self.content), player: Player().copyAll(src: self.player)))
        self.events!.send()
    }
}
