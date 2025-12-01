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
                var timescale = currentTime.timescale
                if timescale < 30 {
                    timescale = 240000
                }
                interestingTimeForTrack.append(
                    currentTime + CMTime(seconds: 0.25, preferredTimescale: timescale)
                )
            }
            else {
                // do an AVSampleCursor step forward
                let cursor = track.makeSampleCursor(presentationTimeStamp: currentTime)
                cursor!.stepInPresentationOrder(byCount: 1)
                if cursor!.presentationTimeStamp > currentTime {
                    // some tracks (cough, timecode) only have one sample,
                    // and that isn't often interesting, and sometimes is
                    // in the wrong direction.
                    interestingTimeForTrack.append(cursor!.presentationTimeStamp)
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
                var timescale = currentTime.timescale
                if timescale < 30 {
                    timescale = 240000
                }
                interestingTimeForTrack.append(
                    currentTime - CMTime(seconds: 0.25, preferredTimescale: timescale)
                )
            }
            else {
                // do an AVSampleCursor step backward
                let cursor = track.makeSampleCursor(presentationTimeStamp: currentTime)
                cursor!.stepInPresentationOrder(byCount: -1)
                if cursor!.presentationTimeStamp < currentTime {
                    // some tracks (cough, timecode) only have one sample,
                    // and that isn't often interesting, and sometimes is
                    // in the wrong direction.
                    interestingTimeForTrack.append(cursor!.presentationTimeStamp)
                }
            }
        }
        
        // return the maximum interesting time (that will be the closest to currentTime)
        return interestingTimeForTrack.max() ?? currentTime
    }
}
