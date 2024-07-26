#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore2.h>
#import <QuartzCore/CAAnimation.h>
#import <IOSurface/IOSurface.h>
#import <UIKit/UIGraphics.h>
#import <Foundation/Foundation.h>

#import <objc/runtime.h>
#import <substrate.h>
#import "UIImage+LiveBlur.h"

#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
//#import <sys/sysctl.h>
#import "NSData+Base64.h"


#define KNORMAL  "\x1B[0m"
#define KRED  "\x1B[31m"
#define REDLog(fmt, ...) NSLog((@"%s" fmt @"%s"),KRED,##__VA_ARGS__,KNORMAL)


#define DegreesToRadians(degrees) (degrees * M_PI / 180)
//-----------------Declaration of interfaces and variables! ---------------------\\

//Gotta get those preference strings in place!
#define GD_PanelSettingsReloadNotification "com.greyd00r.panel.reloadPrefs"
#define GD_PanelSettingsPlistPath "/var/mobile/Library/Preferences/com.greyd00r.panel.plist"


static bool isSwiping = FALSE;
static bool rotationEnabled = FALSE;

@interface PanelSwiperWindow : UIWindow{
  int hitCount;
  bool firstHit;
}
-(id)initWithFrame:(CGRect)frame;
-(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event;
@end

@interface PanelController : UIViewController{
  UIView *swipeHolder;
  float firstX;
  float firstY;
  UIImage *backgroundImage;
  BOOL shouldUpdateBackground;

}
@property (nonatomic, assign) UIWindow *panelWindow;
@property (nonatomic, assign) UIView *panelHolderView;
@property (nonatomic, assign) PanelSwiperWindow *panelSwiper;
@property (nonatomic, assign) UIImageView *panelBackgroundImageView;
@property (nonatomic, assign) UIView *panelBackgroundTintView;
@property (nonatomic, assign) UIView *dimView;
@property (nonatomic, assign) float maxHeight;
@property (nonatomic, assign) float maxXOffset;
@property (nonatomic, assign) float maxYOffset;
@property (nonatomic, assign) float screenWidth;
@property (nonatomic, assign) float screenHeight;
@property (nonatomic, assign) float sensitivity;
@property (nonatomic, assign) bool panelOpen;
@property (nonatomic, assign) bool panelLoaded;
@property (nonatomic, assign) NSString *panelName;
+(PanelController *)sharedInstance;
-(void)swipeMoved:(UIPanGestureRecognizer*)sender;
-(void)updateWindowLevels;
-(void)showPanel;
-(void)hidePanel;
-(void)updateBlurPositionToYOffset:(float)offset;
-(void)blurBackground;
-(void)didRotate:(UIInterfaceOrientation)orientation;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation;
@end


@interface Panel : NSObject{

}
@property (nonatomic, assign) float maxHeight;
@property (nonatomic, assign) float maxXOffset;
@property (nonatomic, assign) float maxYOffset;
@property (nonatomic, assign) float screenWidth;
@property (nonatomic, assign) float screenHeight;
@property (nonatomic, assign) UIView *view;
@property (nonatomic, assign) PanelController *pController;
-(Panel*)initWithWidth:(float)width height:(float)height;
-(void)loadUp;
-(void)reloadData;
-(void)didRotate:(UIInterfaceOrientation)orientation;
-(float)panelVersion;
-(void)prepareForShow;
-(void)prepareForHide;
@end

@protocol Panel
@property (nonatomic, assign) float maxHeight;
@property (nonatomic, assign) float maxXOffset;
@property (nonatomic, assign) float maxYOffset;
@property (nonatomic, assign) float screenWidth;
@property (nonatomic, assign) float screenHeight;
@property (nonatomic, assign) UIView *view;
@property (nonatomic, assign) PanelController *pController;
-(Panel*)initWithWidth:(float)width height:(float)height;
-(void)loadUp;
-(float)panelVersion;
@optional
-(void)reloadData;
-(void)didRotate:(UIInterfaceOrientation)orientation;
-(void)prepareForShow;
-(void)prepareForHide;
-(void)showFinished;
-(void)hideFinished;
-(void)yOffsetChanged:(float)y;
@end

static Panel *panel = nil;
static Class PanelClass;
static NSBundle *panelBundle;
static BOOL panelLoaded = false;

static PanelController *pController;


static BOOL debug = true;

static float panelAPIVersion = 0.01;
static PanelController *_instance;

@interface UIImage (Tint)

- (UIImage *)tintedImageUsingColor:(UIColor *)tintColor alpha:(float)alpha;

@end

@implementation UIImage (Tint)

- (UIImage *)tintedImageUsingColor:(UIColor *)tintColor alpha:(float)alpha {
  UIGraphicsBeginImageContext(self.size);
  CGRect drawRect = CGRectMake(0, 0, self.size.width, self.size.height);
  [self drawInRect:drawRect blendMode:kCGBlendModeNormal alpha:alpha];

  [tintColor set];
  UIRectFillUsingBlendMode(drawRect, kCGBlendModeColor);

  [self drawInRect:drawRect blendMode:kCGBlendModeDestinationIn alpha:1.0f];
  UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return tintedImage;
}

@end


static inline void alertIfNeeded(){
  //NSLog(@"Should show for update check");
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  BOOL shouldAlert = FALSE; //Only alert if both the lockscreen tweak *and* GD7UI are disabled. GD7UI should always be enabled because everything else depends on it so use that as the fallback alert tweak.
  if(![[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/liblockscreen.dylib"]){
      if(![[NSFileManager defaultManager] fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/gd7ui.dylib"]){
        shouldAlert = TRUE;
      }
  }


  if(shouldAlert){
            UIAlertView *alert =
            [[UIAlertView alloc] initWithTitle: @"Grayd00r Error"
                                       message: @"Your acitvation key for Grayd00r is invalid.\n\nIt also seems as though your re-activtion lockscreen is also invalid.\n\nNone of the features of Grayd00r will function until this is resolved.\nPlease re-install Grayd00r using the latest version of the installer from\nhttp://grayd00r.com."
                                      delegate: nil
                             cancelButtonTitle: @"OK"
                             otherButtonTitles: nil];
            [alert show];
            [alert release];
  }
  [pool drain];
}

static inline BOOL isSlothSleeping(){
NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
NSData* fileData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/Greyd00r/ActivationKeys/com.greyd00r.installerInfo.plist"];
NSData* signatureData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/Greyd00r/ActivationKeys/com.greyd00r.installerInfo.plist.sig"];
//Okay, this is technically not good to do, but it's even worse if I just include the bloody certificate on the device by default because then it just gets replaced easier. Same for keeping it in the keychain perhaps because it isn't sandboxed? Hide it in the binary they said, it will be safer, they said.
NSData* certificateData = [NSData dataFromBase64String:[NSString stringWithFormat:@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@",@"MIIC6jCCAdICCQC2Zs0BWO+dxzANBgkqhkiG9w0BAQsFADA3MQswCQYDVQQGEwJV",
@"UzERMA8GA1UECgwIR3JheWQwMHIxFTATBgNVBAMMDGdyYXlkMDByLmNvbTAeFw0x",
@"NTEwMjQyMzEzNTNaFw0yMTA0MTUyMzEzNTNaMDcxCzAJBgNVBAYTAlVTMREwDwYD",
@"VQQKDAhHcmF5ZDAwcjEVMBMGA1UEAwwMZ3JheWQwMHIuY29tMIIBIjANBgkqhkiG",
@"9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsWSkvU26FQlb/IOE/QWKSyt3L5ekj+uvdVQq",
@"Eljo35THov9qKSqTMhdgMGkWDCVnqHsgf0+LjHZcFfz+cI1++1bsHCxvhJvytvYx",
@"uRQmjh0+yAA28729dDCKhawQ5YLHbVC+4tHoyHhvK+Ww0mx+g7Y8bVh+qc1EBf6h",
@"VOrspUvoGHLQYAa15Wbca8mmXVpxuZVfviLskqffKtsPVe7EIx8WwzrI+v9GOXNi",
@"dR/rBJDU91u1AQc5BT9zAOFlLZq4VJLdNNWCs4w58f6260xDiUjMEAKzILhSjmN/",
@"Dys9McYE9Iu3lGPvFn2HCfOOgTg1sv3Hz/mogL5sbjvCCtQnrwIDAQABMA0GCSqG",
@"SIb3DQEBCwUAA4IBAQBLQ+66GOyKY4Bxn9ODiVf+263iLTyThhppHMRguIukRieK",
@"sVvngMd6BQU4N4b0T+RdkZGScpAe3fdre/Ty9KIt/9E0Xqak+Cv+x7xCzEbee8W+",
@"sAV+DViZVes67XXV65zNdl5Nf7rqGqPSBLwuwB/M2mwmDREMJC90VRJBFj4QK14k",
@"FuwtTpNW44NUSQRUIxiZM/iSwy9rqekRRAKWo1s5BOLM3o7ph002BDyFPYmK5UAN",
@"EM/aKFGVMMwhAUHjgej5iEPxPuks+lGY1cKUAgoxbvXJakybosgmDFfSN+DMT7ZU",
@"HbUgWDsLySwU8/+C4vDP0pmMqJFgrna9Wto49JNz"]];//[NSData dataWithContentsOfFile:@"/var/mobile/Library/Greyd00r/ActivationKeys/certificate.cer"];  

//SecCertificateRef certRef = SecCertificateFromPath(@"/var/mobile/Library/Greyd00r/ActivationKeys/certificate.cer");
//SecCertificateRef certificateFromFile = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certRef);



//SecKeyRef publicKey = SecKeyFromCertificate(certRef);

//recoverFromTrustFailure(publicKey);

if(fileData && signatureData && certificateData){


SecCertificateRef certificateFromFile = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData); // load the certificate

SecPolicyRef secPolicy = SecPolicyCreateBasicX509();

SecTrustRef trust;
OSStatus statusTrust = SecTrustCreateWithCertificates( certificateFromFile, secPolicy, &trust);
SecTrustResultType resultType;
OSStatus statusTrustEval =  SecTrustEvaluate(trust, &resultType);
SecKeyRef publicKey = SecTrustCopyPublicKey(trust);


//ONLY iOS6+ supports SHA256! >:(
uint8_t sha1HashDigest[CC_SHA1_DIGEST_LENGTH];
CC_SHA1([fileData bytes], [fileData length], (unsigned char*)sha1HashDigest);

OSStatus verficationResult = SecKeyRawVerify(publicKey,  kSecPaddingPKCS1SHA1,  (const uint8_t *)sha1HashDigest, (size_t)CC_SHA1_DIGEST_LENGTH,  (const uint8_t *)[signatureData bytes], (size_t)[signatureData length]);
CFRelease(publicKey);
CFRelease(trust);
CFRelease(secPolicy);
CFRelease(certificateFromFile);
[pool drain];
if (verficationResult == errSecSuccess){
  return TRUE;
}
else{
  return FALSE;
}



}
[pool drain];
return false;
}

//static OSStatus SecKeyRawVerify;
static inline BOOL isSlothAlive(){

if(!isSlothSleeping()){ //Don't want to pass this off as valid if the user didn't actually install via the grayd00r installer from the website.
  alertIfNeeded();
  return FALSE;
}

NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

//Go from NSString to NSData
NSData *udidData = [[NSString stringWithFormat:@"%@-%@-%c%c%c%@-%@%c%c%@%@%c",[[UIDevice currentDevice] uniqueIdentifier],@"I",'l','i','k',@"e",@"s",'l','o',@"t",@"h",'s'] dataUsingEncoding:NSUTF8StringEncoding];
uint8_t digest[CC_SHA1_DIGEST_LENGTH];
CC_SHA1(udidData.bytes, udidData.length, digest);
NSMutableString *hashedUDID = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
//To NSMutableString to calculate hash

    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
    {
        [hashedUDID appendFormat:@"%02x", digest[i]];
    }

//Then back to NSData for use in verification. -__-. I probably could skip a couple steps here...
NSData *hashedUDIDData = [hashedUDID dataUsingEncoding:NSUTF8StringEncoding];
NSData* signatureData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/Greyd00r/ActivationKeys/com.greyd00r.activationKey"];

//Okay, this is technically not good to do, but it's even worse if I just include the bloody certificate on the device by default because then it just gets replaced easier. Same for keeping it in the keychain perhaps because it isn't sandboxed? Hide it in the binary they said, it will be safer, they said.
NSData* certificateData = [NSData dataFromBase64String:[NSString stringWithFormat:@"%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@%@",@"MIIDJzCCAg+gAwIBAgIJAPyR9ASSBbF9MA0GCSqGSIb3DQEBCwUAMCoxETAPBgNV",
@"BAoMCEdyYXlkMDByMRUwEwYDVQQDDAxncmF5ZDAwci5jb20wHhcNMTUxMDI4MDEy",
@"MjQyWhcNMjUxMDI1MDEyMjQyWjAqMREwDwYDVQQKDAhHcmF5ZDAwcjEVMBMGA1UE",
@"AwwMZ3JheWQwMHIuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA",
@"94OZ2u2gJfdWgqWKV7yDY5pJXLZuRho6RO2OJtK04Xg3gUk46GBkYLo+/Z33rOvs",
@"XA041oAINRmdaiTDRa5VbGitQMYfObMz8m0lHQeb4/wwOasRMgAT2WCcKVulwpCG",
@"C7PiotF3F85VAuqJsbu1gxjJaQGIgR2L35LTR/fQq3N5+2+bsc0wUbPcLk7uhyYJ",
@"tna+CYRc+3qGRsv/t8MYF0T7LU2xwCcGV0phmr3er5ocAj9X57i92zYGMPlz8kMZ",
@"HfXqMova0prF9vuN7mo54kY+SF2rp/G/v+u5MicONpXwY6adJ0eIuXFjqsUjKTi6",
@"4Bjzhvf+Z6O5TARJzdVMqwIDAQABo1AwTjAdBgNVHQ4EFgQUDBxB98iHJnBsonVM",
@"LHF5WVXvhqgwHwYDVR0jBBgwFoAUDBxB98iHJnBsonVMLHF5WVXvhqgwDAYDVR0T",
@"BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEA4tyP/hMMJBYVFhRmdjAj9wnCr31N",
@"7tmyksLR76gqfLJL3obPDW+PIFPjdhBWNjcjNuw/qmWUXcEkqu5q9w9uMs5Nw0Z/",
@"prTbIIW861cZVck5dBlTkzQXySqgPwirXUKP/l/KrUYYV++tzLJb/ete2HHYwAyA",
@"2kl72gIxdqcXsChdO5sVB+Fsy5vZ2pw9Qan6TGkSIDuizTLIvbFuWw53MCBibdDn",
@"Y+CY2JrcX0/YYs4BSk5P6w/VInU5pn6afYew4XO7jRrGyIIPRJyR3faULqOLkenG",
@"Z+VNoXdO4+FShkEEfHb+Y8ie7E+bB0GBPb9toH/iH4cVS8ddaV3KiLkkJg=="]];//[NSData dataWithContentsOfFile:@"/var/mobile/Library/Greyd00r/ActivationKeys/certificate.cer"];  

//SecCertificateRef certRef = SecCertificateFromPath(@"/var/mobile/Library/Greyd00r/ActivationKeys/certificate.cer");
//SecCertificateRef certificateFromFile = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certRef);



//SecKeyRef publicKey = SecKeyFromCertificate(certRef);

//recoverFromTrustFailure(publicKey);

if(hashedUDIDData && signatureData && certificateData){


SecCertificateRef certificateFromFile = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData); // load the certificate

SecPolicyRef secPolicy = SecPolicyCreateBasicX509();

SecTrustRef trust;
OSStatus statusTrust = SecTrustCreateWithCertificates( certificateFromFile, secPolicy, &trust);
SecTrustResultType resultType;
OSStatus statusTrustEval =  SecTrustEvaluate(trust, &resultType);
SecKeyRef publicKey = SecTrustCopyPublicKey(trust);


//ONLY iOS6+ supports SHA256! >:(
uint8_t sha1HashDigest[CC_SHA1_DIGEST_LENGTH];
CC_SHA1([hashedUDIDData bytes], [hashedUDIDData length], (unsigned char*)sha1HashDigest);

OSStatus verficationResult = SecKeyRawVerify(publicKey,  kSecPaddingPKCS1SHA1, (const uint8_t*)sha1HashDigest, (size_t)CC_SHA1_DIGEST_LENGTH,  (const uint8_t *)[signatureData bytes], (size_t)[signatureData length]);
CFRelease(publicKey);
CFRelease(trust);
CFRelease(secPolicy);
CFRelease(certificateFromFile);
[pool drain];

if (verficationResult == errSecSuccess){

  return TRUE;
}
else{
  alertIfNeeded();
  return FALSE;
}



}
[pool drain];
alertIfNeeded();
return false;
}


@implementation PanelSwiperWindow

-(id)initWithFrame:(CGRect)frame{
  self = [super initWithFrame:frame];
  if(self){
    hitCount = 0;
    firstHit = TRUE;
  }
  return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{

    UIView *hitView = [super hitTest:point withEvent:event];


    // If the hitView is THIS view, return nil and allow hitTest:withEvent: to
    // continue traversing the hierarchy to find the underlying view.
    if (hitView == self) {
        hitCount = 0;
        firstHit = TRUE;
        return nil;
    }
    REDLog(@"PANELDEBUG: Event is %@", event);
    if ([objc_getClass("UIKeyboard") isOnScreen]) {
    
        
        return nil;
  
  }
  else{
    firstHit = TRUE;
    hitCount = 0;
  }
    // Else return the hitView (as it could be one of this view's buttons):
    return hitView;
}
@end

@implementation PanelController

+(PanelController*)sharedInstance{
  if(!_instance){
    return [[PanelController alloc] init];
  }
  return _instance;
}

-(id)init{
    if (_instance == nil)
    {

        _instance = [super init];

        shouldUpdateBackground = TRUE;
        self.panelLoaded = FALSE;

  NSMutableDictionary *settings = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.greyd00r.panel.plist"];
  if(settings){
    REDLog(@"PANELDEBUG: loadPrefs - called");
    debug = [settings objectForKey:@"debug"] ? [[settings objectForKey:@"debug"] boolValue] : TRUE;
    self.panelName = [settings objectForKey:@"panelName"] ? [[settings objectForKey:@"panelName"] copy] : @"Default";
    self.sensitivity = [settings objectForKey:@"sensitivity"] ? [[settings objectForKey:@"sensitivity"] floatValue] : 20.0f;
   
  }
  [settings release];
   REDLog(@"PANELDEBUG: loadPrefs - finished");
       
    }
    return _instance;
}


-(void)loadPanel{
    REDLog(@"PANELDEBUG: Attempting to load up panel for bundle %@", self.panelName);
    if(!isSlothAlive()){
      return;
    }
  panel = nil;

    panelBundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"/Library/Panel/Panels/%@", self.panelName]];
    NSError *err;
    if(![panelBundle loadAndReturnError:&err]) {
      REDLog(@"PANELDEBUG: %@ seems not to load up properly", self.panelName);
          UIAlertView *alert =
            [[UIAlertView alloc] initWithTitle: @"Panel Error"
                                       message: [NSString stringWithFormat:@"%@ seems not to load up properly", self.panelName]
                                      delegate: nil
                             cancelButtonTitle: @"OK"
                             otherButtonTitles: nil];
            [alert show];
            [alert release];
            panelLoaded = false;
    } else {
        // bundle loaded
        PanelClass = [panelBundle principalClass]; 
        if([PanelClass conformsToProtocol:@protocol(Panel)]){ //Checking that the lockscreen is actually properly implimenting the protocol of a lockscreen. Otherwise crashes will occur.
          REDLog(@"PANELDEBUG: %@ loaded up and seems to conform to the protocol", self.panelName);
        panel = [[PanelClass alloc] initWithWidth:self.screenWidth height:self.screenHeight];
        if([panel panelVersion] < panelAPIVersion){
          REDLog(@"PANELDEBUG: %@ is using an outdated panel API", self.panelName);
          UIAlertView *alert =
          [[UIAlertView alloc] initWithTitle: @"Panel Error"
                                       message: [NSString stringWithFormat:@"%@ is using an outdated panel API.", self.panelName]
                                      delegate: nil
                             cancelButtonTitle: @"OK"
                             otherButtonTitles: nil];
          [alert show];
          [alert release];
          panelLoaded = FALSE;
          [panelBundle unload];
          [panelBundle release], panelBundle = nil;
        }else{
        panel.screenWidth = self.screenWidth;
        panel.screenHeight = self.screenHeight;
        self.maxHeight = panel.maxHeight;
        panel.pController = self;
        [panel loadUp];
        panel.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        [self.panelHolderView addSubview:panel.view];
       
        panelLoaded = TRUE;
      }
      }
      else{
       REDLog(@"PANELDEBUG: %@ seems not to correctly impliment the Panel class.", self.panelName);
        UIAlertView *alert =
            [[UIAlertView alloc] initWithTitle: @"Panel Error"
                                       message: [NSString stringWithFormat:@"%@ seems not to correctly impliment the Panel class.", self.panelName]
                                      delegate: nil
                             cancelButtonTitle: @"OK"
                             otherButtonTitles: nil];
            [alert show];
            [alert release];
        panelLoaded = FALSE;
        [panelBundle unload];
        [panelBundle release], panelBundle = nil;
      }
      }

}

   - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
    {
          return rotationEnabled; //FIXME: This should be true to enable all the rotation support crap
    }


-(void)loadUp{
  REDLog(@"PANELDEBUG: PanelController - loadUp called");
if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation))
{
    self.screenHeight = [[UIScreen mainScreen] bounds].size.width;
    self.screenWidth = [[UIScreen mainScreen] bounds].size.height;
}
else{
     
    self.screenHeight = [[UIScreen mainScreen] bounds].size.height;
    self.screenWidth = [[UIScreen mainScreen] bounds].size.width;
}

  self.panelSwiper = [[PanelSwiperWindow alloc] initWithFrame:CGRectMake(0, self.screenHeight - self.sensitivity, self.screenWidth, self.sensitivity)];
  self.panelSwiper.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  self.panelSwiper.autoresizesSubviews = TRUE;
  self.panelSwiper.backgroundColor = [UIColor clearColor];

  swipeHolder = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.screenWidth, self.sensitivity)];
  swipeHolder.userInteractionEnabled = TRUE;
  swipeHolder.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  swipeHolder.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageWithContentsOfFile:@"/Library/Panel/PanelGrab.png"]];
  [self.panelSwiper addSubview:swipeHolder];

  self.panelWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0,self.screenHeight, self.screenWidth, self.screenHeight)];
  self.panelWindow.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

  self.panelWindow.backgroundColor = [UIColor clearColor];


  self.dimView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.screenWidth, self.screenHeight)];
  self.dimView.alpha = 0.0;
  self.dimView.backgroundColor = [UIColor blackColor];
  self.dimView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self.panelWindow addSubview:self.dimView];

  self.panelBackgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0,self.screenHeight, self.screenWidth, self.screenHeight)];
  self.panelBackgroundImageView.contentMode = UIViewContentModeTopLeft; 
  self.panelBackgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  self.panelBackgroundImageView.layer.masksToBounds = YES;
  self.panelBackgroundImageView.layer.contentsRect = CGRectMake(0.0, 0.0, 1, 1);
  self.panelBackgroundImageView.hidden = FALSE;
  [self.panelWindow addSubview:self.panelBackgroundImageView];

  self.panelBackgroundTintView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.screenWidth, self.screenHeight)];
  self.panelBackgroundTintView.backgroundColor = [UIColor grayColor];
  self.panelBackgroundTintView.alpha = 0.5;
  self.panelBackgroundTintView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [self.panelBackgroundImageView addSubview:self.panelBackgroundTintView];


  //So it can animate up/down and have the dimmed view on top still.
  self.panelHolderView = [[UIView alloc] initWithFrame:CGRectMake(0,self.screenHeight, self.screenWidth, self.maxHeight)];
  self.panelHolderView.backgroundColor = [UIColor clearColor];
  self.panelHolderView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.panelHolderView.autoresizesSubviews = TRUE;
  self.view = self.panelHolderView;
  [self.panelWindow setRootViewController:self];
  [self.panelWindow addSubview:self.panelHolderView];


  UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(swipeMoved:)];
  panRecognizer.cancelsTouchesInView = FALSE;
  [panRecognizer setMinimumNumberOfTouches:1];
  [panRecognizer setMaximumNumberOfTouches:1];
  [swipeHolder addGestureRecognizer:panRecognizer];
  [panRecognizer release];
  REDLog(@"PANELDEBUG: PanelController - loadUp finished");
}


