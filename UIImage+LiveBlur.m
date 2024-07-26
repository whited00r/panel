#import "UIImage+LiveBlur.h"

/*
Copyright 2014 grayd00r
This is what I wrote to quickly blur things. It probably isn't the best way as I don't think it uses the GPU. 
I have some code that will work on iOS 4+ now though that does so I'll switch to that soon.
For now and for quick testing this will do. (I can just swap out the method internals when I want to upgrade the mode of blurring, quick and easy)

*/



UIKIT_EXTERN CGImageRef UIGetScreenImage();



@implementation UIImage (LiveBlur)

//Gets a live image of the screen. Maybe the IOSurface method would be better?  I also hope to have it be able to grab snapshots of existing views/surfaces.
+(UIImage*)liveBlurForScreenWithQuality:(float)quality interpolation:(int)iQuality blurRadius:(float)radius{

CGRect mainScreen = [[UIScreen mainScreen] bounds];
float screenHeight = mainScreen.size.height;
float screenWidth = mainScreen.size.width;
CGImageRef screen = UIGetScreenImage();

//This is the sneaky bit. We resize the image first, making it much much quicker to blur even at higher blur levels.
UIImage *smallImage = [[[UIImage imageWithCGImage:screen] resizedImage:CGSizeMake(screenWidth / quality, screenHeight / quality) interpolationQuality:iQuality] stackBlur:radius];
//Now we resize it back up to full size. Small loss of quality, but vastly quicker blur times.
UIImage *backgroundImage = [smallImage resizedImage:CGSizeMake(screenWidth,screenHeight) interpolationQuality:iQuality];// tintedImageUsingColor:[UIColor colorWithWhite:0.6 alpha:0.5]];
//backgroundImage = [UIImage imageWithCGImage:screen];


CGImageRelease(screen);
return backgroundImage;
}

+(UIImage*)liveSnapshotOfScreen{

CGRect mainScreen = [[UIScreen mainScreen] bounds];
float screenHeight = mainScreen.size.height;
float screenWidth = mainScreen.size.width;
CGImageRef screen = UIGetScreenImage();

UIImage *screenShot = [[UIImage imageWithCGImage:screen] resizedImage:CGSizeMake(screenWidth, screenHeight) interpolationQuality:4];

CGImageRelease(screen);
return screenShot;
}


+ (UIImage *) snapshotView:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, FALSE, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];

    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return img;
}

//Same method as above, except this applies the blur to any image rather than the screen. I use this in the album art mixed in with a few other things to get the perfect looking blur.
-(UIImage*)fastBlurWithQuality:(float)quality interpolation:(int)iQuality blurRadius:(float)radius{

CGRect mainScreen = [[UIScreen mainScreen] bounds];
float screenHeight = mainScreen.size.height;
float screenWidth = mainScreen.size.width;

UIImage *smallImage = [[self resizedImage:CGSizeMake(screenWidth / quality, screenHeight / quality) interpolationQuality:iQuality] stackBlur:radius];
UIImage *backgroundImage = [smallImage resizedImage:CGSizeMake(screenWidth,screenHeight) interpolationQuality:iQuality];// tintedImageUsingColor:[UIColor colorWithWhite:0.6 alpha:0.5]];
//backgroundImage = [UIImage imageWithCGImage:screen];


return backgroundImage;
}

@end