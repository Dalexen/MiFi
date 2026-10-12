import Foundation

/// Networks are stored on GitHub in one JSON file per geohash tile (data/tiles/<hash>.json).
/// `tilePrecision` must match PRECISION in scripts/ingest.py.
enum Geohash {
    static let tilePrecision = 5
    /// A precision-5 cell is 360/8192 degrees wide and 180/4096 degrees tall (~4.9 km).
    static let tileSizeDegrees = 360.0 / 8192.0

    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    static func encode(lat: Double, lon: Double, precision: Int = tilePrecision) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var hash = ""
        var bits = 0
        var bit = 0
        var even = true
        while hash.count < precision {
            if even {
                let mid = (lonRange.0 + lonRange.1) / 2
                if lon >= mid { bit = bit * 2 + 1; lonRange.0 = mid } else { bit = bit * 2; lonRange.1 = mid }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if lat >= mid { bit = bit * 2 + 1; latRange.0 = mid } else { bit = bit * 2; latRange.1 = mid }
            }
            even.toggle()
            bits += 1
            if bits == 5 {
                hash.append(base32[bit])
                bits = 0
                bit = 0
            }
        }
        return hash
    }

    /// The tile containing the point plus its eight neighbours.
    static func tiles(around lat: Double, lon: Double) -> [String] {
        var result: [String] = []
        for dLat in -1...1 {
            for dLon in -1...1 {
                let la = min(max(lat + Double(dLat) * tileSizeDegrees, -89.999), 89.999)
                var lo = lon + Double(dLon) * tileSizeDegrees
                if lo > 179.999 { lo -= 360 }
                if lo < -179.999 { lo += 360 }
                let h = encode(lat: la, lon: lo)
                if !result.contains(h) { result.append(h) }
            }
        }
        return result
    }
}