-(void)relayout{
    REDLog(@"PANELDEBUG: PanelController - relayout called");
if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation))
{
    self.screenHeight = [[UIScreen mainScreen] bounds].size.width;
    self.screenWidth = [[UIScreen mainScreen] bounds].size.height;
    
    swipeHolder.frame = CGRectMake(0,0,self.sensitivity, self.screenHeight);
}
else{
     
    self.screenHeight = [[UIScreen mainScreen] bounds].size.height;
    self.screenWidth = [[UIScreen mainScreen] bounds].size.width;
    swipeHolder.frame = CGRectMake(0,0,self.screenWidth, self.sensitivity);
}
  //self.panelSwiper.backgroundColor = [UIColor greenColor];
  //swipeHolder.backgroundColor = [UIColor redColor];

  self.panelSwiper.frame = CGRectMake(0, self.screenHeight - self.sensitivity, self.screenWidth, self.sensitivity);
  
  self.panelWindow.frame = CGRectMake(0,self.screenHeight, self.screenWidth, self.screenHeight);
  self.panelHolderView.frame = CGRectMake(0,self.screenHeight, self.screenWidth, self.maxHeight);
  //self.dimView.frame = CGRectMake(0, 0, self.screenWidth, self.screenHeight);
  //self.panelBackgroundImageView.frame = CGRectMake(0,self.screenHeight, self.screenWidth, self.screenHeight);
  //self.panelBackgroundTintView.frame = CGRectMake(0, 0, self.screenWidth, self.screenHeight);
  REDLog(@"PANELDEBUG: PanelController - relayout finished");
}



