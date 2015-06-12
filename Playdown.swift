import Foundation

/**
*  StreamReader is used for reading from files, among other things.
*  c/o Airspeed Velocity
*  http://stackoverflow.com/questions/24581517/read-a-file-url-line-by-line-in-swift
*  http://stackoverflow.com/questions/29540593/read-a-file-line-by-line-in-swift-1-2
*/
class StreamReader  {
    
    let encoding : UInt
    let chunkSize : Int
    
    var fileHandle : NSFileHandle!
    let buffer : NSMutableData!
    let delimData : NSData!
    var atEof : Bool = false
    
    init?(path: String, delimiter: String = "\n", encoding : UInt = NSUTF8StringEncoding, chunkSize : Int = 4096) {
        self.chunkSize = chunkSize
        self.encoding = encoding
        
        if let fileHandle = NSFileHandle(forReadingAtPath: path),
            delimData = delimiter.dataUsingEncoding(NSUTF8StringEncoding),
            buffer = NSMutableData(capacity: chunkSize)
        {
            self.fileHandle = fileHandle
            self.delimData = delimData
            self.buffer = buffer
        } else {
            self.fileHandle = nil
            self.delimData = nil
            self.buffer = nil
            return nil
        }
    }
    
    deinit {
        self.close()
    }
    
    /// Return next line, or nil on EOF.
    func nextLine() -> String? {
        precondition(fileHandle != nil, "Attempt to read from closed file")
        
        if atEof {
            return nil
        }
        
        // Read data chunks from file until a line delimiter is found:
        var range = buffer.rangeOfData(delimData, options: nil, range: NSMakeRange(0, buffer.length))
        while range.location == NSNotFound {
            var tmpData = fileHandle.readDataOfLength(chunkSize)
            if tmpData.length == 0 {
                // EOF or read error.
                atEof = true
                if buffer.length > 0 {
                    // Buffer contains last line in file (not terminated by delimiter).
                    let line = NSString(data: buffer, encoding: encoding)
                    
                    buffer.length = 0
                    return line as String?
                }
                // No more lines.
                return nil
            }
            buffer.appendData(tmpData)
            range = buffer.rangeOfData(delimData, options: nil, range: NSMakeRange(0, buffer.length))
        }
        
        // Convert complete line (excluding the delimiter) to a string:
        let line = NSString(data: buffer.subdataWithRange(NSMakeRange(0, range.location)),
            encoding: encoding)
        // Remove line (and the delimiter) from the buffer:
        buffer.replaceBytesInRange(NSMakeRange(0, range.location + range.length), withBytes: nil, length: 0)
        
        return line as String?
    }
    
    /// Start reading from the beginning of file.
    func rewind() -> Void {
        fileHandle.seekToFileOffset(0)
        buffer.length = 0
        atEof = false
    }
    
    /// Close the underlying file. No reading must be done after calling this method.
    func close() -> Void {
        fileHandle?.closeFile()
        fileHandle = nil
    }
}

extension StreamReader : SequenceType {
    func generate() -> GeneratorOf<String> {
        return GeneratorOf<String> {
            return self.nextLine()
        }
    }
}

extension String {
    func substringsMatchingPattern(let pattern: String, let options: NSRegularExpressionOptions, let matchGroup: Int, error: NSErrorPointer) -> [String] {
        let range = NSMakeRange(0, count(self))
        let regex = NSRegularExpression(pattern: pattern, options: options, error: error)
        let matches = regex?.matchesInString(self, options: nil, range: range)
        
        var output: [String] = []

        for match in matches as! [NSTextCheckingResult] {
            let matchRange = match.rangeAtIndex(matchGroup)
            let matchString = (self as NSString).substringWithRange(matchRange)
            output.append(matchString as String)
        }
        
        return output
    }
    
    func matchesPattern(let pattern: String, let options: NSRegularExpressionOptions, error: NSErrorPointer) -> Bool {
        let range = NSMakeRange(0, count(self))
        let regex = NSRegularExpression(pattern: pattern, options: options, error: error)
        let matches = regex?.firstMatchInString(self, options: nil, range: range)
        
        if matches == nil {
            return false
        } else {
            return true
        }
    }
    
