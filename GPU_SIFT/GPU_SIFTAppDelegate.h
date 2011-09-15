#import <UIKit/UIKit.h>

@class SIFT;

@interface GPU_SIFTAppDelegate : NSObject <UIApplicationDelegate> {
	IBOutlet UIWindow *window;
	IBOutlet SIFT *glView;
}

@property (nonatomic, retain) UIWindow *window;

@end