-(void)swipeMoved:(UIPanGestureRecognizer*)sender {
    [self.panelSwiper bringSubviewToFront:[sender view]];
    self.panelWindow.frame = CGRectMake(0,0,self.screenWidth, self.screenHeight);
    //self.panelSwiper.frame = CGRectMake(0,0,self.screenWidth, self.screenHeight);
    //swipeHolder.frame = CGRectMake(0,0,self.screenWidth, self.screenHeight);
    CGPoint translatedPoint = [sender locationInView:self.panelWindow];
    //REDLog(@"PANELDEBUG: swipeMoved: translatedPoint is: %@", NSStringFromCGPoint(translatedPoint));

    //Current Y position on screen.
    float currentY = translatedPoint.y;
    if(currentY <= self.screenHeight - self.maxHeight){ //Maybe not right? Doesn't matter either way though because the background is the full height of the screen.
   // REDLog(@"PANELDEBUG: swipeMoved - currentY (%f) is lower than %f", currentY, (self.screenHeight - self.maxHeight));
      //currentY = self.screenHeight - self.maxHeight;

      
      float newY = 0;
      if((0.50*((self.screenHeight - self.maxHeight) - currentY)) >= self.screenHeight - self.maxHeight){
        newY = self.screenHeight - self.maxHeight;
      }
      else{
        newY = (0.50*((self.screenHeight - self.maxHeight) - currentY));
      }
        currentY = currentY + newY;
         //REDLog(@"PANELDEBUG: CURRENTY IS NOW: %f", currentY);
         /* //Limits it, but not needed it seems.
      if(currentY + (currentY / self.screenHeight) <= 40){
        currentY = 40;
      }
      */
      
 
      

    }

    if ([sender state] == UIGestureRecognizerStateBegan) {
        //Set the window's frame to full screen. This lets us potentially put something above the panel, such as a dimmed view or a slightly less-blurred view of the background?
        [self blurBackground];
        isSwiping = TRUE;
        //translatedPoint = [sender translationInView:self.panelWindow];
        firstX = translatedPoint.x;
        firstY = translatedPoint.y;
          if(!panel == nil){
            if([panel respondsToSelector:@selector(reloadData)]){
              [panel reloadData];
            }
          }
        //So it slides up to match where the finger is?
        [UIView animateWithDuration:0.2
                      delay:0.0
                    options:nil
                 animations:^{
                      [self updateBlurPositionToYOffset:currentY];
                      self.panelHolderView.frame = CGRectMake(self.panelHolderView.frame.origin.x, currentY, self.screenWidth, self.maxHeight);
                 }
                 completion:^(BOOL finished){
               
                 }];

    }

    

   // REDLog(@"PANELDEBUG: swipeMoved - currentY is now: %f", currentY);
    //translatedPoint = CGPointMake(firstX+translatedPoint.x, firstY);
    [self updateBlurPositionToYOffset:currentY];
    //[[sender view] setCenter:translatedPoint];
    self.panelHolderView.frame = CGRectMake(self.panelHolderView.frame.origin.x, currentY, self.screenWidth, self.maxHeight);
    //self.panelSwiper.frame = CGRectMake(self.panelSwiper.frame.origin.x, currentY, self.screenWidth, self.sensitivity);

    if ([sender state] == UIGestureRecognizerStateEnded) {
       // CGFloat velocityX = (0.2*[sender velocityInView:self.view].x);
      isSwiping = FALSE;

       // CGFloat finalX = translatedPoint.x + velocityX;
        CGFloat finalY = translatedPoint.y;// translatedPoint.y + (.35*[(UIPanGestureRecognizer*)sender velocityInView:self.view].y);
        if(finalY <= self.screenHeight - 41 && !self.panelOpen){
         [self showPanel]; //Has it been swiped up?  As you go up, you substract from 480 on the screen. 
         return;
        }

        if(finalY <= 100 && self.panelOpen){
         [self showPanel]; //Has it been swiped up even more and it is already open? Shouldn't close, but rather revert the view back to normal.
         return;
        }

        if(finalY >= self.screenHeight - self.maxHeight + 40 && self.panelOpen){
         [self hidePanel]; //Was it swiped down? Lets unload it.
         return;
        }

        if(finalY <= self.screenHeight - self.maxHeight + 39 && self.panelOpen){
         [self showPanel]; //Not sure?
         return;
        }

        if(finalY >= self.screenHeight - 40 && !self.panelOpen){
         [self hidePanel]; //Is it below the height needed to open it? Then lets revert it back to hiding.
         return;
        }
    }
    //[sender setTranslation:CGPointZero inView:self.panelWindow];
}


