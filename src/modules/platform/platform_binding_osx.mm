/**
* This file has been modified from its orginal sources.
*
* Copyright (c) 2012 Software in the Public Interest Inc (SPI)
* Copyright (c) 2012 David Pratt
* Copyright (c) 2012 Mital Vora
* 
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
***
* Copyright (c) 2008-2012 Appcelerator Inc.
* 
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
**/

#include <Cocoa/Cocoa.h>
#include <CoreFoundation/CoreFoundation.h>
#include <tide/tide.h>
#include <tideutils/osx/osx_utils.h>
#include <Poco/Environment.h>
#include <Foundation/Foundation.h>
#include "platform_binding.h"

@interface NSProcessInfo (LegacyWarningSurpression)
- (unsigned int) processorCount;
@end

namespace ti
{
std::string PlatformBinding::GetVersionImpl()
{
    // Do not use /System/Library/CoreServices/SystemVersion.plist.
    // See http://www.cocoadev.com/index.pl?DeterminingOSVersion
    SInt32 major, minor, bugfix;
    if (Gestalt(gestaltSystemVersionMajor, &major) != noErr ||
        Gestalt(gestaltSystemVersionMinor, &minor) != noErr ||
        Gestalt(gestaltSystemVersionBugFix, &bugfix) != noErr)
    {
        logger()->Error("Failed to get OS version");
        return "Unknown";
    }

    return [[NSString stringWithFormat:@"%d.%d.%d", major, minor, bugfix] UTF8String];
}

bool PlatformBinding::OpenApplicationImpl(const std::string& name)
{
    NSWorkspace* ws = [NSWorkspace sharedWorkspace];
    NSString* toOpen = [NSString stringWithUTF8String:name.c_str()];

    // Try to open it like a file.
    if ([ws openFile:toOpen])
        return true;

    // If that failed, try to launch it like an application.
    if ([ws launchApplication:toOpen])
        return true;

    // Fall back to trying to open it like a URL.
    return this->OpenURLImpl(name);
}

bool PlatformBinding::OpenURLImpl(const std::string& name)
{
    return [[NSWorkspace sharedWorkspace] openURL:
        [NSURL URLWithString:[NSString stringWithUTF8String:name.c_str()]]];
}

void PlatformBinding::TakeScreenshotImpl(const std::string& targetFile)
{
    CFRef<CGImageRef> image(CGWindowListCreateImage(CGRectInfinite,
        kCGWindowListOptionOnScreenOnly, kCGNullWindowID, kCGWindowImageDefault));
    NSURL* url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:targetFile.c_str()]];

    CFRef<CGImageDestinationRef> imageDestination(CGImageDestinationCreateWithURL(
        (CFURLRef) url, kUTTypePNG, 1, 0));
    if (!imageDestination.get())
        throw ValueException::FromString("Could not save screenshot");

    float resolution = 144.0;
    CFTypeRef keys[2];
    CFTypeRef values[2];
    keys[0] = kCGImagePropertyDPIWidth;
    keys[1] = kCGImagePropertyDPIHeight;
    values[0] = CFNumberCreate(0, kCFNumberFloatType, &resolution);
    values[1] = values[0];

    CFRef<CFDictionaryRef> options(CFDictionaryCreate(0, keys, values, 2,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));
    CFRelease(values[0]);

    CGImageDestinationAddImage(imageDestination.get(), image, options.get());
    CGImageDestinationFinalize(imageDestination.get());
}

}
