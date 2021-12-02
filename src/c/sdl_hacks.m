#import <Foundation/Foundation.h>

// https://stackoverflow.com/questions/43335291/smooth-inertial-scrolling-with-sdl2
void enableAppleMomentumScroll() {
    [[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"AppleMomentumScrollSupported"];
}