    func subrangesMatchingPattern(let pattern: String, let options: NSRegularExpressionOptions, error: NSErrorPointer) -> [NSRange] {
        let range = NSMakeRange(0, count(self))
        let regex = NSRegularExpression(pattern: pattern, options: options, error: error)
        let matches = regex?.matchesInString(self, options: nil, range: range) as! [NSTextCheckingResult]
        return matches.map { return $0.rangeAtIndex(0) }
    }
}

extension NSRange {
    static func minimizeRanges(ranges: [NSRange]) -> Array<NSRange> {
        // Sort by starting first, then by ending last for identical start locations
        let sortedRanges = ranges.sorted { (a, b) -> Bool in
            if a.location < b.location {
                return true
            }
            
            if a.location == b.location && a.length > b.length {
                return true
            }
            
            return false
        }
        
        
        var lastStartLocation = 0
        var minimalSetOfRanges: [NSRange] = []
        
        for i in 0 ..< sortedRanges.count {
            let range = sortedRanges[i]
            
            // We sorted the ranges so that we don't need to worry about this
            if lastStartLocation < range.location + range.length {
                minimalSetOfRanges.append(range)
                lastStartLocation = range.location + range.length
            }
        }
        
        return minimalSetOfRanges
    }
}

extension NSRange {
    func complementSubranges(ranges: [NSRange]) -> [NSRange] {
        let fullRange = self
        let minimalRanges = NSRange.minimizeRanges(ranges)
        
        var missingRanges: [NSRange] = []
        var lastRange: NSRange?
        
        for range in minimalRanges {
            // If there is any space between the current range and the last range in the minimal set, then we need to fill it.
            if lastRange == nil {
                // The first range in the list
                if range.location > 0 {
                    let fillRange = NSMakeRange(0, range.location)
                    missingRanges.append(fillRange)
                }
            } else {
                if range.location > lastRange!.location + lastRange!.length {
                    let lastEnd = lastRange!.location + lastRange!.length
                    let fillRange: NSRange = NSMakeRange(lastEnd, range.location - lastEnd)
                    missingRanges.append(fillRange)
                }
            }
            
            lastRange = range
        }
        
        // Add the last range, if needed
        if let lastRange = lastRange {
            if lastRange.location + lastRange.length < fullRange.length {
                let lastEnd = lastRange.location + lastRange.length
                let difference = fullRange.length - lastEnd
                let endRange = NSMakeRange(lastEnd, difference)
                missingRanges.append(endRange)
            }
        }
        
        return missingRanges
    }
}

struct PlaygroundFile {
    let contents: String
    
