import AVFoundation

extension AVAsset {
    func getNextInterestingTime(after currentTime: CMTime) async throws -> CMTime {
        // below .zero? next interesting time is .zero
        if currentTime < .zero {
            return .zero
        }

        // pin at asset.duration
        let duration = try await self.load(.duration)
        if currentTime >= duration {
            return duration
        }
        
        var interestingTimeForTrack: [CMTime] = []
        
        // getNextInterestingTime for each media type found
        let tracks = try await self.load(.tracks)
        for track in tracks {
            if track.mediaType == .audio {
                // do a 0.25 second step forward
                interestingTimeForTrack.append(
                    currentTime + CMTime(value: 1, timescale: 4)
                )
            }
            else {
                // do an AVTrackSampleCursor step forward
                let cursor = await track.makeTrackSampleCursor(presentationTimeStamp: currentTime)
                cursor.stepInPresentationOrder(byCount: 1)
                if cursor.presentationTimeStamp > currentTime {
                    // some tracks (cough, timecode) only have one sample,
                    // and that isn't often interesting, and sometimes is
                    // in the wrong direction.
                    interestingTimeForTrack.append(cursor.presentationTimeStamp)
                }
            }
        }
        
        // return the minimum interesting time (that will be the closest to currentTime)
        return interestingTimeForTrack.min() ?? currentTime
    }
    
    func getPreviousInterestingTime(before currentTime: CMTime) async throws -> CMTime? {
        // pin at .zero
        if currentTime <= .zero {
            return .zero
        }

        // above asset.duration? previous interesting time is asset.duration
        let duration = try await self.load(.duration)
        if currentTime > duration {
            return duration
        }
        
        var interestingTimeForTrack: [CMTime] = []
        
        // getNextInterestingTime for each media type found
        let tracks = try await self.load(.tracks)
        for track in tracks {
            if track.mediaType == .audio {
                // do a 0.25 second step backward
                interestingTimeForTrack.append(
                    currentTime - CMTime(value: 1, timescale: 4)
                )
            }
            else {
                // do an AVTrackSampleCursor step backward
                let cursor = await track.makeTrackSampleCursor(presentationTimeStamp: currentTime)
                cursor.stepInPresentationOrder(byCount: -1)
                if cursor.presentationTimeStamp < currentTime {
                    // some tracks (cough, timecode) only have one sample,
                    // and that isn't often interesting, and sometimes is
                    // in the wrong direction.
                    interestingTimeForTrack.append(cursor.presentationTimeStamp)
                }
            }
        }
        
        // return the maximum interesting time (that will be the closest to currentTime)
        return interestingTimeForTrack.max() ?? currentTime
    }
}


extension CMTimeMapping {
    // .source is media time range, .target is track time range (CMTimeMapping header doc says so)
    var mediaTimeRange: CMTimeRange {
        return self.source
    }
    var trackTimeRange: CMTimeRange {
        return self.target
    }
}

class AVAssetTrackSampleCursor: NSObject {
    let track: AVAssetTrack
    var presentationTimeStamp: CMTime
    
    // mapping to media time
    var segments: [AVAssetTrackSegment] = []
    var currSegment: AVAssetTrackSegment?
    var currSegmentIndex: Int?
    var mediaSampleCursor: AVSampleCursor?
    var currMediaTime: CMTime?
    
    
    init(track: AVAssetTrack, presentationTimeStamp: CMTime) async {
        self.track = track
        self.presentationTimeStamp = presentationTimeStamp
        
        do {
            self.segments = try await track.load(.segments)
            self.currSegment = try await track.loadSegment(forTrackTime: presentationTimeStamp)
            if self.currSegment == nil {
                self.currSegmentIndex = nil
                self.currMediaTime = nil
                self.mediaSampleCursor = nil
            }
            else {
                self.currSegmentIndex = self.segments.firstIndex(of: self.currSegment!)
                self.currMediaTime = CMTimeMapTimeFromRangeToRange(
                    presentationTimeStamp,
                    fromRange: self.currSegment!.timeMapping.trackTimeRange,
                    toRange: self.currSegment!.timeMapping.mediaTimeRange
                )
                self.mediaSampleCursor = track.makeSampleCursor(presentationTimeStamp: self.currMediaTime!)
            }
        }
        catch {
            self.currSegment = nil
            self.currSegmentIndex = nil
            self.currMediaTime = nil
            self.mediaSampleCursor = nil
        }
    }
    
