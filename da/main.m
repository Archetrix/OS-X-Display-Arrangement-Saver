// OS X Display Arrangement Saver
//
// Copyright (c) 2014 Eugene Cherny
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
//   The above copyright notice and this permission notice shall be included in
//   all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <IOKit/graphics/IOGraphicsLib.h>

void printHelp(void);
void printInfo(void);
void saveArrangement(NSString* savePath);
void loadArrangement(NSString* savePath);

bool checkDisplayAvailability(NSArray* displaySerials);
bool checkMode(CGDisplayModeRef,long,long);
CGDirectDisplayID getDisplayID(NSScreen* screen);
NSString* getScreenSerial(NSScreen* screen, CGDirectDisplayID displayID);
NSPoint getScreenPosition(NSScreen* screen);
NSString* getEDIDDescriptor(NSData* edid, int descriptor, bool displayname);

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        NSArray* args = [[NSProcessInfo processInfo] arguments];
        if ([args count] == 1 || [args count] > 3) {
            printHelp();
            return 1;
        }
        if ([args[1] isEqualToString:@"help"]) {
            printHelp();
        } else if ([args[1] isEqualToString:@"list"]) {
            printInfo();
        } else if ([args[1] isEqualToString:@"save"]) {
            NSString* filename;
            if ([args count] == 3) {
                filename = (NSString*) args[2];
            } else {
                filename = @"~/Desktop/ScreenArrangement.plist";
            }
            printf("Saving to file: '%s'\n", [filename UTF8String]);
            saveArrangement(filename);
        } else if ([args[1] isEqualToString:@"load"]) {
            NSString* filename;
            if ([args count] == 3) {
                filename = (NSString*) args[2];
            } else {
                filename = @"~/Desktop/ScreenArrangement.plist";
            }
            printf("Loading arrangement from file: '%s'\n", [filename UTF8String]);
            loadArrangement(filename);
        }
    }
    return 0;
}

@implementation NSData (Hex) // From StackOverflow: http://stackoverflow.com/a/9084784
- (NSString *) hexString
{
    NSUInteger bytesCount = self.length;
    if (bytesCount) {
        const char* hexChars = "0123456789ABCDEF";
        const unsigned char* dataBuffer = self.bytes;
        char* chars = malloc(sizeof(char) * (bytesCount * 2 + 1));
        char* s = chars;
        for (unsigned i = 0; i < bytesCount; ++i) {
            *s++ = hexChars[((*dataBuffer & 0xF0) >> 4)];
            *s++ = hexChars[(*dataBuffer & 0x0F)];
            dataBuffer++;
        }
        *s = '\0';
        NSString* hexString = [NSString stringWithUTF8String:chars];
        free(chars);
        return hexString;
    }
    return @"";
}
@end


// COMMAND LINE

void printHelp() {
    NSString* helpText =
        @"OS X Display Arrangement Saver 0.2\n"
        @"A tool for saving and restoring display arrangement on OS X\n"
        @"\n"
        @"Usage:\n"
        @"  da help - prints this text\n"
        @"  da list - prints a list of all connected screens\n"
        @"  da save <path_to_plist> - saves current display arrangement to file\n"
        @"  da load <path_to_plist> - loads display arrangement from file\n"
        @"     if <path_to_plist> is not specified - the default used: '~/Desktop/ScreenArrangement.plist'\n"
        @"\n"
        @"NOTES\n"
        @"  This fixes Y-axis arrangement and includes some work to ensure non-edid displays work, too\n"
        @"\n"
        @"  Original authors GitHub repo:\n"
        @"    https://github.com/ech2/OS-X-Display-Arrangement-Saver\n"
        @"  Contributor GitHub repo:\n"
        @"    https://github.com/archetrix/OS-X-Display-Arrangement-Saver\n";
    printf("%s", [helpText UTF8String]);
}

