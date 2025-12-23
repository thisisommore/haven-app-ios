//
//  MessageEncoding.swift
//  iOSExample
//
//  Created by Om More on 25/09/25.
//

import Compression
import Foundation

/// Compress data using zlib compression.
/// This implementation manually adds the zlib header since compression_encode_buffer
/// with COMPRESSION_ZLIB only produces raw DEFLATE data without the zlib wrapper.
/// - Parameter data: The input data to be compressed.
/// - Returns: The compressed data with proper zlib header and checksum, or `nil` if compression fails.
func compressZlib(_ data: Data) -> Data? {
    // Allocate buffer for DEFLATE compression
    let bufferSize = data.count + 32
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    // Compress using DEFLATE (not true zlib)
    let compressedSize = data.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else { return 0 }
        return compression_encode_buffer(
            buffer, bufferSize,
            baseAddress.bindMemory(to: UInt8.self, capacity: 1), data.count,
            nil, COMPRESSION_ZLIB
        )
    }

    guard compressedSize > 0 else { return nil }

    // Create proper zlib format: header + DEFLATE data + ADLER32 checksum
    var result = Data()

    // Add zlib header (2 bytes)
    result.append(0x78) // CMF (Compression Method and flags)
    result.append(0x9C) // FLG (Flags)

    // Add the DEFLATE compressed data
    result.append(Data(bytes: buffer, count: compressedSize))

    // Calculate ADLER32 checksum of original data
    let adler32 = calculateAdler32(data)

    // Add ADLER32 checksum (4 bytes, big-endian)
    result.append(UInt8((adler32 >> 24) & 0xFF))
    result.append(UInt8((adler32 >> 16) & 0xFF))
    result.append(UInt8((adler32 >> 8) & 0xFF))
    result.append(UInt8(adler32 & 0xFF))

    return result
}

/// Calculate ADLER32 checksum for zlib format
/// - Parameter data: Input data to checksum
/// - Returns: ADLER32 checksum value
private func calculateAdler32(_ data: Data) -> UInt32 {
    var a: UInt32 = 1
    var b: UInt32 = 0

    for byte in data {
        a = (a + UInt32(byte)) % 65521
        b = (b + a) % 65521
    }

    return (b << 16) | a
}

/// Encode a UTF-8 string to base64, with optional zlib compression.
/// - Parameter message: The UTF-8 string to encode.
/// - Parameter compress: Whether to apply zlib compression before base64 encoding. Default is true.
/// - Returns: The base64-encoded string if successful, otherwise `nil`.
func encodeMessage(_ message: String, compress: Bool = true) -> String? {
    guard let utf8Data = message.data(using: .utf8) else { return nil }

    let dataToEncode: Data
    if compress {
        guard let compressedData = compressZlib(utf8Data) else { return nil }
        dataToEncode = compressedData
    } else {
        dataToEncode = utf8Data
    }

    return dataToEncode.base64EncodedString()
}

/// Debug helper to print out encoding attempts for an example message.
func encodeAny(message: String = "Hello, World!") {
    if let encoded = encodeMessage(message, compress: false) {
    }

    if let encodedCompressed = encodeMessage(message, compress: true) {
    }

    // Test round-trip
    if let encodedCompressed = encodeMessage(message, compress: true),
       let decoded = decodeMessage(encodedCompressed)
    {
    }
}