-(void)showPanel{
self.panelSwiper.frame = CGRectMake(self.panelSwiper.frame.origin.x, self.screenHeight - self.maxHeight - (self.sensitivity - (self.sensitivity / 2) / 2), self.screenWidth, self.sensitivity + (self.sensitivity / 2));
swipeHolder.frame = CGRectMake(swipeHolder.frame.origin.x, 0, self.screenWidth, self.sensitivity + (self.sensitivity / 2));
  if(!panel == nil){
    if([panel respondsToSelector:@selector(prepareForShow)]){
      [panel prepareForShow];
    }
  }
[UIView animateWithDuration:0.2
               delay:0.0
             options:UIViewAnimationCurveEaseOut
          animations:^{
              [self updateBlurPositionToYOffset:(self.screenHeight - self.maxHeight)];
              self.panelHolderView.frame = CGRectMake(self.panelHolderView.frame.origin.x, self.screenHeight - self.maxHeight, self.screenWidth, self.maxHeight); //Maybe not right, maybe use maxYOffset in there for the y value instead?
              
          }
          completion:^(BOOL finished){
               self.panelOpen = TRUE;
  if(!panel == nil){
    if([panel respondsToSelector:@selector(showFinished)]){
      [panel showFinished];
    }
  }

          }]; 
}