    func stepInPresentationOrder(byCount: Int64) {
        if self.mediaSampleCursor == nil || self.currSegment == nil || self.currSegmentIndex == nil {
            return
        }
        
        if byCount == 0 {
            return
        }
        
        let forward: Bool = byCount > 0
        let backward: Bool = !forward
        
        // step the media time by one sample
        self.mediaSampleCursor!.stepInPresentationOrder(byCount: byCount)
        var newMediaTime = self.mediaSampleCursor!.presentationTimeStamp
        
        if newMediaTime == self.currMediaTime {
            // media sample cursor did not move. It must already point to start of last media sample;
            // we should update newMediaTime to end of segment (if backward, to start of segment, of course),
            // and then run through the usual logic, as if the mediaSampleCursor had actually stepped there.
            if forward {
                newMediaTime = self.currSegment!.timeMapping.mediaTimeRange.end
            }
            else {
                newMediaTime = self.currSegment!.timeMapping.mediaTimeRange.start
            }
        }
        
        if (forward && newMediaTime < self.currSegment!.timeMapping.mediaTimeRange.end)
            || (backward && newMediaTime > self.currSegment!.timeMapping.mediaTimeRange.start) {
            // we haven't stepped to edge of current segment yet (normal case)
            let newTrackTime = CMTimeMapTimeFromRangeToRange(
                newMediaTime,
                fromRange: self.currSegment!.timeMapping.mediaTimeRange,
                toRange: self.currSegment!.timeMapping.trackTimeRange
            )
            if newTrackTime == self.presentationTimeStamp {
                // track sample cursor did not move. It must already point to start of last track sample;
                // we should step to end of segment (if backward, we step to start of segment, of course)
                if forward {
                    self.presentationTimeStamp = self.currSegment!.timeMapping.trackTimeRange.end
                    self.currMediaTime = self.currSegment!.timeMapping.mediaTimeRange.end
                }
                else {
                    self.presentationTimeStamp = self.currSegment!.timeMapping.trackTimeRange.start
                    self.currMediaTime = self.currSegment!.timeMapping.mediaTimeRange.start
                }
            }
            else {
                // successful normal step forward or backward; update our timestamps
                self.presentationTimeStamp = newTrackTime
                self.currMediaTime = newMediaTime
            }
        }
        else if forward {
            // handle stepping forward to end of current segment
            if self.currSegmentIndex! < self.segments.count - 1 {
                // step to start of next segment (same PTS as end of current segment)
                self.currSegmentIndex! += 1
                self.currSegment = self.segments[self.currSegmentIndex!]
                self.currMediaTime = self.currSegment!.timeMapping.mediaTimeRange.start
                self.presentationTimeStamp = self.currSegment!.timeMapping.trackTimeRange.start
                self.mediaSampleCursor = self.track.makeSampleCursor(presentationTimeStamp: self.currMediaTime!)
            }
            else {
                // no next segment, pin at end of current segment (i.e. end of track)
                self.currMediaTime = currSegment!.timeMapping.mediaTimeRange.end
                self.presentationTimeStamp = self.currSegment!.timeMapping.trackTimeRange.end
            }
        }
        else {
            // handle stepping backward to start of current segment
            if self.currSegmentIndex! > 0 {
                // step to end of previous segment (same PTS as start of current segment)
                self.currSegmentIndex! -= 1
                self.currSegment = self.segments[self.currSegmentIndex!]
                self.currMediaTime = self.currSegment!.timeMapping.mediaTimeRange.end
                self.presentationTimeStamp = self.currSegment!.timeMapping.trackTimeRange.end
            }
            else {
                // no previous segment, pin to start of current segment (i.e. start of track)
                self.currMediaTime = self.currSegment!.timeMapping.mediaTimeRange.start
                self.presentationTimeStamp = self.currSegment!.timeMapping.trackTimeRange.start
            }
        }
    }
}

extension AVAssetTrack {
    func makeTrackSampleCursor(presentationTimeStamp: CMTime) async -> AVAssetTrackSampleCursor {
        await .init(track: self, presentationTimeStamp: presentationTimeStamp)
    }
}

enum CMTimeFormat {
    case withFraction
    case withMillisecondsDecimal
    case withMillisecondsDecimalAndFraction
}
extension CMTime {
    func formatted(_ format: CMTimeFormat = .withMillisecondsDecimal) -> String {
        let timeInSeconds = self.seconds
        guard !timeInSeconds.isNaN else {
            return "nan"
        }
        guard !timeInSeconds.isInfinite else {
            return "inf"
        }
 
        var seconds = Int(timeInSeconds)
        let hours = seconds / 3600
        seconds -= hours * 3600
        let minutes = seconds / 60
        seconds -= minutes * 60
    
        switch format {
        case .withFraction:
            return String(format: "%ld/%d", self.value, self.timescale)
        case .withMillisecondsDecimal:
            let millisecs = Int(round((timeInSeconds - Double(Int(timeInSeconds))) * 1000.0))
            if millisecs != 0 {
                return String(format: "%d:%02d:%02d.%03d", hours, minutes, seconds, millisecs)
            }
            else {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            }
        case .withMillisecondsDecimalAndFraction:
            let millisecs = Int(round((timeInSeconds - Double(Int(timeInSeconds))) * 1000.0))
            return String(format: "%d:%02d:%02d.%03d (%ld/%d)", hours, minutes, seconds, millisecs, self.value, self.timescale)
        }
    }
}
