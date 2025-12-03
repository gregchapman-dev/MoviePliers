import AVFoundation

struct Atom {
    let offset: UInt64      // offset in file of atom header
    
    let type: String
    let size: UInt64        // includes header (and extended size field if present) and data;
                            // if atom size was 0 or 1 in file, the size here is computed
                            // (0: to end of file, or 1: use extended size field)
    let sizeWasZero: Bool   // was atomheader.size == 0 (i.e. size is from header offset to EOF)
    let dataOffset: UInt64  // offset in file of data
    let dataSize: UInt64    // size of just the data (no header, no extended size)
    
    let data: Data? = nil
}

class AtomParser {
    let url: URL
    let fileHandle: FileHandle?
    init (_ url: URL) {
        self.url = url
        self.fileHandle = try? FileHandle(forUpdating: url)
    }
    
    deinit {
        if fileHandle != nil {
            try? fileHandle!.close()
        }
    }

    func parseTopLevelAtoms()  -> [Atom] {
        guard let fileHandle else { return [] }
        
        var topLevelAtoms: [Atom] = []
        var offset: UInt64 = 0
        let fileSize = fileHandle.seekToEndOfFile()

        while offset < fileSize {
            do {
                try fileHandle.seek(toOffset: offset)
                
                var sizeWasZero: Bool = false
                
                // Read the 4-byte size (Big Endian)
                guard let sizeData = try fileHandle.read(upToCount: 4), sizeData.count == 4 else { break }
                var size: UInt64 = UInt64(UInt32(bigEndian: sizeData.withUnsafeBytes { $0.load(as: UInt32.self) }))
                if size == 0 {
                    size = fileSize - (offset - 4)
                    sizeWasZero = true
                }
                var dataSize: UInt64
                
                // Read the 4-byte type (ASCII string)
                guard let typeData = try fileHandle.read(upToCount: 4), typeData.count == 4 else { break }
                let type = String(decoding: typeData, as: UTF8.self)
                
                // Now we're positioned where extendedSize would be (if size is 1)
                if size == 1 {
                    guard let extendedSizeData = try fileHandle.read(upToCount: 8), extendedSizeData.count == 8 else
                    {
                        break
                    }
                    size = UInt64(bigEndian: extendedSizeData.withUnsafeBytes { $0.load(as: UInt64.self) })
                    dataSize = size - 16 // dataSize is size - (headerSize (8) + extendedSizeSize (8))
                }
                else {
                    dataSize = size - 8 // dataSize is size - headerSize (8)
                }
                
//                print("Found atom: '\(type)' with size: \(size) at offset: \(offset)")
//                print("              with dataSize: \(dataSize) and dataOffset: \(offset + (size - dataSize))")
                
                let atom = Atom(
                    offset: offset,
                    type: type,
                    size: size,
                    sizeWasZero: sizeWasZero,
                    dataOffset: offset + (size - dataSize),
                    dataSize: dataSize
                )
                topLevelAtoms.append(atom)
                
                // Move the offset to the next atom
                offset += size
                
                // If the atom is a container (like 'moov' or 'trak'), you would need
                // a recursive function to parse its child atoms (size - 8 for header)
                
            } catch {
                print("Error reading file: \(error)")
                break
            }
        }
        print("all done")
        return topLevelAtoms
    }

