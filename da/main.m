// OS X Display Arrangement Saver
//
// Copyright (c) 2014 Eugene Cherny
// Copyright (c) 2019 Andreas Geesen (Videro AG)
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
#define MAX_DISPLAYS 10
#define SECONDARY_DISPLAY_COUNT 9

void printHelp(void);
void printErco(void);
void printVersion(void);
void printInfo(void);
int saveArrangement(NSString* savePath);
int loadArrangement(NSString* savePath);
const NSString* Version=@"1.2";

bool checkDisplayAvailability(NSArray* displaySerials);
bool checkMode(CGDisplayModeRef,long,long);
CGDirectDisplayID getDisplayID(NSScreen* screen);
NSString* getScreenSerial(NSScreen* screen, CGDirectDisplayID displayID);
NSPoint getScreenPosition(NSScreen* screen);
NSString* getEDIDDescriptor(NSData* edid, int descriptor, bool displayname);

static CGDisplayCount numberOfTotalDspys = MAX_DISPLAYS;

static CGDirectDisplayID activeDspys[MAX_DISPLAYS];
static CGDirectDisplayID onlineDspys[MAX_DISPLAYS];
static CGDirectDisplayID secondaryDspys[SECONDARY_DISPLAY_COUNT];

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        NSArray* args = [[NSProcessInfo processInfo] arguments];
        printVersion();
        if ([args count] == 1 || [args count] > 3) {
            printHelp();
            return 1;
        }
        if ([args[1] isEqualToString:@"help"]) {
            printHelp();
        } else if ([args[1] isEqualToString:@"erco"]) {
            printErco();
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
            return saveArrangement(filename);
        } else if ([args[1] isEqualToString:@"load"]) {
            NSString* filename;
            if ([args count] == 3) {
                filename = (NSString*) args[2];
            } else {
                filename = @"~/Desktop/ScreenArrangement.plist";
            }
            printf("Loading arrangement from file: '%s'\n", [filename UTF8String]);
            return loadArrangement(filename);
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

void multiConfigureDisplays(CGDisplayConfigRef configRef, CGDirectDisplayID *secondaryDspys, int count, CGDirectDisplayID master) {
    for (int i = 0; i<count; i++) {
        CGConfigureDisplayMirrorOfDisplay(configRef, secondaryDspys[i], master);
    }
}
bool getMirrorMode() {
    return CGDisplayIsInMirrorSet(CGMainDisplayID());
}
int setMirrorMode(CGDisplayConfigRef config,NSString* paramStore) {
    CGDisplayCount numberOfActiveDspys;
    CGDisplayCount numberOfOnlineDspys;
    CGDisplayErr activeError = CGGetActiveDisplayList (numberOfTotalDspys,activeDspys,&numberOfActiveDspys);
    
    if (activeError!=0) NSLog(@"Error in obtaining active diplay list: %d\n",activeError);
    
    CGDisplayErr onlineError = CGGetOnlineDisplayList (numberOfTotalDspys,onlineDspys,&numberOfOnlineDspys);
    
    if (onlineError!=0) NSLog(@"Error in obtaining online diplay list: %d\n",onlineError);
    
    if (numberOfOnlineDspys<2) {
        printf("No secondary display detected.\n");
        return 0;
    }
    
    int secondaryDisplayIndex = 0;
    for (int displayIndex = 0; displayIndex<numberOfOnlineDspys; displayIndex++) {
        if (onlineDspys[displayIndex] != CGMainDisplayID()) {
            secondaryDspys[secondaryDisplayIndex] = onlineDspys[displayIndex];
            secondaryDisplayIndex++;
        }
    }
    
    if ([paramStore isEqualToString:@"on"] && !getMirrorMode()) {
        multiConfigureDisplays(config, secondaryDspys, numberOfOnlineDspys - 1, CGMainDisplayID());
        printf("Enabling mirror");
        return 1;
    }
    if ([paramStore isEqualToString:@"off"] && getMirrorMode()) {
        multiConfigureDisplays(config, secondaryDspys, numberOfOnlineDspys - 1, kCGNullDirectDisplay);
        printf("Disabling mirror");
        return 1;
    }
    return 0;
}


// COMMAND LINE

void printHelp() {
    NSString* helpText =
    @"Usage:\n"
    @"  da help - prints this text\n"
    @"  da erco - prints a list of error codes returned with explanations\n"
    @"  da list - prints a list of all connected screens and their current setup\n"
    @"  da save <path_to_plist> - saves current display arrangement to file\n"
    @"  da load <path_to_plist> - loads display arrangement from file\n"
    @"     if <path_to_plist> is not specified - the default used: '~/Desktop/ScreenArrangement.plist'\n"
    @"\n"
    @"NOTES\n"
    @"  This ties displays to the port they're plugged in to.\n"
    @"  Be aware of that, because if plugged in to another port\n"
    @"  your screen will not be identified anymore.\n"
    @"\n"
    @"  Original authors GitHub repo:\n"
    @"    https://github.com/ech2/OS-X-Display-Arrangement-Saver\n"
    @"  Contributor GitHub repo:\n"
    @"    https://github.com/archetrix/OS-X-Display-Arrangement-Saver\n";
    printf("%s", [helpText UTF8String]);
}
void printErco() {
    NSString* ercoText =
    @"List of error codes:\n"
    @"    0 : No errors, all good.\n"
    @"  100 : Could not save arrangement into configuration file.\n"
    @"  101 : Could not load configuration file.\n"
    @"  102 : Configuration file is not a saved arrangement.\n"
    @"  103 : Configuration file does not match current setup.\n"
    @"  2xx : Error code minus 200 indicates how many changes had to be made to the current setup while loading a configuration.\n"
    @"        This can help if something else has to be triggered only if screen setup has been changed.\n"
    @"        e.g. restarting a program that would not detect that change on its own.\n"
    @"\n"
    @"Checking return code >200 find soft errors indicating a change in display arangement.\n"
    @"By checking return code >0 and <200 you find real hard errors.\n";
    printf("%s", [ercoText UTF8String]);
}
void printVersion() {
    printf("OS X Display Arrangement Saver %s\nA tool for saving and restoring display arrangement on OS X\n\n", [Version UTF8String]);
}
CGDisplayErr setRotation(NSString* rotation, CGDirectDisplayID directDisplayID) {
    //CGDirectDisplayID directDisplayID = (CGDirectDisplayID)display.intValue;
    
    //Set the rotation
    NSString* desiredRotation;
    if([rotation isEqualToString:@""])
    {
        desiredRotation=@"0";
    }
    else
    {
        desiredRotation = rotation;
    }
    
    enum{
        kIOFBSetTransform = 0x00000400,
    };

    static IOOptionBits anglebits[] = {
        (0x00000400 | (kIOScaleRotate0)   << 16),
        (0x00000400 | (kIOScaleRotate90)  << 16),
        (0x00000400 | (kIOScaleRotate180) << 16),
        (0x00000400 | (kIOScaleRotate270) << 16)
    };
    
    int anglebitsNumber = 0;
    switch ([desiredRotation intValue]) {
        case 90:
            anglebitsNumber = 1;
            break;
        case 180:
            anglebitsNumber = 2;
            break;
        case 270:
            anglebitsNumber = 3;
            break;
        default:
            anglebitsNumber = 0;
            break;
    }
    
    io_service_t service = CGDisplayIOServicePort(directDisplayID);
    CGDisplayErr displayError = IOServiceRequestProbe(service, anglebits[anglebitsNumber]);
    if(displayError == kCGErrorSuccess) {
        sleep(1);
    }
    
    return displayError;
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
    if(getMirrorMode()) {
        printf("Mirror Mode: ON\n");
    } else {
        printf("Mirror Mode: OFF\n");
    }
}

int saveArrangement(NSString* savePath) {
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    NSArray* screens = [NSScreen screens];
    [dict setObject:@"ScreenArrangement" forKey:@"About"];
    for (NSScreen* screen in screens) {
        CGDirectDisplayID displayID=getDisplayID(screen);
        NSString* serial = getScreenSerial(screen,displayID);
        NSPoint position = getScreenPosition(screen);
        NSSize size = [screen frame].size;
        NSInteger rotation = CGDisplayRotation(displayID);
        NSArray* a = [NSArray arrayWithObjects: [NSNumber numberWithInt:position.x], [NSNumber numberWithInt: position.y],[NSNumber numberWithInt: size.width],[NSNumber numberWithInt: size.height], [NSNumber numberWithLong: rotation], nil];
        if ([dict objectForKey:serial]) {
            // Generate a warning, when the serial is already in our dictionary.
            printf("Warning duplicate screen identifier %s detected. Check if two or more serials are identical. Stored alignments will be incomplete.\n",[serial UTF8String]);
        }
        [dict setObject:a forKey:serial];
    }
    if ([dict count] != [screens count]+1) {
        printf("Something odd is happening. Possibly duplicate identifiers. Have %i screens but %i settings to store.\n",(int)[screens count],(int)[dict count]);
    }
    if(getMirrorMode()) {
        [dict setObject:@"on" forKey:@"Mirror"];
    } else {
        [dict setObject:@"off" forKey:@"Mirror"];
    }
    if ([dict writeToFile:[savePath stringByExpandingTildeInPath] atomically: YES]) {
        printf("Configuration file has been saved.\n");
        return 0;
    } else {
        printf("Error: Error saving configuration file.\n");
        return 100;
    }
}

int loadArrangement(NSString* savePath) {
    NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:[savePath stringByExpandingTildeInPath]];
    if (dict == nil) {
        printf("Error: Can't load file\n");
        return 101;
    }
    if (![[dict objectForKey:@"About"] isEqualToString:@"ScreenArrangement"]) {
        printf("Error: Wrong .plist file.\n");
        return 102;
    }
    //[dict removeObjectForKey:@"About"];
    if (!checkDisplayAvailability([dict allKeys])) {
        printf("Error: Probably, this configuration file has been made for different display set.\n");
        return 103;
    }
    int needToChange=0;
    CGDisplayConfigRef config;
    CGBeginDisplayConfiguration(&config);
    NSString* mirrorsetting = [dict objectForKey:@"Mirror"];
    if (mirrorsetting != nil) {
        /*
         Intro: Set mirror mode.
         */
        needToChange+=setMirrorMode(config,mirrorsetting);
    }
    NSMutableArray* paramStore ;
    for (NSScreen* screen in [NSScreen screens]) {
        CGDirectDisplayID displayID = getDisplayID(screen);
        NSString* serial = getScreenSerial(screen,displayID);
        NSInteger rotation = CGDisplayRotation(displayID);
        /*
         1st: Find values in object store
         */
        paramStore = [dict objectForKey:serial];
        printf("\n  Display %li\n", (long)displayID);
        printf("    Serial:    %s\n", [serial UTF8String]);

        /*
         2nd: Check/set Display rotation
         */
        if (rotation != [(NSNumber*)paramStore[4] longValue]) {
            CGDisplayErr rotation_err = setRotation([NSString stringWithFormat:@"%i" ,[(NSNumber*)paramStore[4] intValue]], displayID);
            if (rotation_err != kCGErrorSuccess) {
                printf("Failed to rotate screen %s",[serial UTF8String]);
            } else {
                printf("rotating screen; ");
                needToChange++;
            }
            //printf("    Rotation: %i\n", [(NSNumber*)paramStore[4] intValue]);
        }

        /*
         3rd: Set correct display mode to match desired resolution.
         */
        CFArrayRef modeList=CGDisplayCopyAllDisplayModes(displayID, NULL);
        CFIndex count=CFArrayGetCount(modeList);
        bool foundNow=false,foundNew=false;
        CGDisplayModeRef modeNow=NULL,modeNew=NULL;
        NSSize size = [screen frame].size;
        for (CFIndex index = 0; index < count; index++) {
            // To restore screen size we have to find one mode that matches
            // Changes nothing if we can't find a matching mode.
            // TODO: Examine if that is changing anything (for return code).
            CGDisplayModeRef mode = (CGDisplayModeRef)CFArrayGetValueAtIndex (modeList, index);
            if (!foundNew && checkMode (mode,[(NSNumber*)paramStore[2] longValue],[(NSNumber*)paramStore[3] longValue])) {
                // found
                modeNew=mode;
                foundNew=true;
                //printf("    Dimension: {%i, %i}\n", [(NSNumber*)paramStore[2] intValue],[(NSNumber*)paramStore[3] intValue]);
            }
            if (!foundNow && checkMode (mode,size.width,size.height)) {
                // found
                modeNow=mode;
                foundNow=true;
                //printf("    Dimension: {%i, %i}\n", [(NSNumber*)paramStore[2] intValue],[(NSNumber*)paramStore[3] intValue]);
            }
            if (foundNow && foundNew) break;
        }
        CFRelease(modeList);
        if (foundNow && foundNew && modeNow != modeNew) {
            CGConfigureDisplayWithDisplayMode(config, displayID, modeNew, NULL);
            printf("changing screen resolution; ");
            needToChange++;
        }
        /*
         4th: Set display origin.
         */
        // NSScreen and CGDisplay use different Y axis ... so invert from one to another.
        NSPoint position = getScreenPosition(screen);
        if ((int) position.x != [(NSNumber*)paramStore[0] intValue] || (int) position.y != [(NSNumber*)paramStore[1] intValue]) {
            //printf("  Now  Position:  {%i, %i}\n",  (int) position.x, (int) position.y);
            //printf("  New  Position:  {%i, %i}\n", [(NSNumber*)paramStore[0] intValue], [(NSNumber*)paramStore[1] intValue]);
            CGConfigureDisplayOrigin(config, displayID, [(NSNumber*)paramStore[0] intValue], -1*[(NSNumber*)paramStore[1] intValue]);
            printf("changing screen origin; ");
            needToChange++;
        }
        
    }
    CGCompleteDisplayConfiguration(config, kCGConfigureForSession);
    printf("\nScreen arrangement has been loaded\n");
    // Shift error code to above 200 ...
    if (needToChange>0) needToChange+=200;
    return needToChange;
}

