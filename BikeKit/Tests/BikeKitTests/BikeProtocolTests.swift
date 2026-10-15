import Foundation
import Testing
@testable import BikeKit

struct BikeProtocolTests {
    @Test func settingsFrameMatchesOriginalLayout() {
        let s = BikeSettings(mode: 3, assist: 2, light: true)
        #expect([UInt8](s.frame) == [0x00, 0xD1, 0x01, 0x02, 0x03, 0, 0, 0, 0, 0])
    }

    @Test func modeAndAssistWrapAround() {
        let s = BikeSettings(mode: 7, assist: 4, light: false)
        #expect(s.nextMode().mode == 0)
        #expect(s.nextAssist().assist == 0)
        #expect(BikeSettings(mode: 99, assist: -1, light: false) == BikeSettings(mode: 7, assist: 0, light: false))
    }

    @Test func decodesSettings() {
        // id 03 00 | assist 2 | walk byte 0 (= walk on) | light 1 | mode 5
        let f = BikeFrame(Data([0x03, 0x00, 0x02, 0x00, 0x01, 0x05, 0, 0, 0, 0]))
        #expect(f == .settings(BikeSettings(mode: 5, assist: 2, light: true), walk: true))
    }

    @Test func decodesMotionLittleEndian() {
        // 0x0992 = 2450 → 24.5 km/h
        #expect(BikeFrame(Data([0x02, 0x01, 0x92, 0x09, 0, 0, 0, 0, 0, 0])) == .motion(speed: 24.5))
    }

    @Test func decodesTotalRidePower() {
        #expect(BikeFrame(Data([0x02, 0x02, 0, 0, 0, 0, 0x10, 0x27, 0, 0])) == .total(odometer: 1000))
        #expect(BikeFrame(Data([0x02, 0x03, 0, 12, 0, 0, 0, 0, 45, 0])) == .ride(pedalRPM: 60, rawRange: 45))
        // Real notifier value from the repo's BLE dump: 04 01 90 95 00 00 BD FF FF FF
        #expect(BikeFrame(Data([0x04, 0x01, 0x90, 0x95, 0x00, 0x00, 0xBD, 0xFF, 0xFF, 0xFF])) == .power(chargeCurrent: 65.469))
    }

    @Test func rejectsWrongLengthAndFlagsUnknown() {
        #expect(BikeFrame(Data([0x02, 0x01])) == nil)
        #expect(BikeFrame(Data([0x00, 0x00, 0, 0, 0, 0, 0, 0, 0, 0])) == .unknown(id: [0, 0]))
    }

    @Test func derivedValues() {
        var t = BikeTelemetry()
        t.apply(.ride(pedalRPM: 0, rawRange: 30))
        t.apply(.motion(speed: 32.2))
        var p = RidePrefs()
        p.realMaxRangeKm = 90
        #expect(t.batteryLevel(p) == 0.5)
        #expect(t.rangeKm(p) == 45)
        #expect(abs(t.wheelRPM(p) - 299.7) < 0.1)
        t.apply(.ride(pedalRPM: 0, rawRange: 200))
        #expect(t.batteryLevel(p) == 1)
    }

    @Test func dischargeCurveHitsKeys() {
        let c = DischargeCurve.liIon
        #expect(abs(c.cellVolts(at: 0) - 2.8) < 1e-9)
        #expect(abs(c.cellVolts(at: 0.2) - 3.7) < 1e-9)
        #expect(abs(c.cellVolts(at: 1) - 4.2) < 1e-9)
        #expect(abs(c.cellVolts(at: 2) - 4.2) < 1e-9)
        let mid = c.cellVolts(at: 0.5)
        #expect(mid > 3.7 && mid < 3.76)
    }
}