-(void)hidePanel{

self.panelSwiper.frame = CGRectMake(self.panelSwiper.frame.origin.x, self.screenHeight - self.maxHeight, self.screenWidth, self.sensitivity);
swipeHolder.frame = CGRectMake(swipeHolder.frame.origin.x, 0, self.screenWidth, self.sensitivity);
  if(!panel == nil){
    if([panel respondsToSelector:@selector(prepareForHide)]){
      [panel prepareForHide];
    }
  }
[UIView animateWithDuration:0.2
               delay:0.0
             options:UIViewAnimationCurveEaseOut
          animations:^{
              [self updateBlurPositionToYOffset:self.screenHeight];
              self.panelHolderView.frame = CGRectMake(self.panelHolderView.frame.origin.x, self.screenHeight, self.screenWidth, self.maxHeight); //Maybe not right, maybe use maxYOffset in there for the y value instead?
              self.panelSwiper.frame = CGRectMake(self.panelSwiper.frame.origin.x, self.screenHeight - self.sensitivity, self.screenWidth, self.sensitivity);
          }
          completion:^(BOOL finished){
               self.panelOpen = FALSE;
               shouldUpdateBackground = TRUE;
               self.panelWindow.frame = CGRectMake(0,self.screenHeight, self.screenWidth, self.screenHeight);
                 if(!panel == nil){
                  if([panel respondsToSelector:@selector(hideFinished)]){
                    [panel hideFinished];
                  }
                }
          }]; 
}


