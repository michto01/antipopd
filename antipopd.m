// antipopd
//
// Copyright (c) Matthew Robinson 2010, 2018
// Email: matt@blendedcocoa.com
//
// See banner() below for a description of this program.
//
// This version of antipopd is released, like Robert Tomsick's version, under
// a Creative Commons Attribution Noncommercial Share Alike License 3.0,
// http://creativecommons.org/licenses/by-nc-sa/3.0/us

#import <unistd.h>

//#import <AppKit/AppKit.h>
#import <IOKit/ps/IOPowerSources.h>

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreFoundation/CoreFoundation.h>

#import <Availability.h>

#define NEW

#define ANTIPOPD_CONFIG "/usr/local/share/antipop/ac_only"
#define BATTERY_STATE   CFSTR("State:/IOKit/PowerSources/InternalBattery-0")
#define POWER_SOURCE    CFSTR("Power Source State")

#define OLD_MACOS    (TARGET_OS_OSX && __MAC_OS_X_VERSION_MIN_REQUIRED <= 101400)

static BOOL runOnACOnly = NO;
static size_t  interval = 10;

void banner() {
    printf(
           "USAGE:\n"
           "\t -aconly {true/false}  Run only on the AC power\n"
           "\t -interval {int}       Period to run the audio with\n"
           "\n"
    );

    printf("Copyright (c) Matthew Robinson 2010, 2018\n");
    printf("Email: matt@blendedcocoa.com\n\n");

    printf("antipopd is a drop in replacement for Robert Tomsick's antipopd 1.0.2 bash\n");
    printf("script which is available at http://www.tomsick.net/projects/antipop\n\n");

    printf("antipopd is a utility program which keeps the audio system active to stop\n");
    printf("the popping sound that can occur when OS X puts the audio system to sleep.\n");
    printf("This is achieved by using the Speech Synthesizer system to speak a space,\n");
    printf("which results in no audio output but keeps the audio system awake.\n\n");

    printf("The benefit of this compiled version over the bash script is a reduction\n");
    printf("in resource overheads.  The bash script executes two expensive processes \n");
    printf("(pmset and say) every ten seconds (one process if ac_only is set to 0).\n\n");

    printf("This version of antipopd is released, like Robert Tomsick's version, under\n");
    printf("a Creative Commons Attribution Noncommercial Share Alike License 3.0,\n");
    printf("http://creativecommons.org/licenses/by-nc-sa/3.0/us\n\n");
}

#if OLD_MACOS
    NSSpeechSynthesizer* speech;
#else
    AVSpeechSynthesizer* speech;
#endif

// Timer callback that actually speaks the space
void speak(CFRunLoopTimerRef timer, void *info) {
    // If we are only supposed to run on AC power
    if (runOnACOnly) {
        // and we don't have unlimited power remaining
        if (IOPSGetTimeRemainingEstimate() != kIOPSTimeRemainingUnlimited) {
            // then return without speaking
            //return;
            fprintf(stderr, "No AC power, exiting ...\n");
            exit(EXIT_FAILURE);
        }
    }

#if OLD_MACOS
    if (!speech) {
        speech = [[NSSpeechSynthesizer alloc] initWithVoice:nil];
    }

    [speech startSpeakingString:@" "];
#else
    if (!speech) {
        speech = [AVSpeechSynthesizer new];
    }

    AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:@" "];
    utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-GB"];
    [speech speakUtterance:utterance];
#endif
}

// Check for the existance of the ac_only file, check the contents
// and set runOnACOnly as appropriate
void loadACOnlyConfig() {
    // Try to open the ac_only config file
    int fd = open(ANTIPOPD_CONFIG, O_RDONLY);

    // If succesful look inside, otherwise proceed with runOnACOnly default
    if (fd != -1) {
        char    buffer;

        ssize_t result = read(fd, &buffer, 1);

        // ...the first byte of the file is 1
        if (result == 1 && buffer == '1') {
            runOnACOnly = YES;
        }

        close(fd);
    }
}

int main(int argc, char *argv[]) {
    NSUserDefaults* arguments = [NSUserDefaults standardUserDefaults];
    bool argumentLoaded = false;

    if ([arguments objectForKey:@"aconly"]) {
        argumentLoaded = true;
        runOnACOnly = [arguments boolForKey:@"aconly"];
    } else {
        loadACOnlyConfig();
    }

    if ([arguments objectForKey:@"interval"]) {
        argumentLoaded = true;
        interval = [arguments integerForKey:@"interval"];
    }

    if (argc >= 2 && !argumentLoaded) { // if we have any other parameter show the banner
        printf("%s\n\n", argv[0]);
        banner();
        exit(EXIT_SUCCESS);
    }

    fprintf(stderr, "Settings:\n");
    fprintf(stderr, "\tAC Only:  %s\n", runOnACOnly ? "YES": "NO");
    fprintf(stderr, "\tINTERVAL: %zd (seconds)\n", interval);
    fprintf(stdout, "Running %s ...\n", argv[0]);

    // Put an AutoreleasePool in place in case NSSpeechSynthesizer expects it
    @autoreleasepool {
        CFRunLoopTimerContext context = {
            0, NULL, NULL, NULL, NULL,
        };

        CFRunLoopTimerRef timer = 
            CFRunLoopTimerCreate(NULL, 0, interval, 0, 0, speak, &context);

        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
        CFRunLoopRun();
    }

    return EXIT_SUCCESS;
}