void printInfo() {
    NSArray* screens = [NSScreen screens];
    printf("Total: %lu\n", (unsigned long)[screens count]);
    for (NSScreen* screen in screens) {
        CGDirectDisplayID displayID = getDisplayID(screen);
        NSString* serial = getScreenSerial(screen, displayID);
        NSPoint position = getScreenPosition(screen);
        NSSize size = [screen frame].size;
        NSInteger rotation = CGDisplayRotation(displayID);
        printf("  Display %li\n", (long)displayID);
        printf("    Serial:    %s\n", [serial UTF8String]);
        printf("    Position:  {%i, %i}\n", (int)position.x, (int)position.y);
        printf("    Dimension: {%i, %i} @ %i\n", (int)size.width, (int)size.height, (int) rotation);
    }
}

void saveArrangement(NSString* savePath) {
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    NSArray* screens = [NSScreen screens];
    [dict setObject:@"ScreenArrangement" forKey:@"About"];
    for (NSScreen* screen in screens) {
        CGDirectDisplayID displayID=getDisplayID(screen);
        NSString* serial = getScreenSerial(screen,displayID);
        NSPoint position = getScreenPosition(screen);
        NSSize size = [screen frame].size;
        NSInteger rotation = CGDisplayRotation(displayID);
        NSArray* a = [NSArray arrayWithObjects: [NSNumber numberWithInt:position.x], [NSNumber numberWithInt: position.y],[NSNumber numberWithInt: size.width],[NSNumber numberWithInt: size.height], rotation, nil];
        if (dict[serial]) {
            // Generate a warning, when the serial is already in our dictionary.
            printf("Warning duplicate screen identifier %s detected. Check if two or more serials are identical. Stored alignments will be incomplete.\n",[serial UTF8String]);
        }
        [dict setObject:a forKey:serial];
    }
    if ([dict count] != [screens count]+1) {
        printf("Something odd is happening. Possibly duplicate identifiers. Have %i screens but %i settings to store.\n",(int)[screens count],(int)[dict count]);
    }
    if ([dict writeToFile:[savePath stringByExpandingTildeInPath] atomically: YES]) {
        printf("Configuration file has been saved.\n");
    } else {
        printf("Error: Error saving configuration file.\n");
    }
}

void loadArrangement(NSString* savePath) {
    NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:[savePath stringByExpandingTildeInPath]];
    if (dict == nil) {
        printf("Error: Can't load file\n");
    }
    if (![[dict objectForKey:@"About"] isEqualToString:@"ScreenArrangement"]) {
        printf("Error: Wrong .plist file.\n");
    }
    //[dict removeObjectForKey:@"About"];
    if (!checkDisplayAvailability([dict allKeys])) {
        printf("Error: Probably, this configuration file has been made for different display set.\n");
        return;
    }
    
    CGDisplayConfigRef config;
    CGBeginDisplayConfiguration(&config);
    NSMutableArray* paramStore ;
    for (NSScreen* screen in [NSScreen screens]) {
        CGDirectDisplayID displayID = getDisplayID(screen);
        NSString* serial = getScreenSerial(screen,displayID);
        CFArrayRef modeList=CGDisplayCopyAllDisplayModes(displayID, NULL);
        CFIndex count=CFArrayGetCount(modeList);
        
        /*
         1st: Find values in object store
         */
        paramStore = [dict objectForKey:serial];
        
        /*
         2nd: Set correct display mode to match desired resolution.
         */
        for (CFIndex index = 0; index < count; index++) {
            // To restore screen size we have to find one mode that matches
            // Changes nothing if we can't find a matching mode.
            CGDisplayModeRef mode = (CGDisplayModeRef)CFArrayGetValueAtIndex (modeList, index);
            if (checkMode (mode,[(NSNumber*)paramStore[2] longValue],[(NSNumber*)paramStore[3] longValue])) {
                // found
                CGConfigureDisplayWithDisplayMode(config, displayID, mode, NULL);
                break;
            }
        }

        /*
         3rd: Set display origin.
         */
        // NSScreen and CGDisplay use different Y axis ... so invert from one to another.
        CGConfigureDisplayOrigin(config, displayID, [(NSNumber*)paramStore[0] intValue], -1*[(NSNumber*)paramStore[1] intValue]);
        
    }
    CGCompleteDisplayConfiguration(config, kCGConfigureForSession);
    printf("Screen arrangement has been loaded\n");
}

