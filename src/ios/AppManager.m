#import "AppManager.h"
#import <Cordova/CDV.h>
#import <CommonCrypto/CommonDigest.h>

#define FileHashDefaultChunkSizeForReadingData 1024*8

@implementation AppManager

- (void)openApp:(CDVInvokedUrlCommand *)command {
    NSString *scheme = command.arguments[0];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", scheme]];
    if ([[UIApplication sharedApplication] canOpenURL:url])
        [[UIApplication sharedApplication] openURL:url];
    else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Not Install"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)hasApp:(CDVInvokedUrlCommand *)command {
    NSString *scheme = command.arguments[0];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", scheme]];
    BOOL flag = NO;
    if ([[UIApplication sharedApplication] canOpenURL:url])
        flag = YES;
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:flag];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)exitApp:(CDVInvokedUrlCommand *)command {
    exit(0);
}

- (void)getPic:(CDVInvokedUrlCommand *)command {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *screen = [[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates/screen.png"]];
    NSString *tip = @"error";
    if (![manager fileExistsAtPath:screen]) {
        NSString *imageName = [self getImageName:[self getCurrentOrientation] delegate:(id <CDVScreenOrientationDelegate>) self.viewController device:[self getCurrentDevice]];
        NSString *updates = [[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates/"]];
        if (![manager fileExistsAtPath:updates])
            [manager createDirectoryAtPath:updates withIntermediateDirectories:YES attributes:nil error:nil];
        BOOL flag = [UIImagePNGRepresentation([UIImage imageNamed:imageName]) writeToFile:screen atomically:YES];
        if (flag)
            tip = @"success";
    }
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:tip];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)checkProject:(CDVInvokedUrlCommand *)command {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *version = [[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates/version.txt"]];
    NSString *tip, *currentCode;
    if ([manager fileExistsAtPath:version]) {
        currentCode = [NSString stringWithContentsOfFile:version encoding:NSUTF8StringEncoding error:nil];
        NSString *versionCode = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        if ([versionCode isEqualToString:currentCode] && ![versionCode isEqualToString:@""])
            tip = @"nothing";
        else {
            [manager removeItemAtPath:version error:nil];
            [manager removeItemAtPath:[[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates/files.json"]] error:nil];
            [manager removeItemAtPath:[[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates/project/"]] error:nil];
            tip = @"unzip";
        }
    } else
        tip = @"unzip";
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:tip];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)unzipProject:(CDVInvokedUrlCommand *)command {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *updates = [[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates"]];
    NSString *project = [[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates/project"]];
    if (![manager fileExistsAtPath:project])
        [manager createDirectoryAtPath:project withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *local = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"www"];
    NSDirectoryEnumerator *direnum = [manager enumeratorAtPath:local];
    NSMutableArray <NSMutableDictionary *> *array = [NSMutableArray array];
    NSString *filename;
    while (filename = [direnum nextObject]) {
        if (![filename hasPrefix:@"update"]) {
            [manager copyItemAtPath:[local stringByAppendingPathComponent:filename] toPath:[project stringByAppendingPathComponent:filename] error:nil];
            BOOL isDir = NO;
            [manager fileExistsAtPath:[project stringByAppendingPathComponent:filename] isDirectory:&isDir];
            if (!isDir && ![filename hasPrefix:@"cordova"] && ![filename hasPrefix:@"plugins"]) {
                NSString *fileName = [[NSFileManager defaultManager] displayNameAtPath:[project stringByAppendingPathComponent:filename]];
                NSMutableDictionary *dictM = [NSMutableDictionary dictionary];
                NSString *md5 = [self getFileMD5WithPath:[project stringByAppendingPathComponent:filename]];
                [dictM setObject:fileName forKey:@"fileName"];
                [dictM setObject:[NSString stringWithFormat:@"/%@", filename] forKey:@"filePath"];
                [dictM setObject:md5 forKey:@"fileMd5"];
                [array addObject:dictM];
            }
        }
    }
    NSMutableDictionary *dictRoot = [NSMutableDictionary dictionary];
    [dictRoot setObject:[NSString stringWithFormat:@"%d", array.count] forKey:@"count"];
    [dictRoot setObject:array forKey:@"files"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictRoot options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonStr = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    NSString *versionCode = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    [self createFile:manager parent:updates path:[[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates/version.txt"]] content:versionCode];
    [self createFile:manager parent:updates path:[[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates/files.json"]] content:jsonStr];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"success"];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)md5Project:(CDVInvokedUrlCommand *)command {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *library = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *updates = [[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates"]];
    NSString *project = [[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates/project"]];
    NSDirectoryEnumerator *direnum = [manager enumeratorAtPath:project];
    NSMutableArray <NSMutableDictionary *> *array = [NSMutableArray array];
    NSString *filename;
    while (filename = [direnum nextObject]) {
        BOOL isDir = NO;
        [manager fileExistsAtPath:[project stringByAppendingPathComponent:filename] isDirectory:&isDir];
        if (!isDir && ![filename hasPrefix:@"cordova"] && ![filename hasPrefix:@"plugins"]) {
            NSString *fileName = [[NSFileManager defaultManager] displayNameAtPath:[project stringByAppendingPathComponent:filename]];
            NSMutableDictionary *dictM = [NSMutableDictionary dictionary];
            NSString *md5 = [self getFileMD5WithPath:[project stringByAppendingPathComponent:filename]];
            [dictM setObject:fileName forKey:@"fileName"];
            [dictM setObject:[NSString stringWithFormat:@"/%@", filename] forKey:@"filePath"];
            [dictM setObject:md5 forKey:@"fileMd5"];
            [array addObject:dictM];
        }
    }
    NSMutableDictionary *dictRoot = [NSMutableDictionary dictionary];
    [dictRoot setObject:[NSString stringWithFormat:@"%d", array.count] forKey:@"count"];
    [dictRoot setObject:array forKey:@"files"];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictRoot options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonStr = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    [self createFile:manager parent:updates path:[[library objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/NoCloud/updates/files.json"]] content:jsonStr];
}

- (NSString *)getImageName:(UIInterfaceOrientation)currentOrientation delegate:(id <CDVScreenOrientationDelegate>)orientationDelegate device:(CDV_iOSDevice)device {
    NSString *imageName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UILaunchImageFile"];
    if ([self isUsingCDVLaunchScreen]) {
        imageName = @"LaunchStoryboard";
        return imageName;
    }
    NSUInteger supportedOrientations = [orientationDelegate supportedInterfaceOrientations];
    BOOL supportsLandscape = (supportedOrientations & UIInterfaceOrientationMaskLandscape);
    BOOL supportsPortrait = (supportedOrientations & UIInterfaceOrientationMaskPortrait || supportedOrientations & UIInterfaceOrientationMaskPortraitUpsideDown);
    BOOL isOrientationLocked = !(supportsPortrait && supportsLandscape);
    if (imageName)
        imageName = [imageName stringByDeletingPathExtension];
    else
        imageName = @"Default";
    if ([imageName isEqualToString:@"LaunchImage"]) {
        if (device.iPhone4 || device.iPhone5 || device.iPad)
            imageName = [imageName stringByAppendingString:@"-700"];
        else if (device.iPhone6)
            imageName = [imageName stringByAppendingString:@"-800"];
        else if (device.iPhone6Plus || device.iPhoneX) {
            if (device.iPhone6Plus)
                imageName = [imageName stringByAppendingString:@"-800"];
            else
                imageName = [imageName stringByAppendingString:@"-1100"];
            if (currentOrientation == UIInterfaceOrientationPortrait || currentOrientation == UIInterfaceOrientationPortraitUpsideDown)
                imageName = [imageName stringByAppendingString:@"-Portrait"];
        }
    }
    if (device.iPhone5)
        imageName = [imageName stringByAppendingString:@"-568h"];
    else if (device.iPhone6)
        imageName = [imageName stringByAppendingString:@"-667h"];
    else if (device.iPhone6Plus || device.iPhoneX) {
        if (isOrientationLocked)
            imageName = [imageName stringByAppendingString:(supportsLandscape ? @"-Landscape" : @"")];
        else
            switch (currentOrientation) {
                case UIInterfaceOrientationLandscapeLeft:
                case UIInterfaceOrientationLandscapeRight:
                    imageName = [imageName stringByAppendingString:@"-Landscape"];
                    break;
                default:
                    break;
            }
        if (device.iPhoneX)
            imageName = [imageName stringByAppendingString:@"-2436h"];
        else
            imageName = [imageName stringByAppendingString:@"-736h"];
    } else if (device.iPad) {
        if (isOrientationLocked)
            imageName = [imageName stringByAppendingString:(supportsLandscape ? @"-Landscape" : @"-Portrait")];
        else
            switch (currentOrientation) {
                case UIInterfaceOrientationLandscapeLeft:
                case UIInterfaceOrientationLandscapeRight:
                    imageName = [imageName stringByAppendingString:@"-Landscape"];
                    break;
                case UIInterfaceOrientationPortrait:
                case UIInterfaceOrientationPortraitUpsideDown:
                default:
                    imageName = [imageName stringByAppendingString:@"-Portrait"];
                    break;
            }
    }
    return imageName;
}

- (UIInterfaceOrientation)getCurrentOrientation {
    UIInterfaceOrientation iOrientation = [UIApplication sharedApplication].statusBarOrientation;
    UIDeviceOrientation dOrientation = [UIDevice currentDevice].orientation;
    bool landscape;
    if (dOrientation == UIDeviceOrientationUnknown || dOrientation == UIDeviceOrientationFaceUp || dOrientation == UIDeviceOrientationFaceDown)
        landscape = UIInterfaceOrientationIsLandscape(iOrientation);
    else {
        landscape = UIDeviceOrientationIsLandscape(dOrientation);
        if (dOrientation == UIDeviceOrientationLandscapeLeft)
            iOrientation = UIInterfaceOrientationLandscapeRight;
        else if (dOrientation == UIDeviceOrientationLandscapeRight)
            iOrientation = UIInterfaceOrientationLandscapeLeft;
        else if (dOrientation == UIDeviceOrientationPortrait)
            iOrientation = UIInterfaceOrientationPortrait;
        else if (dOrientation == UIDeviceOrientationPortraitUpsideDown)
            iOrientation = UIInterfaceOrientationPortraitUpsideDown;
    }
    return iOrientation;
}

- (CDV_iOSDevice)getCurrentDevice {
    CDV_iOSDevice device;
    UIScreen *mainScreen = [UIScreen mainScreen];
    CGFloat mainScreenHeight = mainScreen.bounds.size.height;
    CGFloat mainScreenWidth = mainScreen.bounds.size.width;
    int limit = MAX(mainScreenHeight, mainScreenWidth);
    device.iPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    device.iPhone = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone);
    device.retina = ([mainScreen scale] == 2.0);
    device.iPhone4 = (device.iPhone && limit == 480.0);
    device.iPhone5 = (device.iPhone && limit == 568.0);
    device.iPhone6 = (device.iPhone && limit == 667.0);
    device.iPhone6Plus = (device.iPhone && limit == 736.0);
    device.iPhoneX = (device.iPhone && limit == 812.0);
    return device;
}

- (BOOL)isUsingCDVLaunchScreen {
    NSString *launchStoryboardName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UILaunchStoryboardName"];
    if (launchStoryboardName)
        return ([launchStoryboardName isEqualToString:@"CDVLaunchScreen"]);
    else
        return NO;
}

- (BOOL)createFile:(NSFileManager *)manager parent:(NSString *)parent path:(NSString *)path content:(NSString *)content {
    if (![manager fileExistsAtPath:parent])
        [manager createDirectoryAtPath:parent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
    return [manager createFileAtPath:path contents:data attributes:nil];
}

- (NSString *)getFileMD5WithPath:(NSString *)path {
    return (__bridge_transfer NSString *) FileMD5HashCreateWithPath((__bridge CFStringRef) path, FileHashDefaultChunkSizeForReadingData);
}

CFStringRef FileMD5HashCreateWithPath(CFStringRef filePath, size_t chunkSizeForReadingData) {
    CFStringRef result = NULL;
    CFReadStreamRef readStream = NULL;
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef) filePath, kCFURLPOSIXPathStyle, (Boolean) false);
    CC_MD5_CTX hashObject;
    bool hasMoreData = true;
    bool didSucceed;
    if (!fileURL) goto done;
    readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, (CFURLRef) fileURL);
    if (!readStream) goto done;
    didSucceed = (bool) CFReadStreamOpen(readStream);
    if (!didSucceed) goto done;
    CC_MD5_Init(&hashObject);
    if (!chunkSizeForReadingData)
        chunkSizeForReadingData = FileHashDefaultChunkSizeForReadingData;
    while (hasMoreData) {
        uint8_t buffer[chunkSizeForReadingData];
        CFIndex readBytesCount = CFReadStreamRead(readStream, (UInt8 *) buffer, (CFIndex) sizeof(buffer));
        if (readBytesCount == -1) break;
        if (readBytesCount == 0) {
            hasMoreData = false;
            continue;
        }
        CC_MD5_Update(&hashObject, (const void *) buffer, (CC_LONG) readBytesCount);
    }
    didSucceed = !hasMoreData;
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &hashObject);
    if (!didSucceed) goto done;
    char hash[2 * sizeof(digest) + 1];
    for (size_t i = 0; i < sizeof(digest); ++i)
        snprintf(hash + (2 * i), 3, "%02x", (int) (digest[i]));
    result = CFStringCreateWithCString(kCFAllocatorDefault, (const char *) hash, kCFStringEncodingUTF8);
    done:
    if (readStream) {
        CFReadStreamClose(readStream);
        CFRelease(readStream);
    }
    if (fileURL)
        CFRelease(fileURL);
    return result;
}

@end