    func _replaceMoovAtom_NotUsedAnymore(with newMoov: Data) {
        guard let fileHandle else { return }
        let topAtoms = parseTopLevelAtoms()
        do {
            if let moovIndex = topAtoms.firstIndex(where: { $0.type == "moov" }) {
                let moovAtom = topAtoms[moovIndex]
                if moovIndex == topAtoms.count - 1 {
                    // "moov" is last atom in file, just overwrite it (and if newMoov is shorter, truncate the file)
                    try fileHandle.seek(toOffset: moovAtom.offset)
                    fileHandle.write(newMoov)
                    if newMoov.count < moovAtom.size {
                        try fileHandle.truncate(atOffset: moovAtom.offset + UInt64(newMoov.count))
                    }
                }
                else {
                    // "moov" is NOT last atom in file.
                    if newMoov.count > moovAtom.size {
                        // won't fit where current 'moov' is.  We'll have to append newMoov to the file.
                        
                        // First, patch up the last atom's size (if it was 0), since
                        // it's no longer going to be the last atom in the file.
                        let lastAtom = topAtoms[topAtoms.count - 1]
                        if lastAtom.sizeWasZero {
                            if lastAtom.size <= UINT32_MAX {
                                // fits in 32-bit size field
                                let newSize: UInt32 = UInt32(lastAtom.size)
                                var bigEndianNewSize = newSize.bigEndian
                                try fileHandle.seek(toOffset: lastAtom.offset)
                                fileHandle.write(Data(bytes: &bigEndianNewSize, count: 4))
                            }
                            else {
                                // won't fit in 32-bit field, hopefully the penultimate atom is 'wide' so we can
                                // use that space to fit a new extended header (with extended size field)
                                let penultimateAtom = topAtoms[topAtoms.count - 2]
                                if penultimateAtom.type != "wide" {
                                    print("Didn't find a 'wide' atom to extend the size of the previous atom; cannot replace moov atom.")
                                    return
                                }
                                
                                // overwrite 'wide' atom with size=1 type=lastAtom.type extendedSize=lastAtom.size
                                let size32: UInt32 = 1
                                let type: String = lastAtom.type
                                let size64: UInt64 = UInt64(lastAtom.size)
                                var bigEndianSize32 = size32.bigEndian
                                var bigEndianSize64 = size64.bigEndian
                                
                                try fileHandle.seek(toOffset: penultimateAtom.offset)
                                fileHandle.write(Data(bytes: &bigEndianSize32, count: 4))
                                fileHandle.write(Data(type.utf8))
                                fileHandle.write(Data(bytes: &bigEndianSize64, count: 8))
                            }
                        }
                        
                        // Second, whack the original 'moov' atom's type to something ('hoov' is traditional
                        // for "hidden moov")
                        try fileHandle.seek(toOffset: moovAtom.offset + 4)
                        fileHandle.write(Data("hoov".utf8))
                        
                        // Third, append newMoov to the file.
                        try fileHandle.seekToEnd()
                        fileHandle.write(newMoov)
                    }
                    else {
                        // It will fit where the current 'moov' is.  Write it there, and then cover
                        // the rest of the old 'moov' with a 'free' atom if necessary.
                        let extraSpace: UInt64 = UInt64(newMoov.count) - moovAtom.size
                        try fileHandle.seek(toOffset: moovAtom.offset)
                        fileHandle.write(newMoov)
                        if extraSpace > INT32_MAX {
                            // Yikes!
                            let size32: UInt32 = 1
                            var bigEndianSize32 = size32.bigEndian
                            let size64 = UInt64(extraSpace)
                            var bigEndianSize64 = size64.bigEndian
                            let freeDataSize = Int(extraSpace - 16)

                            fileHandle.write(Data(bytes: &bigEndianSize32, count: 4))
                            fileHandle.write(Data("free".utf8))
                            fileHandle.write(Data(bytes: &bigEndianSize64, count: 8))
                            if freeDataSize > 0 {
                                // too much free space data to clear
                                // just write a marker so someone hexdumping can
                                // see what's happening
                                fileHandle.write(Data("Just a bunch of free space, really; ignore the rest of this data; it used to be part of the previous moov atom".utf8))
                            }
                        }
                        else if extraSpace >= 8 {
                            let size32: UInt32 = UInt32(extraSpace)
                            var bigEndianSize32 = size32.bigEndian
                            let freeSize = Int(extraSpace - 8)

                            fileHandle.write(Data(bytes: &bigEndianSize32, count: 4))
                            fileHandle.write(Data("free".utf8))
                            if freeSize > 0 {
                                fileHandle.write(Data(count: freeSize))  // all zeroes, so we don't leave data around
                            }
                        }
                        else if extraSpace > 0 {
                            try fileHandle.seek(toOffset: moovAtom.offset)
                            guard let sizeData = try fileHandle.read(upToCount: 4), sizeData.count != 4 else {
                                // should never happen, we literally just wrote this
                                print("could not read new moov size back from file")
                                return
                            }
                            
                            var newMoovSize: UInt32 = UInt32(bigEndian: sizeData.withUnsafeBytes { $0.load(as: UInt32.self) })
                            newMoovSize += UInt32(extraSpace)
                            var bigEndianNewMoovSize: UInt32 = newMoovSize.bigEndian
                            
                            try fileHandle.seek(toOffset: moovAtom.offset)
                            fileHandle.write(Data(bytes: &bigEndianNewMoovSize, count: 4))
                            
                            // clear those few bytes of data
                            try fileHandle.seek(toOffset: moovAtom.offset + 8)
                            fileHandle.write(Data(count: Int(extraSpace)))
                        }
                    }
                }
            }
            else {
                // we should not get here
                print("No moov atom found; cannot replace moov atom.")
            }
        }
        catch {
            print("Failed to replace moov atom: \(error)")
        }
    }
    
