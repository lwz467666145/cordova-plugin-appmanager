#import <Cordova/CDVPlugin.h>

typedef struct {
    BOOL iPhone;
    BOOL iPad;
    BOOL iPhone4;
    BOOL iPhone5;
    BOOL iPhone6;
    BOOL iPhone6Plus;
    BOOL retina;
    BOOL iPhoneX;
    
} CDV_iOSDevice;

@interface AppManager : CDVPlugin
    
- (void)openApp:(CDVInvokedUrlCommand*)command;
- (void)hasApp:(CDVInvokedUrlCommand*)command;
- (void)exitApp:(CDVInvokedUrlCommand*)command;
- (void)getPic:(CDVInvokedUrlCommand*)command;
- (void)checkProject:(CDVInvokedUrlCommand*)command;
- (void)unzipProject:(CDVInvokedUrlCommand*)command;
- (void)md5Project:(CDVInvokedUrlCommand*)command;
    
@end
