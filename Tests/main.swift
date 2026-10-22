// Run: swiftc Barefoot/OkokPacket.swift Tests/main.swift -o /tmp/dt && /tmp/dt
// Frames built per openScale's OkOkHandler; company id is little-endian on the wire.
import Foundation

func test() {
    func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }
    func frame(_ company: UInt16, _ payload: [UInt8]) -> Data {
        Data([UInt8(company & 0xFF), UInt8(company >> 8)] + payload)
    }

    // V20: settled flag + 2-decimal divider, 67.05 kg
    var v20 = [UInt8](repeating: 0, count: 19)
    v20[6] = 0x05; v20[8] = 0x1A; v20[9] = 0x31
    v20[12] = { var c: UInt8 = 0x20; for i in 0..<12 { c ^= v20[i] }; return c }()
    var r = OkokPacket.decode(frame(0x20CA, v20))!
    assert(close(r.kg, 67.05) && r.stable, "v20 \(r)")

    // unstable frame is ignored
    var unstable = v20
    unstable[6] = 0x04
    unstable[12] = { var c: UInt8 = 0x20; for i in 0..<12 { c ^= unstable[i] }; return c }()
    assert(OkokPacket.decode(frame(0x20CA, unstable)) == nil, "unstable")

    // corrupted checksum is rejected
    var bad = v20
    bad[12] ^= 0xFF
    assert(OkokPacket.decode(frame(0x20CA, bad)) == nil, "checksum")

    // V11: 2-decimal divider, kg, 67.05 kg
    var v11 = [UInt8](repeating: 0, count: 23)
    v11[3] = 0x1A; v11[4] = 0x31; v11[9] = 0x04
    v11[16] = { var c: UInt8 = 0xCA ^ 0x11; for i in 0..<16 { c ^= v11[i] }; return c }()
    r = OkokPacket.decode(frame(0x11CA, v11))!
    assert(close(r.kg, 67.05), "v11 \(r)")

    // V11 in pounds: 147.7 lb -> 67.0 kg (divider 10, unit bits 10 -> props 0x10)
    var lb = v11
    lb[3] = 0x05; lb[4] = 0xC5
    lb[9] = 0x10
    lb[16] = { var c: UInt8 = 0xCA ^ 0x11; for i in 0..<16 { c ^= lb[i] }; return c }()
    r = OkokPacket.decode(frame(0x11CA, lb))!
    assert(close(r.kg, 1477.0 / 10 / 2.2046226218), "v11 lb \(r)")

    // VF0: msb/lsb swapped relative to the others, 67.0 kg
    r = OkokPacket.decode(frame(0xF0FF, [0x00, 0x00, 0x9E, 0x02]))!
    assert(close(r.kg, 67.0), "vf0 \(r)")

    // C0: stable + 2-decimal divider, 67.05 kg
    var c0 = [UInt8](repeating: 0, count: 13)
    c0[0] = 0x1A; c0[1] = 0x31; c0[6] = 0x05
    r = OkokPacket.decode(frame(0xFFC0, c0))!
    assert(close(r.kg, 67.05) && r.stable, "c0 \(r)")

    // not an OKOK scale (Apple company id) must be ignored
    assert(OkokPacket.decode(frame(0x004C, [0x02, 0x15])) == nil, "apple")

    // truncated
    assert(OkokPacket.decode(Data()) == nil, "empty")
    assert(OkokPacket.decode(Data([0xCA, 0x20])) == nil, "header only")

    print("decode ok")
}

test()
