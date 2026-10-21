import Foundation

/// The path a shot takes, for the replay after a ball is graded.
///
/// A pure function of the shot, the contact and the landing point, so the
/// replay can be tested without SceneKit: every correct shot must clear the
/// net, and an attack on a ball below the net must not.
struct ShotFlight: Equatable, Sendable {
    struct Sample: Equatable, Sendable {
        let point: CourtPoint
        let height: Double
    }

    let samples: [Sample]
    /// True when the path ends in the net rather than on the far court.
    let endsInNet: Bool
    /// Seconds the replay takes to fly the path. Pace is most of what tells a
    /// drive from a drop, so it varies by shot rather than being one constant.
    var airTime: Double = 1.0

    static let netHeight = 34.0 / 12.0
    static let sampleCount = 28

    /// - Parameters:
    ///   - intoNet: draw the shot the way it actually goes wrong, into the
    ///     tape, instead of a clean arc to its target.
    static func make(
        _ shot: Shot,
        from contact: CourtPoint,
        contactHeight: Double,
        to landing: CourtPoint,
        intoNet: Bool = false
    ) -> ShotFlight {
        if intoNet {
            return netted(from: contact, contactHeight: contactHeight, toward: landing)
        }
        // Resting height of the replay ball's centre, so it sits on the court
        // rather than half sunk into it.
        let end = restingHeight
        let apex = apexHeight(for: shot.type, contactHeight: contactHeight)
        var flight = ShotFlight(
            samples: arc(from: contact, h0: contactHeight, to: landing, h1: end, apex: apex).samples,
            endsInNet: false,
            airTime: airTime(for: shot.type)
        )
        // Lift the arc until it clears the tape. A replay of the right answer
        // that clips the net would teach the opposite of the lesson.
        var lifted = apex
        while (flight.heightAtNet ?? .infinity) < netHeight + 0.35, lifted < 30 {
            lifted += 0.5
            flight = ShotFlight(
                samples: arc(from: contact, h0: contactHeight, to: landing, h1: end, apex: lifted).samples,
                endsInNet: false,
                airTime: flight.airTime
            )
        }
        return flight
    }

    /// The replay ball's radius in feet, and so the height its centre rests at.
    static let restingHeight = 0.17

    /// How high the ball peaks, by shot shape, in feet.
    ///
    /// Kept below what a real drop or lob reaches: the first-person camera is
    /// framed on the court, so a true 17 ft lob leaves the top of the screen
    /// and its flight is lost under the HUD. The shapes stay distinct.
    static func apexHeight(for type: ShotType, contactHeight h: Double) -> Double {
        switch type {
        case .dink: return max(h, netHeight) + 0.9
        case .reset: return max(h, netHeight) + 1.1
        case .drop: return max(h + 2.2, 6.2)
        case .deepReturn: return max(h + 3, 7.5)
        case .lob: return 10.5
        case .drive, .speedUp: return max(h, netHeight + 0.7) + 0.4
        case .putAway: return h
        }
    }

    /// Seconds in the air, by shot shape: a drive is on you before a drop has
    /// finished rising.
    static func airTime(for type: ShotType) -> Double {
        switch type {
        case .putAway: return 0.5
        case .drive, .speedUp: return 0.6
        case .dink, .reset: return 0.95
        case .drop: return 1.1
        case .deepReturn: return 1.15
        case .lob: return 1.45
        }
    }

    /// A ball hit hard off a low contact: it rises a little and dies in the tape.
    private static func netted(from contact: CourtPoint, contactHeight: Double, toward landing: CourtPoint) -> ShotFlight {
        let dy = landing.y - contact.y
        let fraction = dy == 0 ? 1 : (CourtGeometry.netY - contact.y) / dy
        let netPoint = CourtPoint(
            x: contact.x + (landing.x - contact.x) * fraction,
            y: CourtGeometry.netY - 0.15
        )
        let hit = netHeight * 0.72
        let samples = (0..<sampleCount).map { i -> Sample in
            let t = Double(i) / Double(sampleCount - 1)
            let point = CourtPoint(
                x: contact.x + (netPoint.x - contact.x) * t,
                y: contact.y + (netPoint.y - contact.y) * t
            )
            let rise = 0.6 * 4 * t * (1 - t)
            return Sample(point: point, height: contactHeight + (hit - contactHeight) * t + rise)
        }
        return ShotFlight(samples: samples, endsInNet: true, airTime: 0.55)
    }

    private struct Arc {
        let samples: [Sample]
    }

    /// A parabola from contact to landing that peaks at `apex` halfway along.
    private static func arc(from a: CourtPoint, h0: Double, to b: CourtPoint, h1: Double, apex: Double) -> Arc {
        let mid = (h0 + h1) / 2
        let bulge = 4 * max(0, apex - mid)
        func height(_ t: Double) -> Double { h0 + (h1 - h0) * t + bulge * t * (1 - t) }
        let samples = (0..<sampleCount).map { i -> Sample in
            let t = Double(i) / Double(sampleCount - 1)
            let point = i == sampleCount - 1
                ? b
                : CourtPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            return Sample(point: point, height: height(t))
        }
        return Arc(samples: samples)
    }

    /// The same path with the part of its arc above the straight line from
    /// contact to landing scaled by `factor`, so a high arc can be fitted to
    /// what the camera shows. A netted path is left alone.
    func flattened(by factor: Double) -> ShotFlight {
        guard !endsInNet, let first = samples.first, let last = samples.last, samples.count > 1 else {
            return self
        }
        let span = Double(samples.count - 1)
        let scaled = samples.enumerated().map { index, sample -> Sample in
            let t = Double(index) / span
            let line = first.height + (last.height - first.height) * t
            return Sample(point: sample.point, height: line + (sample.height - line) * factor)
        }
        return ShotFlight(samples: scaled, endsInNet: false, airTime: airTime)
    }

    /// The flattest version of this path, between `factor` 1 and 0, that
    /// `fits`, but never one that drops into the net: a replay must not
    /// teach that a shot over the tape would have hit it.
    func fitted(_ fits: (ShotFlight) -> Bool) -> ShotFlight {
        guard !endsInNet, !fits(self) else { return self }
        var low = 0.0, high = 1.0
        for _ in 0..<12 {
            let mid = (low + high) / 2
            if fits(flattened(by: mid)) { low = mid } else { high = mid }
        }
        var factor = low
        var flight = flattened(by: factor)
        let clearance = Self.netHeight + 0.2
        while (flight.heightAtNet ?? .infinity) < clearance, factor < 1 {
            factor = min(1, factor + 0.05)
            flight = flattened(by: factor)
        }
        return flight
    }

    /// Height of the path where it crosses the net plane, interpolated
    /// between the two samples either side of it.
    var heightAtNet: Double? {
        guard let index = samples.firstIndex(where: { $0.point.y >= CourtGeometry.netY }) else {
            return nil
        }
        guard index > 0 else { return samples[index].height }
        let a = samples[index - 1], b = samples[index]
        let span = b.point.y - a.point.y
        let t = span == 0 ? 0 : (CourtGeometry.netY - a.point.y) / span
        return a.height + (b.height - a.height) * t
    }
}