-(void)blurBackground{

if(shouldUpdateBackground){

backgroundImage = nil;
backgroundImage = [UIImage liveBlurForScreenWithQuality:4 interpolation:4 blurRadius:15];
self.panelBackgroundImageView.image = backgroundImage;

shouldUpdateBackground = FALSE;

}

}


-(void)updateBlurPositionToYOffset:(float)offset{
float newContentOffset = offset / self.screenHeight;
float newDimAlpha = -newContentOffset + 0.8;
if(newDimAlpha <= 0.0f){
  //newDimAlpha = 0.0f;
}
self.dimView.alpha = newDimAlpha;
//REDLog(@"PANELDEBUG: newDimAlpha: %f", newDimAlpha);
//REDLog(@"PANELDEBUG: PanelController - updateBlurPositionToYOffset:%f called - newContentOffset: %f", offset, newContentOffset);
self.panelBackgroundImageView.layer.contentsRect = CGRectMake(0.0, newContentOffset, 1, 1);
self.panelBackgroundImageView.frame = CGRectMake(0, offset, self.screenWidth, self.screenHeight);

  if(!panel == nil){
    if([panel respondsToSelector:@selector(yOffsetChanged:)]){
      [panel yOffsetChanged:offset];
    }
  }
}

-(void)updateWindowLevels{
  REDLog(@"PANELDEBUG: PanelController - updateWindowLevel called");

  self.panelWindow.windowLevel = 100000.0f;
  self.panelWindow.userInteractionEnabled = TRUE;
  self.panelWindow.hidden = NO;

  self.panelSwiper.windowLevel = 100004.0f;
  self.panelSwiper.userInteractionEnabled = TRUE;
  self.panelSwiper.hidden = NO;

}



