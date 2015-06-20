#!/usr/bin/env xcrun swift

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

struct Playdown {
    let streamReader: StreamReader!
    let SingleLineTextBeginningPattern = "^//:"
    let MultilineTextBeginningPattern = "/\\*:"
    let MultilineTextEndingPattern = "\\*/"
    let MarkdownCodeStartDelimiter = "```swift"
    let MarkdownCodeEndDelimiter = "```\n"

    enum LineType {
        case SingleLineText, MultilineText, SwiftCode
    }
    
    init(filename: String) {
        streamReader = StreamReader(path: filename)
    }
    
    func markdown() {
        var lineState: LineType = .SwiftCode
        var previousLineState: LineType? = nil
        
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
            
            let outputText: String!
            
            if previousLineState == nil {
                // This is the first line
                
                switch lineState {
                case .SingleLineText:
                    outputText = stringByStrippingSingleLineTextMetacharactersFromString(line)
                case .MultilineText:
                    // The first line of a multiline comment is never displayed (it's an optional comment)
                    outputText = "" // stringByStrippingSingleLineTextMetacharactersFromString(line)
                default:
                    if !singleLineBeginning && !multiLineBeginning {
                        outputText = stringByAlteringCodeFencing(line)
                    } else {
                        outputText = line
                    }
                }
            } else {
                // This is a regular line
                // Old state -> Current state
                
                switch (previousLineState!, lineState) {
                // Swift code -> Other
                case (.SwiftCode, .SwiftCode):
                    outputText = line
                case (.SwiftCode, .SingleLineText):
                    outputText = MarkdownCodeEndDelimiter + stringByStrippingSingleLineTextMetacharactersFromString(line)
                case (.SwiftCode, .MultilineText):
                    // The first line of a multiline comment is never displayed (it's an optional comment)
                    outputText = MarkdownCodeEndDelimiter + "" // stringByStrippingMultilineTextMetacharactersFromString(line)
                
                // Single line -> Other
                case (.SingleLineText, .SwiftCode):
                    outputText = stringByAlteringCodeFencing(line)
                case (.SingleLineText, .SingleLineText):
                    outputText = stringByStrippingSingleLineTextMetacharactersFromString(line)
                case (.SingleLineText, .MultilineText):
                    // The first line of a multiline comment is never displayed (it's an optional comment)
                    outputText = "" // stringByStrippingMultilineTextMetacharactersFromString(line)
                    
                // Multiline -> Other
                case (.MultilineText, .SwiftCode):
                    outputText = stringByAlteringCodeFencing(line)
                case (.MultilineText, .SingleLineText):
                    outputText = stringByStrippingSingleLineTextMetacharactersFromString(line)
                case (.MultilineText, .MultilineText):
                    outputText = stringByStrippingMultilineTextMetacharactersFromString(line)
                }
                
            }
            
            println(outputText)
            
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
            println(MarkdownCodeEndDelimiter)
        }
    }
    
    func stringByStrippingSingleLineTextMetacharactersFromString(string: String) -> String {
        return string.stringByReplacingOccurrencesOfString("//: ", withString: "")
    }
    
    func stringByStrippingMultilineTextMetacharactersFromString(string: String) -> String {
        let strippedLine = string.stringByReplacingOccurrencesOfString("/*:", withString: "")
                                 .stringByReplacingOccurrencesOfString("*/", withString: "")
        return strippedLine
    }
    
    func stringByAlteringCodeFencing(string: String) -> String {
        let outputText: String
        
        // Add a newline between the markdown delimiter if necessary
        if string.matchesPattern("\\n", options: nil, error: nil) || count(string) == 0 {
            // Empty line
            outputText = "\n" + MarkdownCodeStartDelimiter + string
        } else {
            outputText = MarkdownCodeStartDelimiter + "\n" + string
        }
        
        return outputText
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
        playdown.markdown()
    }
}

Main()