    func markdownFormat() -> String {
        var error: NSError?
        let blockRanges = contents.subrangesMatchingPattern("^/\\*:(.*)?\\*/", options: .AnchorsMatchLines, error: &error)
        let singleLineRanges = contents.subrangesMatchingPattern("^//:(.*)$", options: .AnchorsMatchLines, error: &error)
        
        let fullRange = NSMakeRange(0, count(contents))
        
        let coal: [NSRange] = blockRanges + singleLineRanges
        println(coal)

        let comp = fullRange.complementSubranges(coal)
        println(comp)

        enum MDType {
            case SingleLine, Block, Code, Undefined
        }
        
        var parts: [(MDType, NSRange)] = []
        
        for code in comp {
            if code.length > 1 {
                parts.append((MDType.Code, code))
            }
        }
        
        for block in blockRanges {
            parts.append((MDType.Block, block))
        }
        
        for line in singleLineRanges {
            parts.append((MDType.SingleLine, line))
        }
        
        let sortedParts = parts.sorted { (a, b) -> Bool in
            if a.1.location < b.1.location {
                return true
            }
            
            return false
        }
        
        var output = ""
        var lastState = MDType.Undefined
        
        let contentsAsNSString = contents as NSString

        for pair in sortedParts {
            let substr = contentsAsNSString.substringWithRange(pair.1)
            
            if pair.0 == .Code {
                // Strip leading newlines from code
                let strippedNewLines = substr.stringByTrimmingCharactersInSet(NSCharacterSet.newlineCharacterSet())

                if lastState == .Undefined {
                    output += "```\n\(strippedNewLines)\n```"
                } else {
                    if lastState == .SingleLine {
                        println("Last state SNL $$$\(strippedNewLines)$$$")
                        output += "\n\n```\n\(strippedNewLines)\n```"
                    } else {
                        output += "\n```\n\(strippedNewLines)\n```"
                    }
                    
                }
                
            } else if pair.0 == .SingleLine {
                let singleLineStartPattern = "^//:\\s*"
                let singleLineRegex = NSRegularExpression(pattern: singleLineStartPattern, options: NSRegularExpressionOptions.AnchorsMatchLines, error: &error)
                let strippedPredeterminer = singleLineRegex?.stringByReplacingMatchesInString(substr, options: nil, range: NSMakeRange(0, count(substr)), withTemplate: "")
                
                if lastState == .Code {
                    output += "\n\n"
                }

                if lastState == .SingleLine {
                    output += "\n"
                }
                
                output += strippedPredeterminer!
            } else if pair.0 == .Block {
                let strippedPredeterminer = substr.stringByReplacingOccurrencesOfString("/*:", withString: "", options: NSStringCompareOptions.AnchoredSearch, range: nil)
                let strippedPostDeterminer = strippedPredeterminer.stringByReplacingOccurrencesOfString("*/", withString: "", options: NSStringCompareOptions.AnchoredSearch | NSStringCompareOptions.BackwardsSearch, range: nil)
                
                if lastState == .SingleLine {
                    output += "\n\n"
                }
                
                if lastState == .Code {
                    output += "\n"
                }
                
                output += strippedPostDeterminer
            }
            
            lastState = pair.0
        }
        
        return output
    }
}

struct Playdown {
    let streamReader: StreamReader!

    enum LineType {
        case SingleLineText, MultilineText, SwiftCode
    }
    
    init(filename: String) {
        streamReader = StreamReader(path: filename)
    }
    
    func markdown() -> String {
        var lineState: LineType = .SwiftCode
        var previousLineState: LineType? = nil
        
        let SingleLineTextBeginningPattern = "^//:"
        let MultilineTextBeginningPattern = "/\\*:"
        let MultilineTextEndingPattern = "\\*/"
        let options = NSRegularExpressionOptions.AllowCommentsAndWhitespace
        
        for line in streamReader {
            var error: NSError?
            
            let singleLineBeginning = line.matchesPattern(SingleLineTextBeginningPattern, options: options, error: &error)
            let multiLineBeginning = line.matchesPattern(MultilineTextBeginningPattern, options: options, error: &error)
            let multiLineEnding = line.matchesPattern(MultilineTextEndingPattern, options: options, error: &error)
            
            // Switch into a regular-text line if necessary
            if singleLineBeginning  {
                lineState = .SingleLineText
            } else if multiLineBeginning {
                lineState = .MultilineText
            } else if lineState == .MultilineText {
                lineState = .MultilineText
            } else {
                lineState = .SwiftCode
            }
            
            if previousLineState == nil {
                // This is the first line
                if !singleLineBeginning && !multiLineBeginning {
                    println("```")
                }
                
                println(line)
            } else {
                switch (previousLineState!, lineState) {
                case (.SwiftCode, .SwiftCode):
                    println(line)
                case (_, .SwiftCode):
                    println("```")
                    println(line)
                case (.SwiftCode, _):
                    println("```")
                    println(line)
                default:
                    println(line)
                    
                }
            }
            
            previousLineState = lineState
            
            // Handle switching out of modes
            if multiLineEnding {
                // Only handle multi-line ending if we were previously in multiline mode
                if let previous = previousLineState where previous == .MultilineText {
                    previousLineState = .MultilineText
                    lineState = .SwiftCode
                }
            }
        }
        
        // Handle the closing tags
        if lineState == .SwiftCode && previousLineState == .SwiftCode {
            println("```")
        }
        
        return ""
    }
}

struct Main {
    init() {
        if Process.arguments.count < 2 {
            println("Filename required.")
            assert(false);
        }

        let filename = Process.arguments[1]
        let playdown = Playdown(filename: filename)
        println(playdown.markdown())
    }
}

Main()