// UTILITY FUNCTIONS

bool checkDisplayAvailability(NSArray* displaySerials) {
    NSArray* screens = [NSScreen screens];
    for (NSScreen* screen in screens) {
        NSString* serial = getScreenSerial(screen,0);
        if (![displaySerials containsObject:serial]) {
            return false;
        }
    }
    return true;
}

bool checkMode (CGDisplayModeRef mode, long checkw, long checkh) {
    long height = CGDisplayModeGetHeight(mode);
    long width = CGDisplayModeGetWidth(mode);
    CFStringRef encoding = CGDisplayModeCopyPixelEncoding(mode);
    
    if (height == checkh && width == checkw && CFStringCompare(encoding, CFSTR(IO32BitDirectPixels),0)==kCFCompareEqualTo) {
        CFRelease(encoding);
        return true;
    } else {
        CFRelease(encoding);
        return false;
    }
}

CGDirectDisplayID getDisplayID(NSScreen* screen) {
    NSDictionary* screenDescription = [screen deviceDescription];
    return [[screenDescription objectForKey:@"NSScreenNumber"] unsignedIntValue];
}

NSString* getScreenSerial(NSScreen* screen, CGDirectDisplayID displayID) {
    // In fact, the function returns vendor id concateneted with serial number
    NSString* name;
    NSDictionary *deviceInfo = (__bridge_transfer NSDictionary*) IODisplayCreateInfoDictionary(CGDisplayIOServicePort(displayID), kIODisplayOnlyPreferredName);
    NSData* edid = [deviceInfo objectForKey:@"IODisplayEDID"];
    if (edid != nil) {
        // The function tries to return vendor id concateneted with serial number
        // See https://en.wikipedia.org/wiki/Extended_Display_Identification_Data#EDID_1.4_data_format
        name = [[edid subdataWithRange:NSMakeRange(10, 6)] hexString];
        // If name contains an empty serial nuber (i've seen this happen just now) use DisplayID as fallback
        if ([[name substringFromIndex: [name length] -8] isEqualToString:@"00000000"]) {
            edid = nil;
        }
    }
    if (edid == nil ) {
        if (displayID == 0) {
            displayID = getDisplayID(screen);
        }
        // Use displayID in case display has no EDID information.
        name = [NSString stringWithFormat:@"%u",displayID];
    }
    return name;
}

NSPoint getScreenPosition(NSScreen* screen) {
    NSRect frame = [screen frame];
    NSPoint point;
    point.x = frame.origin.x;
    point.y = frame.origin.y;
    return point;
}

NSString* getEDIDDescriptor(NSData* edid, int descriptor, bool displayname) {
    NSMutableString *_string = [NSMutableString stringWithString:@""];
    NSString* type=@"000000FF";
    if (displayname) {
        type=@"000000FC";
    }
    int offset=54;
    if (descriptor >= 4) {
        offset=108;
    } else if (descriptor == 3) {
        offset=90;
    } else if (descriptor == 2) {
        offset=72;
    }
    
    if ([[[edid subdataWithRange:NSMakeRange(offset, 4)] hexString] isEqualToString:type]) {
        // Section is a display Name (ASCII Text)
        NSData *_data = [edid subdataWithRange:NSMakeRange((offset+5), 13)];
        for (int i = 0; i < _data.length; i++) {
            unsigned char _byte;
            [_data getBytes:&_byte range:NSMakeRange(i, 1)];
            if (_byte >= 32 && _byte < 127) {
                [_string appendFormat:@"%c", _byte];
            //} else {
            //    [_string appendFormat:@"[%d]", _byte];
            }
        }
    }
    return [NSString stringWithFormat:@"%@", [_string stringByTrimmingCharactersInSet:
                                              [NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}