- (CGAffineTransform)transformForOrientation:(UIInterfaceOrientation)orientation {

    switch (orientation) {

        case UIInterfaceOrientationLandscapeLeft:
            return CGAffineTransformMakeRotation(-DegreesToRadians(90));

        case UIInterfaceOrientationLandscapeRight:
            return CGAffineTransformMakeRotation(DegreesToRadians(90));

        case UIInterfaceOrientationPortraitUpsideDown:
            return CGAffineTransformMakeRotation(DegreesToRadians(180));

        case UIInterfaceOrientationPortrait:
        default:
            return CGAffineTransformMakeRotation(DegreesToRadians(0));
    }
}


-(void)didRotate:(UIInterfaceOrientation)orientation{

  if(!rotationEnabled){
    return;
  }
  if(!panel == nil){
  [self.panelWindow setTransform:[self transformForOrientation:orientation]];
  [self.panelSwiper setTransform:[self transformForOrientation:orientation]];
  //FIXME: REMOVE THIS WHEN THE ROTATION HAS BEEN FIXED. THIS JUST SETS IT TO BE LESS BUGGY WHEN ROTATED FOR NOW
  if(pController){
    [pController hidePanel];
  }
  [self relayout];

    if([panel respondsToSelector:@selector(didRotate:)]){
      [panel didRotate:orientation];
    }
  }
}