    func _parseAtomsInMemory_ExampleCode(data: Data) {
        var offset = 0
        while offset < data.count {
            data.withUnsafeBytes { rawBufferPointer in
                // Ensure we have enough data for the size and type fields
                guard offset + 8 <= rawBufferPointer.count else { return }

                // Read size (UInt32, big endian)
                let size: UInt32 = rawBufferPointer.load(fromByteOffset: offset, as: UInt32.self).byteSwapped
                offset += MemoryLayout<UInt32>.size

                // Read type (4-character code, UInt32 big endian, or cast to String)
                let typeCode: UInt32 = rawBufferPointer.load(fromByteOffset: offset, as: UInt32.self).byteSwapped
                let type = String(decoding: withUnsafeBytes(of: typeCode) { Data($0) }, as: UTF8.self)
                offset += MemoryLayout<UInt32>.size

                print("Found atom: \(type), size: \(size) bytes")

                // Determine if it's a container atom or a leaf atom, and parse content
                // For container atoms, recursively call this function with the inner data
                // For leaf atoms, extract specific data based on the type
                
                // Move to the next atom
                offset += Int(size) - 8 // Subtract the size and type fields we already read
            }
        }
    }

    func _insertFreeAtom_ExampleCode(fileURL: URL, size: UInt64) {
        let atomType: String = "free"
        var size32: UInt32
        var size64: UInt64?
        if size <= UINT32_MAX {
            // fits in 32-bit size field
            size32 = UInt32(size)
            size64 = nil
        }
        else {
            // set 32-bit size field to big-endian 1, set 64-bit extendedSize field to big-endian size
            size32 = 1
            size64 = size
        }
        var bigEndianSize32: UInt32 = size32.byteSwapped // QuickTime files are big-endian
        var bigEndianSize64: UInt64? = size64?.byteSwapped

        let sizeData = Data(bytes: &bigEndianSize32, count: 4)
        let typeData = Data(atomType.utf8)
        var extendedSizeData: Data? = nil
        if bigEndianSize64 != nil {
            extendedSizeData = Data(bytes: &bigEndianSize64, count: 8)
        }

        do {
            let fileHandle = try FileHandle(forWritingTo: fileURL)
            // Seek to the end of the file or a specific offset
            // if end of file, instead of writing lots of zeroes, try
            // fileHandle.truncate(newBiggerEOF), which will fill the new
            // extent of the file with zeroes.
            fileHandle.seekToEndOfFile()

            fileHandle.write(sizeData)
            fileHandle.write(typeData)
            if let extendedSizeData {
                fileHandle.write(extendedSizeData)
            }
            
            // Write the remaining free space data (padding)
            var paddingSize = size - 8 // header is 8 bytes
            if extendedSizeData != nil {
                paddingSize -= 8 // extended size is another 8 bytes
            }
            
            let maxWriteSize: Int = 10*1024*1024
            var maxWriteData: Data? = nil
            while paddingSize > 0 {
                if paddingSize > maxWriteSize {
                    if maxWriteData == nil {
                        maxWriteData = Data(count: maxWriteSize)
                    }
                    fileHandle.write(maxWriteData!)
                    paddingSize -= UInt64(maxWriteSize)
                }
                else {
                    fileHandle.write(Data(count: Int(paddingSize)))
                    paddingSize = 0
                }
            }

            print("Successfully wrote 'free' atom to file.")
        } catch {
            print("Error writing atom: \(error.localizedDescription)")
        }
    }
}
