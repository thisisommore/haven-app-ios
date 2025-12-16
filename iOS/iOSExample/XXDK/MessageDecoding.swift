//
//  MessageDecoding.swift
//  iOSExample
//
//  Created by Om More on 25/09/25.
//

import Compression
import Foundation

/// Decompress zlib-compressed data.
/// This implementation skips the 2-byte zlib header before calling `compression_decode_buffer`.
/// - Parameter data: The input data that is expected to be zlib-compressed.
/// - Returns: The decompressed payload, or `nil` if decompression fails.
func decompressZlib(_ data: Data) -> Data? {
    // Skip zlib header (2 bytes)
    let headerSize = 2
    guard data.count > headerSize else { return nil }

    // Use a larger buffer to handle various compression ratios
    let bufferSize = max(data.count * 4, 1024)
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    let result = data.subdata(in: headerSize ..< data.count).withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else { return 0 }
        return compression_decode_buffer(
            buffer, bufferSize,
            baseAddress.bindMemory(to: UInt8.self, capacity: 1),
            data.count - headerSize,
            nil,
            COMPRESSION_ZLIB
        )
    }

    guard result > 0 else { return nil }

    return Data(bytes: buffer, count: result)
}

/// Decode a message that may be base64-wrapped, optionally UTF-8 directly,
/// or zlib-compressed UTF-8 payload.
/// - Parameter b64: Base64-encoded string.
/// - Returns: The decoded UTF-8 string if successful, otherwise `nil`.
func decodeMessage(_ b64: String) -> String? {
    print("[MessageDecoding] Input base64: \(b64.prefix(50))...")

    // Convert base64 to Data
    guard let data = Data(base64Encoded: b64) else {
        print("[MessageDecoding] Failed to decode base64")
        return nil
    }

    print("[MessageDecoding] Base64 decoded to \(data.count) bytes")

    // Try direct UTF-8 decoding first
    if let utf8String = String(data: data, encoding: .utf8) {
        print("[MessageDecoding] Direct UTF-8 decode: \(utf8String)")
        return utf8String
    }

    // Check if it looks like zlib/deflate (starts with 0x78)
    if data.count > 0, data[0] == 0x78 {
        print("[MessageDecoding] Attempting zlib decompression")
        if let decompressed = decompressZlib(data),
           let utf8String = String(data: decompressed, encoding: .utf8)
        {
            return utf8String
        }
    }

    print("[MessageDecoding] All decoding methods failed")
    return nil
}

/// Debug helper to print out decoding attempts for an example payload.
func decodeAny(b64: String = "eJyzKbBLz03PtdEvsAMAFoYDrA==") {
    guard let data = Data(base64Encoded: b64) else {
        print("Failed to decode base64")
        return
    }

    print("Base64 bytes: \(data.count)")

    if let utf8String = String(data: data, encoding: .utf8) {
        print("UTF-8 (direct): \(utf8String)")
    }

    if data.count > 0, data[0] == 0x78 {
        if let decompressed = decompressZlib(data) {
            if let utf8String = String(data: decompressed, encoding: .utf8) {
                print("Inflated UTF-8: \(utf8String)")
            }
        } else {
            print("Inflate failed: Could not decompress zlib data")
        }
    }
}