// UTILITY FUNCTIONS

bool checkDisplayAvailability(NSArray* displaySerials) {
    NSArray* screens = [NSScreen screens];
    for (NSScreen* screen in screens) {
        CGDirectDisplayID displayID=getDisplayID(screen);
        NSString* serial = getScreenSerial(screen,displayID);
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
    NSString* name_edid = @"";
    NSMutableString* hwkey=[[NSMutableString alloc]init];
    NSMutableString* descriptor=[[NSMutableString alloc]init];

    NSDictionary *deviceInfo = (__bridge_transfer NSDictionary*) IODisplayCreateInfoDictionary(CGDisplayIOServicePort(displayID), kIODisplayOnlyPreferredName);
    NSData* edid = [deviceInfo objectForKey:@"IODisplayEDID"];
    NSString* prefskey = [deviceInfo objectForKey:@"IODisplayPrefsKey"];
    
    if (prefskey != nil) {
        NSRange searchRange = NSMakeRange(0,[prefskey length]);
        // "IOService:/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/IGPU@2/AppleIntelFramebuffer@2/display0/AppleDisplay-4c2d-373"
        NSString *pattern = @"([0-9]?@[0-9]{1,2})";
        NSError *error = nil;
        
        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
        NSArray *matches = [regex matchesInString:prefskey options:0 range:searchRange];
        NSUInteger matchCount = [matches count];
        if (matchCount) {
            for (NSUInteger matchIdx = 0; matchIdx<matchCount;matchIdx++) {
                NSTextCheckingResult *match = [matches objectAtIndex:matchIdx];
                NSRange matchRange = [match range];
                [hwkey appendString:[prefskey substringWithRange:matchRange]];
            }
        }
    }

    if (edid != nil) {
        // The function tries to return vendor id concateneted with serial number
        // See https://en.wikipedia.org/wiki/Extended_Display_Identification_Data#EDID_1.4_data_format
        name_edid = [[edid subdataWithRange:NSMakeRange(10, 6)] hexString];

        // Use this additional edid descriptor data (if existent and not empty) to make identification stronger.
        // We have seen displays (mostly generic DVI to LED-Wall controllers) that send no serial number and not even a manufacturer or device identifier at all.
        // Some have at least an ASCII Serial Number in the descriptor extensions.
        for (int i=1;i<4;i++) {
            NSString* fnktemp = getEDIDDescriptor(edid, i, true);
            if ([fnktemp length] != 0) {
                [descriptor appendString:fnktemp];
            }
        }
        for (int i=1;i<4;i++) {
            NSString* fnktemp = getEDIDDescriptor(edid, i, false);
            if ([fnktemp length] != 0) {
                [descriptor appendString:fnktemp];
            }
        }
    }
    NSString *result=[NSString stringWithFormat:@"%@#%@:%@", name_edid, hwkey, descriptor];
    if (![result  isEqual: @"#:"]) {
        return [NSString stringWithFormat:@"%li", (long)displayID];
    } else {
        return result;
    }
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