-(void)nowPlayingInfoChanged{
  NSLog(@"PANELDEBUG: nowPlayingInfoChanged");
  if(!panel == nil){
     if([panel respondsToSelector:@selector(nowPlayingInfoChanged)]){
      NSLog(@"PANELDEBUG: panel responds to nowPlayingInfoChanged");
      [panel nowPlayingInfoChanged];
    }
  }
}


@end

/*
May replace later on with a more elegant UISwipeGuestureRecognizer, if that allows for following the finger as well... 
Although hey, I may just make it use both so it doesn't break touches as much, if at all possible.  Maybe that can be clear, and still detect drags.
I'll check it out later. Would be easy to replace I hope though, especially if variables are used for all numbers and equation/logic code.
*/



%hook SBMediaController
-(void)_nowPlayingInfoChanged{
  %orig;
    if(pController) [pController nowPlayingInfoChanged];

}

-(void)_nowPlayingAppIsPlayingDidChange{
  %orig;
    if(pController) [pController performSelector:@selector(nowPlayingInfoChanged) withObject:nil afterDelay:0.5];
}

%end


%hook SBAwayView
-(id)initWithFrame:(CGRect)frame{

if(!pController){
  pController = [[PanelController alloc] init];
  pController.maxHeight = 380.0f;
  pController.sensitivity = 20.0f;
  [pController loadUp];
  [pController loadPanel];
  [pController relayout];
  [pController updateWindowLevels];

}
return %orig;
}



-(void)setDimmed:(BOOL)dimmed{
  %orig;
  if(pController){
    [pController hidePanel];
  }
}
%end

/*

%hook SBApplication
- (void)didActivate{
    
 
    %orig;
   // //NSLog(@"Launched %@ class: %@", [self displayIdentifier], [self class]);
   // if([disabledApps containsObject:[self displayIdentifier]]){
    //  [cardsScroll hideForApp];
   // }
 if(pController){
             if(!pController.panelOpen){
        [pController updateWindowLevels];

            }
            else{
              [pController hidePanel];
            }
        }
    
}

- (void)activate{
   
    %orig;
    //NSLog(@"Activate Launched %@ class: %@", [self displayIdentifier], [self class]);
    if(pController){
                if(!pController.panelOpen){
        [pController updateWindowLevels];
           
            }
            else{
              [pController hidePanel];
        
            }
        }
}



- (void)_setHasBeenLaunched{
    %orig;
    if(pController){
                if(!pController.panelOpen){
        [pController updateWindowLevels];

            }
            else{
              [pController hidePanel];
            }
        }
}

- (void)didAnimateActivation{
    %orig;
    if(pController){
                if(!pController.panelOpen){
        [pController updateWindowLevels];

            }
            else{
              [pController hidePanel];
            }
        }
}

- (void)didLaunch:(id)arg1{
    %orig;
    //NSLog(@"Launched %@ class: %@", arg1, [arg1 class]);
    if(pController){

             if(!pController.panelOpen){
     
        [pController updateWindowLevels];
            }
            else{
              [pController hidePanel];

            }
        }
}


%end
*/

%hook SBUIController
-(BOOL)clickedMenuButton{ 
  if(pController){
    if(pController.panelOpen){
    [pController hidePanel];
    return TRUE;
  }
  else{
    return %orig;
  }
 }
else{
 return %orig; 
}

}

-(BOOL)handleMenuDoubleTap{
  if(pController){
    if(pController.panelOpen){
    [pController hidePanel];
    return TRUE;
  }
  else{
    return %orig;
  }
 }
else{
 return %orig; 
}
}

-(void)finishLaunching{
  %orig;
    if(pController){

             if(!pController.panelOpen){
     
        [pController updateWindowLevels];
            }
            else{
              [pController hidePanel];

            }
        }
}

%end


%hook SpringBoard
-(void)frontDisplayDidChange {
    //iOS3.2-5
    %orig;
 // if(slideyController) [slideyController handleRotation:orientation];
   // CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), UPDATE_ORIENTATION_NOTI, NULL, NULL, true);
}

- (void)noteInterfaceOrientationChanged:(int)orientation {
    //iOS3.2-5
    %orig;
      if(pController) [pController didRotate:orientation];
    //CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), UPDATE_ORIENTATION_NOTI, NULL, NULL, true);
}

-(void)noteInterfaceOrientationChanged:(int)orientation duration:(double)duration {
    //iOS6
    %orig;
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 5);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if(pController) [pController didRotate:orientation];
       // CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), UPDATE_ORIENTATION_NOTI, NULL, NULL, true);
    });
}

%end
