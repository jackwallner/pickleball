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
        let end = 0.12
        let apex = apexHeight(for: shot.type, contactHeight: contactHeight)
        var flight = ShotFlight(
            samples: arc(from: contact, h0: contactHeight, to: landing, h1: end, apex: apex).samples,
            endsInNet: false
        )
        // Lift the arc until it clears the tape. A replay of the right answer
        // that clips the net would teach the opposite of the lesson.
        var lifted = apex
        while (flight.heightAtNet ?? .infinity) < netHeight + 0.35, lifted < 30 {
            lifted += 0.5
            flight = ShotFlight(
                samples: arc(from: contact, h0: contactHeight, to: landing, h1: end, apex: lifted).samples,
                endsInNet: false
            )
        }
        return flight
    }

    /// How high the ball peaks, by shot shape, in feet.
    static func apexHeight(for type: ShotType, contactHeight h: Double) -> Double {
        switch type {
        case .dink: return max(h, netHeight) + 0.9
        case .reset: return max(h, netHeight) + 1.1
        case .drop: return max(h + 3.5, 8.5)
        case .deepReturn: return max(h + 5, 10)
        case .lob: return 17
        case .drive, .speedUp: return max(h, netHeight + 0.7) + 0.4
        case .putAway: return h
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
        return ShotFlight(samples: samples, endsInNet: true)
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
