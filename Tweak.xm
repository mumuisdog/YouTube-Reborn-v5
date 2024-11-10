#import "Tweak.h"

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)
#define YT_BUNDLE_ID @"com.google.ios.youtube"
#define YT_NAME @"YouTube"

static BOOL hasDeviceNotch() {
	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
		return NO;
	} else {
		LAContext *context = [[LAContext alloc] init];
		[context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil];
		return [context biometryType] == LABiometryTypeFaceID;
	}
}

UIColor *rebornHexColour;
UIColor *lcmHexColor;

YTLocalPlaybackController *playingVideoID;

%hook YTLocalPlaybackController
- (NSString *)currentVideoID {
    playingVideoID = self;
    return %orig;
}
%end

YTSingleVideo *shortsPlayingVideoID;

%hook YTSingleVideo
- (NSString *)videoId {
    shortsPlayingVideoID = self;
    return %orig;
}
%end

YTUserDefaults *ytThemeSettings;

%hook YTUserDefaults
- (long long)appThemeSetting {
    ytThemeSettings = self;
    return %orig;
}
%end

YTMainAppVideoPlayerOverlayViewController *resultOut;
YTMainAppVideoPlayerOverlayViewController *layoutOut;
YTMainAppVideoPlayerOverlayViewController *stateOut;

%hook YTMainAppVideoPlayerOverlayViewController
- (CGFloat)mediaTime {
    resultOut = self;
    return %orig;
}
- (int)playerViewLayout {
    layoutOut = self;
    return %orig;
}
- (NSInteger)playerState {
    stateOut = self;
    return %orig;
}
%end

// Keychain patching
static NSString *accessGroupID() {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
                           @"bundleSeedID", kSecAttrAccount,
                           @"", kSecAttrService,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound)
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status != errSecSuccess)
            return nil;
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];

    return accessGroup;
}

// IAmYouTube - https://github.com/PoomSmart/IAmYouTube
%hook YTVersionUtils
+ (NSString *)appName { return YT_NAME; }
+ (NSString *)appID { return YT_BUNDLE_ID; }
%end

%hook GCKBUtils
+ (NSString *)appIdentifier { return YT_BUNDLE_ID; }
%end

%hook GPCDeviceInfo
+ (NSString *)bundleId { return YT_BUNDLE_ID; }
%end

%hook OGLBundle
+ (NSString *)shortAppName { return YT_NAME; }
%end

%hook GVROverlayView
+ (NSString *)appName { return YT_NAME; }
%end

%hook OGLPhenotypeFlagServiceImpl
- (NSString *)bundleId { return YT_BUNDLE_ID; }
%end

%hook APMAEU
+ (BOOL)isFAS { return YES; }
%end

%hook GULAppEnvironmentUtil
+ (BOOL)isFromAppStore { return YES; }
%end

%hook SSOConfiguration
- (id)initWithClientID:(id)clientID supportedAccountServices:(id)supportedAccountServices {
    self = %orig;
    [self setValue:YT_NAME forKey:@"_shortAppName"];
    [self setValue:YT_BUNDLE_ID forKey:@"_applicationIdentifier"];
    return self;
}
%end

%hook NSBundle
- (NSString *)bundleIdentifier {
    NSArray *address = [NSThread callStackReturnAddresses];
    Dl_info info = {0};
    if (dladdr((void *)[address[2] longLongValue], &info) == 0)
        return %orig;
    NSString *path = [NSString stringWithUTF8String:info.dli_fname];
    if ([path hasPrefix:NSBundle.mainBundle.bundlePath])
        return YT_BUNDLE_ID;
    return %orig;
}
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if ([key isEqualToString:@"CFBundleIdentifier"])
        return YT_BUNDLE_ID;
    if ([key isEqualToString:@"CFBundleDisplayName"] || [key isEqualToString:@"CFBundleName"])
        return YT_NAME;
    return %orig;
}
// Fix Google Sign in by @PoomSmart and @level3tjg (qnblackcat/uYouPlus#684)
- (NSDictionary *)infoDictionary {
    NSMutableDictionary *info = %orig.mutableCopy;
    NSString *altBundleIdentifier = info[@"ALTBundleIdentifier"];
    if (altBundleIdentifier) info[@"CFBundleIdentifier"] = altBundleIdentifier;
    return info;
}
%end

// Fix login for YouTube 18.13.2 and higher
%hook SSOKeychainHelper
+ (NSString *)accessGroup {
    return accessGroupID();
}
+ (NSString *)sharedAccessGroup {
    return accessGroupID();
}
%end

// Fix login for YouTube 17.33.2 and higher
%hook SSOKeychainCore
+ (NSString *)accessGroup {
    return accessGroupID();
}

+ (NSString *)sharedAccessGroup {
    return accessGroupID();
}
%end

// Fix App Group Directory by moving it to documents directory
%hook NSFileManager
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    if (groupIdentifier != nil) {
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documentsURL = [paths lastObject];
        return [documentsURL URLByAppendingPathComponent:@"AppGroup"];
    }
    return %orig(groupIdentifier);
}
%end

%group gPictureInPicture
%hook YTPlayerPIPController
- (BOOL)isPictureInPicturePossible {
    return YES;
}
- (BOOL)canEnablePictureInPicture {
    return YES;
}
- (BOOL)isPipSettingEnabled {
    return YES;
}
- (BOOL)isPictureInPictureForceDisabled {
    return NO;
}
- (void)setPictureInPictureForceDisabled:(BOOL)arg1 {
    %orig(NO);
}
%end
%hook YTLocalPlaybackController
- (BOOL)isPictureInPicturePossible {
    return YES;
}
%end
%hook YTBackgroundabilityPolicy
- (BOOL)isPlayableInPictureInPictureByUserSettings {
    return YES;
}
%end
%hook YTLightweightPlayerViewController
- (BOOL)isPictureInPicturePossible {
    return YES;
}
%end
%hook YTPlayerViewController
- (BOOL)isPictureInPicturePossible {
    return YES;
}
%end
%hook YTPlayerResponse
- (BOOL)isPlayableInPictureInPicture {
    return YES;
}
- (BOOL)isPipOffByDefault {
    return NO;
}
%end
%hook MLPIPController
- (BOOL)pictureInPictureSupported {
    return YES;
}
%end
%end

%hook YTRightNavigationButtons
%property (retain, nonatomic) YTQTMButton *youtubeRebornButton;
- (NSMutableArray *)buttons {
	NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YouTubeReborn" ofType:@"bundle"];
    NSString *youtubeRebornLightSettingsPath;
    NSString *youtubeRebornDarkSettingsPath;
    if (tweakBundlePath) {
        NSBundle *tweakBundle = [NSBundle bundleWithPath:tweakBundlePath];
        youtubeRebornLightSettingsPath = [tweakBundle pathForResource:@"ytrebornbuttonwhite" ofType:@"png"];
		youtubeRebornDarkSettingsPath = [tweakBundle pathForResource:@"ytrebornbuttonblack" ofType:@"png"];
    } else {
// RootHide
                youtubeRebornLightSettingsPath = jbroot(@"/Library/Application Support/YouTubeReborn.bundle/ytrebornbuttonwhite.png");
        youtubeRebornDarkSettingsPath = jbroot(@"/Library/Application Support/YouTubeReborn.bundle/ytrebornbuttonblack.png");
// Rootless 
//		youtubeRebornLightSettingsPath = ROOT_PATH_NS(@"/Library/Application Support/YouTubeReborn.bundle/ytrebornbuttonwhite.png");
//      youtubeRebornDarkSettingsPath = ROOT_PATH_NS(@"/Library/Application Support/YouTubeReborn.bundle/ytrebornbuttonblack.png");
    }
    NSMutableArray *retVal = %orig.mutableCopy;
    [self.youtubeRebornButton removeFromSuperview];
    [self addSubview:self.youtubeRebornButton];
    if (!self.youtubeRebornButton) {
        self.youtubeRebornButton = [%c(YTQTMButton) iconButton];
        self.youtubeRebornButton.frame = CGRectMake(0, 0, 24, 24);
        
        if ([%c(YTPageStyleController) pageStyle] == 0) {
            [self.youtubeRebornButton setImage:[UIImage imageWithContentsOfFile:youtubeRebornDarkSettingsPath] forState:UIControlStateNormal];
        }
        else if ([%c(YTPageStyleController) pageStyle] == 1) {
            [self.youtubeRebornButton setImage:[UIImage imageWithContentsOfFile:youtubeRebornLightSettingsPath] forState:UIControlStateNormal];
        }
        
        [self.youtubeRebornButton addTarget:self action:@selector(rebornRootOptionsAction) forControlEvents:UIControlEventTouchUpInside];
        [retVal insertObject:self.youtubeRebornButton atIndex:0];
    }
    return retVal;
}
- (NSMutableArray *)visibleButtons {
    NSMutableArray *retVal = %orig.mutableCopy;
    [self setLeadingPadding:+10];
    if (self.youtubeRebornButton) {
        [self.youtubeRebornButton removeFromSuperview];
        [self addSubview:self.youtubeRebornButton];
        [retVal insertObject:self.youtubeRebornButton atIndex:0];
    }
    return retVal;
}
%new;
- (void)rebornRootOptionsAction {
    RootOptionsController *rootOptionsController = [[RootOptionsController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *rootOptionsControllerView = [[UINavigationController alloc] initWithRootViewController:rootOptionsController];
    rootOptionsControllerView.modalPresentationStyle = UIModalPresentationFullScreen;

    UIViewController *rootPrefsViewController = [self _viewControllerForAncestor];
    [rootPrefsViewController presentViewController:rootOptionsControllerView animated:YES completion:nil];
}
%end

%hook YTMainAppControlsOverlayView

%property(retain, nonatomic) UIButton *rebornOverlayButton;

- (id)initWithDelegate:(id)delegate {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"15.0") && [[NSUserDefaults standardUserDefaults] boolForKey:@"kRebornIHaveYouTubePremium"] == NO && [[NSUserDefaults standardUserDefaults] boolForKey:@"kEnablePictureInPictureVTwo"] == YES) {
        %init(gPictureInPicture);
    }
    self = %orig;
    if (self) {
        self.rebornOverlayButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        [self.rebornOverlayButton addTarget:self action:@selector(rebornOptionsAction) forControlEvents:UIControlEventTouchUpInside];
        [self.rebornOverlayButton setTitle:@"OP" forState:UIControlStateNormal];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kShowStatusBarInOverlay"] == YES) {
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kEnableiPadStyleOniPhone"] == YES) {
                self.rebornOverlayButton.frame = CGRectMake(40, 9, 40.0, 30.0);
            } else {
                self.rebornOverlayButton.frame = CGRectMake(40, 24, 40.0, 30.0);
            }
        } else {
            self.rebornOverlayButton.frame = CGRectMake(40, 9, 40.0, 30.0);
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideRebornOPButtonVTwo"] == YES) {
            self.rebornOverlayButton.hidden = YES;
        }
        [self addSubview:self.rebornOverlayButton];
    }
    return self;
}

- (void)setTopOverlayVisible:(BOOL)visible isAutonavCanceledState:(BOOL)canceledState {
    if (canceledState) {
        if (!self.rebornOverlayButton.hidden) {
            self.rebornOverlayButton.alpha = 0.0;
        }
    } else {
        if (!self.rebornOverlayButton.hidden) {
            int rotation = [layoutOut playerViewLayout];
            if (rotation == 2) {
                self.rebornOverlayButton.alpha = visible ? 1.0 : 0.0;
            } else {
                self.rebornOverlayButton.alpha = 0.0;
            }
        }
    }
    %orig;
}

%new;
- (void)rebornOptionsAction {
    NSInteger videoStatus = [stateOut playerState];
    if (videoStatus == 3) {
        [self didPressPause:[self playPauseButton]];
    }

    NSString *videoIdentifier = [playingVideoID currentVideoID];

    UIAlertController *alertMenu = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kRebornIHaveYouTubePremium"] == NO) {
        [alertMenu addAction:[UIAlertAction actionWithTitle:@"Download Audio" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self rebornAudioDownloader:videoIdentifier];
        }]];

        [alertMenu addAction:[UIAlertAction actionWithTitle:@"Download Video" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self rebornVideoDownloader:videoIdentifier];
        }]];
    }

    [alertMenu addAction:[UIAlertAction actionWithTitle:@"Play In External App" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self rebornPlayInExternalApp:videoIdentifier];
    }]];

    [alertMenu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];

    [alertMenu setModalPresentationStyle:UIModalPresentationPopover];
    UIPopoverPresentationController *popPresenter = [alertMenu popoverPresentationController];
    popPresenter.sourceView = self;
    popPresenter.sourceRect = self.bounds;

    UIViewController *menuViewController = [self _viewControllerForAncestor];
    [menuViewController presentViewController:alertMenu animated:YES completion:nil];
}

%new;
- (void)rebornVideoDownloader :(NSString *)videoID {
    NSDictionary *youtubePlayerRequest = [YouTubeExtractor youtubePlayerRequest:@"mediaconnect":videoID];
    NSString *videoTitle = [NSString stringWithFormat:@"%@", youtubePlayerRequest[@"videoDetails"][@"title"]];
    NSArray *videoArtworkArray = youtubePlayerRequest[@"videoDetails"][@"thumbnail"][@"thumbnails"];
    NSURL *videoArtwork = [NSURL URLWithString:[NSString stringWithFormat:@"%@", videoArtworkArray[([videoArtworkArray count] - 1)][@"url"]]];
    NSDictionary *innertubeAdaptiveFormats = youtubePlayerRequest[@"streamingData"][@"adaptiveFormats"];
    NSURL *video2160p;
    NSURL *video1440p;
    NSURL *video1080p;
    NSURL *video720p;
    NSURL *video480p;
    NSURL *video360p;
    NSURL *video240p;
    NSURL *audioHigh;
    NSURL *audioMedium;
    NSURL *audioLow;
    for (NSDictionary *format in innertubeAdaptiveFormats) {
        if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"2160"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"quality"]] isEqual:@"hd2160"]) {
            if (video2160p == nil) {
                video2160p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"1440"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"quality"]] isEqual:@"hd1440"]) {
            if (video1440p == nil) {
                video1440p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"1080"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"quality"]] isEqual:@"hd1080"]) {
            if (video1080p == nil) {
                video1080p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"720"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"quality"]] isEqual:@"hd720"]) {
            if (video720p == nil) {
                video720p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"480"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"qualityLabel"]] isEqual:@"480p"]) {
            if (video480p == nil) {
                video480p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"360"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"qualityLabel"]] isEqual:@"360p"]) {
            if (video360p == nil) {
                video360p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"240"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"qualityLabel"]] isEqual:@"240p"]) {
            if (video240p == nil) {
                video240p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"audio/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"audioQuality"]] isEqual:@"AUDIO_QUALITY_HIGH"]) {
            if (audioHigh == nil) {
                audioHigh = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"audio/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"audioQuality"]] isEqual:@"AUDIO_QUALITY_MEDIUM"]) {
            if (audioMedium == nil) {
                audioMedium = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"audio/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"audioQuality"]] isEqual:@"AUDIO_QUALITY_LOW"]) {
            if (audioLow == nil) {
                audioLow = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        }
    }

    NSURL *audioURL;
    if (audioHigh != nil) {
        audioURL = audioHigh;
    } else if (audioMedium != nil) {
        audioURL = audioMedium;
    } else if (audioLow != nil) {
        audioURL = audioLow;
    }

    UIAlertController *alertQualitySelector = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    if (video240p != nil) {
        [alertQualitySelector addAction:[UIAlertAction actionWithTitle:@"240p" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            YouTubeDownloadController *rebornYouTubeDownloadController = [[YouTubeDownloadController alloc] init];
            rebornYouTubeDownloadController.downloadTitle = videoTitle;
            rebornYouTubeDownloadController.videoURL = video240p;
            rebornYouTubeDownloadController.audioURL = audioURL;
            rebornYouTubeDownloadController.dualURL = nil;
            rebornYouTubeDownloadController.artworkURL = videoArtwork;
            rebornYouTubeDownloadController.downloadOption = 0;

            UIViewController *rebornYouTubeDownloadViewController = self._viewControllerForAncestor;
            [rebornYouTubeDownloadViewController presentViewController:rebornYouTubeDownloadController animated:YES completion:nil];
        }]];
    }
    if (video360p != nil) {
        [alertQualitySelector addAction:[UIAlertAction actionWithTitle:@"360p" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            YouTubeDownloadController *rebornYouTubeDownloadController = [[YouTubeDownloadController alloc] init];
            rebornYouTubeDownloadController.downloadTitle = videoTitle;
            rebornYouTubeDownloadController.videoURL = video360p;
            rebornYouTubeDownloadController.audioURL = audioURL;
            rebornYouTubeDownloadController.dualURL = nil;
            rebornYouTubeDownloadController.artworkURL = videoArtwork;
            rebornYouTubeDownloadController.downloadOption = 0;

            UIViewController *rebornYouTubeDownloadViewController = self._viewControllerForAncestor;
            [rebornYouTubeDownloadViewController presentViewController:rebornYouTubeDownloadController animated:YES completion:nil];
        }]];
    }
    if (video480p != nil) {
        [alertQualitySelector addAction:[UIAlertAction actionWithTitle:@"480p" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            YouTubeDownloadController *rebornYouTubeDownloadController = [[YouTubeDownloadController alloc] init];
            rebornYouTubeDownloadController.downloadTitle = videoTitle;
            rebornYouTubeDownloadController.videoURL = video480p;
            rebornYouTubeDownloadController.audioURL = audioURL;
            rebornYouTubeDownloadController.dualURL = nil;
            rebornYouTubeDownloadController.artworkURL = videoArtwork;
            rebornYouTubeDownloadController.downloadOption = 0;

            UIViewController *rebornYouTubeDownloadViewController = self._viewControllerForAncestor;
            [rebornYouTubeDownloadViewController presentViewController:rebornYouTubeDownloadController animated:YES completion:nil];
        }]];
    }
    if (video720p != nil) {
        [alertQualitySelector addAction:[UIAlertAction actionWithTitle:@"720p" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            YouTubeDownloadController *rebornYouTubeDownloadController = [[YouTubeDownloadController alloc] init];
            rebornYouTubeDownloadController.downloadTitle = videoTitle;
            rebornYouTubeDownloadController.videoURL = video720p;
            rebornYouTubeDownloadController.audioURL = audioURL;
            rebornYouTubeDownloadController.dualURL = nil;
            rebornYouTubeDownloadController.artworkURL = videoArtwork;
            rebornYouTubeDownloadController.downloadOption = 0;

            UIViewController *rebornYouTubeDownloadViewController = self._viewControllerForAncestor;
            [rebornYouTubeDownloadViewController presentViewController:rebornYouTubeDownloadController animated:YES completion:nil];
        }]];
    }
    if (video1080p != nil) {
        [alertQualitySelector addAction:[UIAlertAction actionWithTitle:@"1080p" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            YouTubeDownloadController *rebornYouTubeDownloadController = [[YouTubeDownloadController alloc] init];
            rebornYouTubeDownloadController.downloadTitle = videoTitle;
            rebornYouTubeDownloadController.videoURL = video1080p;
            rebornYouTubeDownloadController.audioURL = audioURL;
            rebornYouTubeDownloadController.dualURL = nil;
            rebornYouTubeDownloadController.artworkURL = videoArtwork;
            rebornYouTubeDownloadController.downloadOption = 0;

            UIViewController *rebornYouTubeDownloadViewController = self._viewControllerForAncestor;
            [rebornYouTubeDownloadViewController presentViewController:rebornYouTubeDownloadController animated:YES completion:nil];
        }]];
    }
    if (video1440p != nil) {
        [alertQualitySelector addAction:[UIAlertAction actionWithTitle:@"1440p" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            YouTubeDownloadController *rebornYouTubeDownloadController = [[YouTubeDownloadController alloc] init];
            rebornYouTubeDownloadController.downloadTitle = videoTitle;
            rebornYouTubeDownloadController.videoURL = video1440p;
            rebornYouTubeDownloadController.audioURL = audioURL;
            rebornYouTubeDownloadController.dualURL = nil;
            rebornYouTubeDownloadController.artworkURL = videoArtwork;
            rebornYouTubeDownloadController.downloadOption = 0;

            UIViewController *rebornYouTubeDownloadViewController = self._viewControllerForAncestor;
            [rebornYouTubeDownloadViewController presentViewController:rebornYouTubeDownloadController animated:YES completion:nil];
        }]];
    }
    if (video2160p != nil) {
        [alertQualitySelector addAction:[UIAlertAction actionWithTitle:@"2160p" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            YouTubeDownloadController *rebornYouTubeDownloadController = [[YouTubeDownloadController alloc] init];
            rebornYouTubeDownloadController.downloadTitle = videoTitle;
            rebornYouTubeDownloadController.videoURL = video2160p;
            rebornYouTubeDownloadController.audioURL = audioURL;
            rebornYouTubeDownloadController.dualURL = nil;
            rebornYouTubeDownloadController.artworkURL = videoArtwork;
            rebornYouTubeDownloadController.downloadOption = 0;

            UIViewController *rebornYouTubeDownloadViewController = self._viewControllerForAncestor;
            [rebornYouTubeDownloadViewController presentViewController:rebornYouTubeDownloadController animated:YES completion:nil];
        }]];
    }

    [alertQualitySelector addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];

    [alertQualitySelector setModalPresentationStyle:UIModalPresentationPopover];
    UIPopoverPresentationController *popPresenter = [alertQualitySelector popoverPresentationController];
    popPresenter.sourceView = self;
    popPresenter.sourceRect = self.bounds;

    UIViewController *qualitySelectorViewController = [self _viewControllerForAncestor];
    [qualitySelectorViewController presentViewController:alertQualitySelector animated:YES completion:nil];
}

%new;
- (void)rebornAudioDownloader :(NSString *)videoID {
    NSDictionary *youtubePlayerRequest = [YouTubeExtractor youtubePlayerRequest:@"mediaconnect":videoID];
    NSArray *videoArtworkArray = youtubePlayerRequest[@"videoDetails"][@"thumbnail"][@"thumbnails"];
    NSArray *innertubeAdaptiveFormats = youtubePlayerRequest[@"streamingData"][@"adaptiveFormats"];

    NSMutableDictionary *qualityInfo = [[NSMutableDictionary alloc] init];
    for (NSDictionary *format in innertubeAdaptiveFormats) {
        if ([format[@"mimeType"] containsString:@"audio/mp4"] && [format[@"audioQuality"] isEqual:@"AUDIO_QUALITY_HIGH"] && (qualityInfo[@"audioQuality"] == nil || [qualityInfo[@"audioQuality"] isEqual:@""] || [qualityInfo[@"audioQuality"] isEqual:@"medium"] || [qualityInfo[@"audioQuality"] isEqual:@"low"])) {
            qualityInfo[@"audioQuality"] = @"high";
            qualityInfo[@"audioUrl"] = [NSURL URLWithString:format[@"url"]];
        } else if ([format[@"mimeType"] containsString:@"audio/mp4"] && [format[@"audioQuality"] isEqual:@"AUDIO_QUALITY_MEDIUM"] && (qualityInfo[@"audioQuality"] == nil || [qualityInfo[@"audioQuality"] isEqual:@""] || [qualityInfo[@"audioQuality"] isEqual:@"low"])) {
            qualityInfo[@"audioQuality"] = @"medium";
            qualityInfo[@"audioUrl"] = [NSURL URLWithString:format[@"url"]];
        } else if ([format[@"mimeType"] containsString:@"audio/mp4"] && [format[@"audioQuality"] isEqual:@"AUDIO_QUALITY_LOW"] && (qualityInfo[@"audioQuality"] == nil || [qualityInfo[@"audioQuality"] isEqual:@""])) {
            qualityInfo[@"audioQuality"] = @"low";
            qualityInfo[@"audioUrl"] = [NSURL URLWithString:format[@"url"]];
        }
    }

    YouTubeDownloadController *rebornYouTubeDownloadController = [[YouTubeDownloadController alloc] init];
    rebornYouTubeDownloadController.downloadTitle = youtubePlayerRequest[@"videoDetails"][@"title"];
    rebornYouTubeDownloadController.videoURL = nil;
    rebornYouTubeDownloadController.audioURL = qualityInfo[@"audioUrl"];
    rebornYouTubeDownloadController.dualURL = nil;
    rebornYouTubeDownloadController.artworkURL = [NSURL URLWithString:videoArtworkArray[([videoArtworkArray count] - 1)][@"url"]];
    rebornYouTubeDownloadController.downloadOption = 1;

    UIViewController *rebornYouTubeDownloadViewController = self._viewControllerForAncestor;
    [rebornYouTubeDownloadViewController presentViewController:rebornYouTubeDownloadController animated:YES completion:nil];
}

%new;
- (void)rebornPlayInExternalApp :(NSString *)videoID {
    NSDictionary *youtubePlayerRequest = [YouTubeExtractor youtubePlayerRequest:@"ios":videoID];
    NSURL *videoPath = [NSURL URLWithString:[NSString stringWithFormat:@"%@", youtubePlayerRequest[@"streamingData"][@"hlsManifestUrl"]]];

    UIAlertController *alertApp = [UIAlertController alertControllerWithTitle:@"Choose App" message:nil preferredStyle:UIAlertControllerStyleAlert];

    [alertApp addAction:[UIAlertAction actionWithTitle:@"Play In Infuse" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"infuse://x-callback-url/play?url=%@", videoPath]] options:@{} completionHandler:nil];
    }]];

    [alertApp addAction:[UIAlertAction actionWithTitle:@"Play In VLC" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"vlc-x-callback://x-callback-url/stream?url=%@", videoPath]] options:@{} completionHandler:nil];
    }]];

    [alertApp addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];

    UIViewController *alertAppViewController = [self _viewControllerForAncestor];
    [alertAppViewController presentViewController:alertApp animated:YES completion:nil];
}
%end

%hook YTReelHeaderView
- (void)layoutSubviews {
	%orig();
    UIButton *rebornOverlayButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [rebornOverlayButton addTarget:self action:@selector(rebornOptionsAction) forControlEvents:UIControlEventTouchUpInside];
    [rebornOverlayButton setTitle:@"OP" forState:UIControlStateNormal];
    rebornOverlayButton.frame = CGRectMake(40, 5, 40.0, 30.0);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideRebornShortsOPButton"] == YES) {
        rebornOverlayButton.hidden = YES;
    }
    [self addSubview:rebornOverlayButton];
}

%new;
- (void)rebornOptionsAction {
    NSString *videoIdentifier = [shortsPlayingVideoID videoId];

    UIAlertController *alertMenu = [UIAlertController alertControllerWithTitle:nil message:@"Please Pause The Video Before Continuing" preferredStyle:UIAlertControllerStyleActionSheet];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kRebornIHaveYouTubePremium"] == NO) {
        [alertMenu addAction:[UIAlertAction actionWithTitle:@"Download Audio" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self rebornAudioDownloader:videoIdentifier];
        }]];

        [alertMenu addAction:[UIAlertAction actionWithTitle:@"Download Video" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self rebornVideoDownloader:videoIdentifier];
        }]];
    }

    [alertMenu addAction:[UIAlertAction actionWithTitle:@"Play In External App" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self rebornPlayInExternalApp:videoIdentifier];
    }]];

    [alertMenu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];

    [alertMenu setModalPresentationStyle:UIModalPresentationPopover];
    UIPopoverPresentationController *popPresenter = [alertMenu popoverPresentationController];
    popPresenter.sourceView = self;
    popPresenter.sourceRect = self.bounds;

    UIViewController *menuViewController = [self _viewControllerForAncestor];
    [menuViewController presentViewController:alertMenu animated:YES completion:nil];
}

%new;
- (void)rebornVideoDownloader :(NSString *)videoID {
    NSDictionary *youtubePlayerRequest = [YouTubeExtractor youtubePlayerRequest:@"mediaconnect":videoID];
    NSString *videoTitle = [NSString stringWithFormat:@"%@", youtubePlayerRequest[@"videoDetails"][@"title"]];
    NSArray *videoArtworkArray = youtubePlayerRequest[@"videoDetails"][@"thumbnail"][@"thumbnails"];
    NSURL *videoArtwork = [NSURL URLWithString:[NSString stringWithFormat:@"%@", videoArtworkArray[([videoArtworkArray count] - 1)][@"url"]]];
    NSDictionary *innertubeFormats = youtubePlayerRequest[@"streamingData"][@"formats"];
    NSURL *video2160p;
    NSURL *video1440p;
    NSURL *video1080p;
    NSURL *video720p;
    NSURL *video480p;
    NSURL *video360p;
    NSURL *video240p;
    for (NSDictionary *format in innertubeFormats) {
        if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"2160"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"quality"]] isEqual:@"hd2160"]) {
            if (video2160p == nil) {
                video2160p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"1440"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"quality"]] isEqual:@"hd1440"]) {
            if (video1440p == nil) {
                video1440p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"1080"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"quality"]] isEqual:@"hd1080"]) {
            if (video1080p == nil) {
                video1080p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"720"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"quality"]] isEqual:@"hd720"]) {
            if (video720p == nil) {
                video720p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"480"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"qualityLabel"]] isEqual:@"480p"]) {
            if (video480p == nil) {
                video480p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"360"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"qualityLabel"]] isEqual:@"360p"]) {
            if (video360p == nil) {
                video360p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        } else if ([[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"height"]] isEqual:@"240"] || [[format objectForKey:@"mimeType"] containsString:@"video/mp4"] & [[NSString stringWithFormat:@"%@", [format objectForKey:@"qualityLabel"]] isEqual:@"240p"]) {
            if (video240p == nil) {
                video240p = [NSURL URLWithString:[NSString stringWithFormat:@"%@", [format objectForKey:@"url"]]];
            }
        }
    }

    NSURL *videoURL;
    if (video2160p != nil) {
        videoURL = video2160p;
    } else if (video1440p != nil) {
        videoURL = video1440p;
    } else if (video1080p != nil) {
        videoURL = video1080p;
    } else if (video720p != nil) {
        videoURL = video720p;
    } else if (video480p != nil) {
        videoURL = video480p;
    } else if (video360p != nil) {
        videoURL = video360p;
    } else if (video240p != nil) {
        videoURL = video240p;
    }

    YouTubeDownloadController *rebornYouTubeDownloadController = [[YouTubeDownloadController alloc] init];
    rebornYouTubeDownloadController.downloadTitle = videoTitle;
    rebornYouTubeDownloadController.videoURL = nil;
    rebornYouTubeDownloadController.audioURL = nil;
    rebornYouTubeDownloadController.dualURL = videoURL;
    rebornYouTubeDownloadController.artworkURL = videoArtwork;
    rebornYouTubeDownloadController.downloadOption = 2;

    UIViewController *rebornYouTubeDownloadViewController = self._viewControllerForAncestor;
    [rebornYouTubeDownloadViewController presentViewController:rebornYouTubeDownloadController animated:YES completion:nil];
}

%new;
- (void)rebornAudioDownloader :(NSString *)videoID {
    NSDictionary *youtubePlayerRequest = [YouTubeExtractor youtubePlayerRequest:@"mediaconnect":videoID];
    NSArray *videoArtworkArray = youtubePlayerRequest[@"videoDetails"][@"thumbnail"][@"thumbnails"];
    NSArray *innertubeAdaptiveFormats = youtubePlayerRequest[@"streamingData"][@"adaptiveFormats"];

    NSMutableDictionary *qualityInfo = [[NSMutableDictionary alloc] init];
    for (NSDictionary *format in innertubeAdaptiveFormats) {
        if ([format[@"mimeType"] containsString:@"audio/mp4"] && [format[@"audioQuality"] isEqual:@"AUDIO_QUALITY_HIGH"] && (qualityInfo[@"audioQuality"] == nil || [qualityInfo[@"audioQuality"] isEqual:@""] || [qualityInfo[@"audioQuality"] isEqual:@"medium"] || [qualityInfo[@"audioQuality"] isEqual:@"low"])) {
            qualityInfo[@"audioQuality"] = @"high";
            qualityInfo[@"audioUrl"] = [NSURL URLWithString:format[@"url"]];
        } else if ([format[@"mimeType"] containsString:@"audio/mp4"] && [format[@"audioQuality"] isEqual:@"AUDIO_QUALITY_MEDIUM"] && (qualityInfo[@"audioQuality"] == nil || [qualityInfo[@"audioQuality"] isEqual:@""] || [qualityInfo[@"audioQuality"] isEqual:@"low"])) {
            qualityInfo[@"audioQuality"] = @"medium";
            qualityInfo[@"audioUrl"] = [NSURL URLWithString:format[@"url"]];
        } else if ([format[@"mimeType"] containsString:@"audio/mp4"] && [format[@"audioQuality"] isEqual:@"AUDIO_QUALITY_LOW"] && (qualityInfo[@"audioQuality"] == nil || [qualityInfo[@"audioQuality"] isEqual:@""])) {
            qualityInfo[@"audioQuality"] = @"low";
            qualityInfo[@"audioUrl"] = [NSURL URLWithString:format[@"url"]];
        }
    }

    YouTubeDownloadController *rebornYouTubeDownloadController = [[YouTubeDownloadController alloc] init];
    rebornYouTubeDownloadController.downloadTitle = youtubePlayerRequest[@"videoDetails"][@"title"];
    rebornYouTubeDownloadController.videoURL = nil;
    rebornYouTubeDownloadController.audioURL = qualityInfo[@"audioUrl"];
    rebornYouTubeDownloadController.dualURL = nil;
    rebornYouTubeDownloadController.artworkURL = [NSURL URLWithString:videoArtworkArray[([videoArtworkArray count] - 1)][@"url"]];
    rebornYouTubeDownloadController.downloadOption = 1;

    UIViewController *rebornYouTubeDownloadViewController = self._viewControllerForAncestor;
    [rebornYouTubeDownloadViewController presentViewController:rebornYouTubeDownloadController animated:YES completion:nil];
}

%new;
- (void)rebornPlayInExternalApp :(NSString *)videoID {
    NSDictionary *youtubePlayerRequest = [YouTubeExtractor youtubePlayerRequest:@"ios":videoID];
    NSURL *videoPath = [NSURL URLWithString:[NSString stringWithFormat:@"%@", youtubePlayerRequest[@"streamingData"][@"hlsManifestUrl"]]];

    UIAlertController *alertApp = [UIAlertController alertControllerWithTitle:@"Choose App" message:nil preferredStyle:UIAlertControllerStyleAlert];

    [alertApp addAction:[UIAlertAction actionWithTitle:@"Play In Infuse" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"infuse://x-callback-url/play?url=%@", videoPath]] options:@{} completionHandler:nil];
    }]];

    [alertApp addAction:[UIAlertAction actionWithTitle:@"Play In VLC" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"vlc-x-callback://x-callback-url/stream?url=%@", videoPath]] options:@{} completionHandler:nil];
    }]];

    [alertApp addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];

    UIViewController *alertAppViewController = [self _viewControllerForAncestor];
    [alertAppViewController presentViewController:alertApp animated:YES completion:nil];
}
%end

// No YouTube Ads
%group gNoVideoAds
%hook YTHotConfig
- (BOOL)disableAfmaIdfaCollection { return NO; }
%end
%hook YTIPlayerResponse
- (BOOL)isMonetized { return NO; }
%end
%hook YTDataUtils
+ (id)spamSignalsDictionary { return @{}; }
+ (id)spamSignalsDictionaryWithoutIDFA { return @{}; }
%end
%hook YTAdsInnerTubeContextDecorator
- (void)decorateContext:(id)context { %orig(nil); }
%end
%hook YTAccountScopedAdsInnerTubeContextDecorator
- (void)decorateContext:(id)context { %orig(nil); }
%end
%hook YTReelInfinitePlaybackDataSource
- (void)setReels:(NSMutableOrderedSet <YTReelModel *> *)reels {
    [reels removeObjectsAtIndexes:[reels indexesOfObjectsPassingTest:^BOOL(YTReelModel *obj, NSUInteger idx, BOOL *stop) {
        return [obj respondsToSelector:@selector(videoType)] ? obj.videoType == 3 : NO;
    }]];
    %orig;
}
%end
BOOL isAdString(NSString *description) {
    if ([description containsString:@"brand_promo"]
        || [description containsString:@"carousel_footered_layout"]
        || [description containsString:@"carousel_headered_layout"]
        || [description containsString:@"feed_ad_metadata"]
        || [description containsString:@"full_width_portrait_image_layout"]
        || [description containsString:@"full_width_square_image_layout"]
        || [description containsString:@"home_video_with_context"]
        || [description containsString:@"landscape_image_wide_button_layout"]
        || [description containsString:@"product_engagement_panel"]
        || [description containsString:@"product_item"]
        || [description containsString:@"shelf_header"]
        || [description containsString:@"square_image_layout"]
        || [description containsString:@"text_image_button_layout"]
        || [description containsString:@"text_search_ad"]
        || [description containsString:@"expandable_list"]
        || [description containsString:@"expandable_metadata"]
        || [description containsString:@"video_display_full_layout"]
        || [description containsString:@"video_display_full_buttoned_layout"])
        return YES;
    return NO;
}
NSData *cellDividerData;
%hook YTIElementRenderer
- (NSData *)elementData {
    NSString *description = [self description];
    if ([description containsString:@"cell_divider"]) {
        if (!cellDividerData) cellDividerData = %orig;
        return cellDividerData;
    }
    if ([self respondsToSelector:@selector(hasCompatibilityOptions)] && self.hasCompatibilityOptions && self.compatibilityOptions.hasAdLoggingData) return cellDividerData;
    return %orig;
}
%end
%hook YTInnerTubeCollectionViewController
- (void)loadWithModel:(YTISectionListRenderer *)model {
    if ([model isKindOfClass:%c(YTISectionListRenderer)]) {
        NSMutableArray <YTISectionListSupportedRenderers *> *contentsArray = model.contentsArray;
        NSIndexSet *removeIndexes = [contentsArray indexesOfObjectsPassingTest:^BOOL(YTISectionListSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
            if (![renderers isKindOfClass:%c(YTISectionListSupportedRenderers)])
                return NO;
            YTIItemSectionRenderer *sectionRenderer = renderers.itemSectionRenderer;
            YTIItemSectionSupportedRenderers *firstObject = [sectionRenderer.contentsArray firstObject];
            YTIElementRenderer *elementRenderer = firstObject.elementRenderer;
            NSString *description = [elementRenderer description];
            return isAdString(description)
                || [description containsString:@"post_shelf"]
                || [description containsString:@"product_carousel"]
                || [description containsString:@"statement_banner"];
        }];
        [contentsArray removeObjectsAtIndexes:removeIndexes];
    }
    %orig;
}
%end
%hook YTWatchNextResultsViewController
- (void)loadWithModel:(YTISectionListRenderer *)watchNextResults {
    if ([watchNextResults isKindOfClass:%c(YTISectionListRenderer)]) {
        NSMutableArray <YTISectionListSupportedRenderers *> *contentsArray = watchNextResults.contentsArray;
        NSIndexSet *removeIndexes = [contentsArray indexesOfObjectsPassingTest:^BOOL(YTISectionListSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
            if (![renderers isKindOfClass:%c(YTISectionListSupportedRenderers)])
                return NO;
            YTIItemSectionRenderer *sectionRenderer = renderers.itemSectionRenderer;
            YTIItemSectionSupportedRenderers *firstObject = [sectionRenderer.contentsArray firstObject];
            YTIElementRenderer *elementRenderer = firstObject.elementRenderer;
            NSString *description = [elementRenderer description];
            return isAdString(description);
        }];
        [contentsArray removeObjectsAtIndexes:removeIndexes];
    }
    %orig;
}
%end
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig();
    if ([self.accessibilityIdentifier isEqualToString:@"id.products_in_video_with_preview_overlay_badge.view"]) self.hidden = YES; 
}
%end
%end

// Remove “Play next in queue” from the menu by @PoomSmart
%group gHidePlayNextInQueue
%hook YTMenuItemVisibilityHandler
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    return renderer.icon.iconType == 251 ? NO : %orig;
}
%end
%end

// Hide Upgrade Dialog by @arichorn
%hook YTGlobalConfig
- (BOOL)shouldBlockUpgradeDialog { return YES;}
- (BOOL)shouldForceUpgrade { return NO;}
- (BOOL)shouldShowUpgrade { return NO;}
- (BOOL)shouldShowUpgradeDialog { return NO;}
%end

%group gBackgroundPlayback
%hook YTIPlayerResponse
- (BOOL)isPlayableInBackground {
    return YES;
}
%end
%hook YTSingleVideo
- (BOOL)isPlayableInBackground {
    return YES;
}
%end
%hook YTSingleVideoMediaData
- (BOOL)isPlayableInBackground {
    return YES;
}
%end
%hook YTPlaybackData
- (BOOL)isPlayableInBackground {
    return YES;
}
%end
%hook YTIPlayabilityStatus
- (BOOL)isPlayableInBackground {
    return YES;
}
%end
%hook YTPlaybackBackgroundTaskController
- (BOOL)isContentPlayableInBackground {
    return YES;
}
- (void)setContentPlayableInBackground:(BOOL)arg1 {
    %orig(YES);
}
%end
%hook YTBackgroundabilityPolicy
- (BOOL)isBackgroundableByUserSettings {
    return YES;
}
%end
%end

%group gExtraSpeedOptions
%hook YTVarispeedSwitchController
- (void *)init {
    void *ret = (void *)%orig;

    NSMutableArray *ytSpeedOptions = [NSMutableArray new];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"0.1x" rate:0.1]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"0.25x" rate:0.25]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"0.5x" rate:0.5]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"0.75x" rate:0.75]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"Normal" rate:1]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"1.25x" rate:1.25]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"1.5x" rate:1.5]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"1.75x" rate:1.75]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"2x" rate:2]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"2.5x" rate:2.5]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"3x" rate:3]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"3.5x" rate:3.5]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"4x" rate:4]];
    [ytSpeedOptions addObject:[[NSClassFromString(@"YTVarispeedSwitchControllerOption") alloc] initWithTitle:@"5x" rate:5]];
    MSHookIvar<NSArray *>(self, "_options") = [ytSpeedOptions copy];

    return ret;
}
%end
%hook MLHAMQueuePlayer
- (void)setRate:(float)rate {
	MSHookIvar<float>(self, "_rate") = rate;

	id ytPlayer = MSHookIvar<HAMPlayerInternal *>(self, "_player");
	[ytPlayer setRate:rate];

	[self.playerEventCenter broadcastRateChange:rate];
}
%end
%end

%group gLowContrastMode // Low Contrast Mode v1.4.2 (Compatible with only YouTube v16.05.7-v17.38.10)
%hook UIColor
+ (UIColor *)whiteColor { // Dark Theme Color
    if (lcmHexColor) {
        return lcmHexColor;
    }
    return [UIColor colorWithRed: 0.56 green: 0.56 blue: 0.56 alpha: 1.00];
}
+ (UIColor *)lightTextColor {
    if (lcmHexColor) {
        return lcmHexColor;
    }
    return [UIColor colorWithRed: 0.56 green: 0.56 blue: 0.56 alpha: 1.00];
}
+ (UIColor *)placeholderTextColor {
    if (lcmHexColor) {
        return lcmHexColor;
    }
    return [UIColor colorWithRed: 0.56 green: 0.56 blue: 0.56 alpha: 1.00];
}
+ (UIColor *)labelColor {
    if (lcmHexColor) {
        return lcmHexColor;
    }
    return [UIColor colorWithRed: 0.56 green: 0.56 blue: 0.56 alpha: 1.00];
}
+ (UIColor *)secondaryLabelColor {
    if (lcmHexColor) {
        return lcmHexColor;
    }
    return [UIColor colorWithRed: 0.56 green: 0.56 blue: 0.56 alpha: 1.00];
}
+ (UIColor *)tertiaryLabelColor {
    if (lcmHexColor) {
        return lcmHexColor;
    }
    return [UIColor colorWithRed: 0.56 green: 0.56 blue: 0.56 alpha: 1.00];
}
+ (UIColor *)quaternaryLabelColor {
    if (lcmHexColor) {
        return lcmHexColor;
    }
    return [UIColor colorWithRed: 0.56 green: 0.56 blue: 0.56 alpha: 1.00];
}
%end
%hook YTCommonColorPalette
- (UIColor *)textPrimary {
    return self.pageStyle == 1 ? [UIColor whiteColor] : %orig;
}
- (UIColor *)textSecondary {
    return self.pageStyle == 1 ? [UIColor whiteColor] : %orig;
}
- (UIColor *)overlayTextPrimary {
    return self.pageStyle == 1 ? [UIColor whiteColor] : %orig;
}
- (UIColor *)overlayTextSecondary {
    return self.pageStyle == 1 ? [UIColor whiteColor] : %orig;
}
- (UIColor *)iconActive {
    return self.pageStyle == 1 ? [UIColor whiteColor] : %orig;
}
- (UIColor *)iconActiveOther {
    return self.pageStyle == 1 ? [UIColor whiteColor] : %orig;
}
- (UIColor *)brandIconActive {
    return self.pageStyle == 1 ? [UIColor whiteColor] : %orig;
}
- (UIColor *)staticBrandWhite {
    return self.pageStyle == 1 ? [UIColor whiteColor] : %orig;
}
- (UIColor *)overlayIconActiveOther {
    return self.pageStyle == 1 ? [UIColor whiteColor] : %orig;
}
%end
%hook YTColor
+ (UIColor *)white1 {
    return [UIColor whiteColor];
}
+ (UIColor *)white2 {
    return [UIColor whiteColor];
}
+ (UIColor *)white3 {
    return [UIColor whiteColor];
}
+ (UIColor *)white4 {
    return [UIColor whiteColor];
}
+ (UIColor *)white5 {
    return [UIColor whiteColor];
}
%end
%hook QTMColorGroup
- (UIColor *)tint100 {
    return [UIColor whiteColor];
}
- (UIColor *)tint300 {
    return [UIColor whiteColor];
}
- (UIColor *)bodyTextColor {
    return [UIColor whiteColor];
}
- (UIColor *)bodyTextColorOnLighterColor {
    return [UIColor whiteColor];
}
- (UIColor *)bodyTextColorOnRegularColor {
    return [UIColor whiteColor];
}
- (UIColor *)bodyTextColorOnDarkerColor {
    return [UIColor whiteColor];
}
- (UIColor *)bodyTextColorOnAccentColor {
    return [UIColor whiteColor];
}
- (UIColor *)bodyTextColorOnOnBrightAccentColor {
    return [UIColor whiteColor];
}
- (UIColor *)lightBodyTextColor {
    return [UIColor whiteColor];
}
- (UIColor *)buttonBackgroundColor {
    return [UIColor whiteColor];
}
%end
%hook YTQTMButton
- (void)setImage:(UIImage *)image {
    UIImage *currentImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self setTintColor:[UIColor whiteColor]];
    %orig(currentImage);
}
%end
%hook UIExtendedSRGColorSpace
- (void)setTextColor:(UIColor *)textColor {
    textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
    %orig();
}
%end
%hook VideoTitleLabel
- (void)setTextColor:(UIColor *)textColor {
    textColor = [UIColor whiteColor];
    %orig(textColor);
}
%end
%hook UILabel
+ (void)load {
    @autoreleasepool {
        [[UILabel appearance] setTextColor:[UIColor whiteColor]];
    }
}
- (void)setTextColor:(UIColor *)textColor {
    %log;
    textColor = [UIColor whiteColor];
    %orig(textColor);
}
%end
%hook UITextField
- (void)setTextColor:(UIColor *)textColor {
    %log;
    textColor = [UIColor whiteColor];
    %orig(textColor);
}
%end
%hook UITextView
- (void)setTextColor:(UIColor *)textColor {
    %log;
    textColor = [UIColor whiteColor];
    %orig(textColor);
}
%end
%hook UISearchBar
- (void)setTextColor:(UIColor *)textColor {
    textColor = [UIColor whiteColor];
    %orig(textColor);
}
%end
%hook UISegmentedControl
- (void)setTitleTextAttributes:(NSDictionary *)attributes forState:(UIControlState)state {
    NSMutableDictionary *modifiedAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
    [modifiedAttributes setObject:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    %orig(modifiedAttributes, state);
}
%end
%hook UIButton
- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state {
    color = [UIColor whiteColor];
    %orig(color, state);
}
%end
%hook UIBarButtonItem
- (void)setTitleTextAttributes:(NSDictionary *)attributes forState:(UIControlState)state {
    NSMutableDictionary *modifiedAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
    [modifiedAttributes setObject:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    %orig(modifiedAttributes, state);
}
%end
%hook NSAttributedString
- (instancetype)initWithString:(NSString *)str attributes:(NSDictionary<NSAttributedStringKey, id> *)attrs {
    NSMutableDictionary *modifiedAttributes = [NSMutableDictionary dictionaryWithDictionary:attrs];
    [modifiedAttributes setObject:[UIColor whiteColor] forKey:NSForegroundColorAttributeName];
    return %orig(str, modifiedAttributes);
}
%end
%hook CATextLayer
- (void)setTextColor:(CGColorRef)textColor {
    %orig([UIColor whiteColor].CGColor);
}
%end
%hook ASTextNode
- (NSAttributedString *)attributedString {
    NSAttributedString *originalAttributedString = %orig;
    NSMutableAttributedString *newAttributedString = [originalAttributedString mutableCopy];
    [newAttributedString addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, newAttributedString.length)];
    return newAttributedString;
}
%end
%hook ASTextFieldNode
- (void)setTextColor:(UIColor *)textColor {
   %orig([UIColor whiteColor]);
}
%end
%hook ASTextView
- (void)setTextColor:(UIColor *)textColor {
   %orig([UIColor whiteColor]);
}
%end
%hook ASButtonNode
- (void)setTextColor:(UIColor *)textColor {
   %orig([UIColor whiteColor]);
}
%end
%end

// Auto-Hide Home Bar by @arichorn
%group gAutoHideHomeBar
%hook UIViewController
- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}
%end
%end

%group gNoCastButton
%hook YTSettings
- (BOOL)disableMDXDeviceDiscovery {
    return YES;
} 
%end
%hook YTRightNavigationButtons
- (void)layoutSubviews {
	%orig();
	self.MDXButton.hidden = YES;
}
%end
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
	self.playbackRouteButton.hidden = YES;
}
%end
%end

%group gNoNotificationButton
%hook YTNotificationPreferenceToggleButton
- (void)setHidden:(BOOL)arg1 {
    %orig(YES);
}
%end
%hook YTNotificationMultiToggleButton
- (void)setHidden:(BOOL)arg1 {
    %orig(YES);
}
%end
%hook YTRightNavigationButtons
- (void)layoutSubviews {
	%orig();
	self.notificationButton.hidden = YES;
}
%end
%end

%group gAllowHDOnCellularData
%hook YTUserDefaults
- (BOOL)disableHDOnCellular {
	return NO;
}
- (void)setDisableHDOnCellular:(BOOL)arg1 {
    %orig(NO);
}
%end
%hook YTSettings
- (BOOL)disableHDOnCellular {
	return NO;
}
- (void)setDisableHDOnCellular:(BOOL)arg1 {
    %orig(NO);
}
%end
%end

%group gShowStatusBarInOverlay
%hook YTSettings
- (BOOL)showStatusBarWithOverlay {
    return YES;
}
%end
%end

%group gPortraitFullscreen // @Dayanch96
%hook YTWatchViewController
- (unsigned long long)allowedFullScreenOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}
%end
%end

%group gDisableRelatedVideosInOverlay
%hook YTRelatedVideosViewController
- (BOOL)isEnabled {
    return NO;
}
- (void)setEnabled:(BOOL)arg1 {
    %orig(NO);
}
%end
%hook YTFullscreenEngagementOverlayView
- (BOOL)isEnabled {
    return NO;
} 
- (void)setEnabled:(BOOL)arg1 {
    %orig(NO);
} 
%end
%hook YTFullscreenEngagementOverlayController
- (BOOL)isEnabled {
    return NO;
}
- (void)setEnabled:(BOOL)arg1 {
    %orig(NO);
}
%end
%hook YTMainAppVideoPlayerOverlayView
- (void)setInfoCardButtonHidden:(BOOL)arg1 {
    %orig(YES);
}
- (void)setInfoCardButtonVisible:(BOOL)arg1 {
    %orig(NO);
}
%end
%hook YTMainAppVideoPlayerOverlayViewController
- (void)adjustPlayerBarPositionForRelatedVideos {
}
%end
%end

%group gDisableVideoEndscreenPopups
%hook YTCreatorEndscreenView
- (id)initWithFrame:(CGRect)arg1 {
    return NULL;
}
%end
%end

%group gDisableYouTubeKids
%hook YTWatchMetadataAppPromoCell
- (id)initWithFrame:(CGRect)arg1 {
    return NULL;
}
%end
%hook YTHUDMessageView
- (id)initWithMessage:(id)arg1 dismissHandler:(id)arg2 {
    return NULL;
}
%end
%hook YTNGWatchMiniBarViewController
- (id)miniplayerRenderer {
    return NULL;
}
%end
%hook YTWatchMiniBarViewController
- (id)miniplayerRenderer {
    return NULL;
}
- (void)updateMiniBarPlayerStateFromRenderer {
    %orig;
}
%end
%end

%group gDisableHints
%hook YTSettings
- (BOOL)areHintsDisabled {
	return YES;
}
- (void)setHintsDisabled:(BOOL)arg1 {
    %orig(YES);
}
%end
%hook YTUserDefaults
- (BOOL)areHintsDisabled {
	return YES;
}
- (void)setHintsDisabled:(BOOL)arg1 {
    %orig(YES);
}
%end
%end

%group gHideExploreTab
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FEexplore"];
    }];
    if (index != NSNotFound) [items removeObjectAtIndex:index];

    %orig;
}
%end
%end

%group gHideShortsTab
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FEshorts"];
    }];
    if (index != NSNotFound) [items removeObjectAtIndex:index];

    %orig;
}
%end
%end

%group gHideUploadTab
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarIconOnlyItemRenderer] pivotIdentifier] isEqualToString:@"FEuploads"];
    }];
    if (index != NSNotFound) [items removeObjectAtIndex:index];

    %orig;
}
%end
%end

%group gHideSubscriptionsTab
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FEsubscriptions"];
    }];
    if (index != NSNotFound) [items removeObjectAtIndex:index];

    %orig;
}
%end
%end

%group gHideYouTab
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FElibrary"];
    }];
    if (index != NSNotFound) [items removeObjectAtIndex:index];

    %orig;
}
%end
%end

%group gDisableDoubleTapToSkip
%hook YTMainAppVideoPlayerOverlayViewController
- (BOOL)allowDoubleTapToSeekGestureRecognizer {
    return NO;
}
%end
%end

%group gHideOverlayDarkBackground
%hook YTMainAppVideoPlayerOverlayView
- (void)setBackgroundVisible:(BOOL)arg1 isGradientBackground:(BOOL)arg2 {
    %orig(NO, arg2);
}
%end
%end

%group gEnableiPadStyleOniPhone
%hook UIDevice
- (long long)userInterfaceIdiom {
    return YES;
} 
%end
%hook UIStatusBarStyleAttributes
- (long long)idiom {
    return NO;
} 
%end
%hook UIKBTree
- (long long)nativeIdiom {
    return NO;
} 
%end
%hook UIKBRenderer
- (long long)assetIdiom {
    return NO;
} 
%end
%end

%group gEnableiPhoneStyleOniPad
%hook UIDevice
- (long long)userInterfaceIdiom {
    return NO;
} 
%end
%hook UIStatusBarStyleAttributes
- (long long)idiom {
    return YES;
} 
%end
%hook UIKBTree
- (long long)nativeIdiom {
    return YES;
} 
%end
%hook UIKBRenderer
- (long long)assetIdiom {
    return YES;
} 
%end
%end

%group gHidePreviousButtonInOverlay
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
	MSHookIvar<YTMainAppControlsOverlayView *>(self, "_previousButton").hidden = YES;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_previousButtonView").hidden = YES;
}
%end
%end

%group gHideNextButtonInOverlay
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
	MSHookIvar<YTMainAppControlsOverlayView *>(self, "_nextButton").hidden = YES;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_nextButtonView").hidden = YES;
}
%end
%end

%group gHidePreviousButtonShadowInOverlay
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
    MSHookIvar<YTTransportControlsButtonView *>(self, "_previousButtonView").backgroundColor = nil;
}
%end
%end

%group gHideNextButtonShadowInOverlay
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
    MSHookIvar<YTTransportControlsButtonView *>(self, "_nextButtonView").backgroundColor = nil;
}
%end
%end

%group gHideSeekBackwardButtonShadowInOverlay
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
    MSHookIvar<YTTransportControlsButtonView *>(self, "_seekBackwardAccessibilityButtonView").backgroundColor = nil;
}
%end
%end

%group gHideSeekForwardButtonShadowInOverlay
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
    MSHookIvar<YTTransportControlsButtonView *>(self, "_seekForwardAccessibilityButtonView").backgroundColor = nil;
}
%end
%end

%group gHidePlayPauseButtonShadowInOverlay
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
	MSHookIvar<YTPlaybackButton *>(self, "_playPauseButton").backgroundColor = nil;
}
%end
%end

%group gDisableVideoAutoPlay
%hook YTPlaybackConfig
- (void)setStartPlayback:(BOOL)arg1 {
	%orig(NO);
}
%end
%end

%group gHideAutoPlaySwitchInOverlay
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
	self.autonavSwitch.hidden = YES;
}
%end
%end

%group gHideCaptionsSubtitlesButtonInOverlay
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
    self.closedCaptionsOrSubtitlesButton.hidden = YES;
}
%end
%end

%group gDisableVideoInfoCards
%hook YTInfoCardDarkTeaserContainerView
- (id)initWithFrame:(CGRect)arg1 {
    return NULL;
}
- (BOOL)isVisible {
    return NO;
}
%end
%hook YTInfoCardTeaserContainerView
- (id)initWithFrame:(CGRect)arg1 {
    return NULL;
}
- (BOOL)isVisible {
    return NO;
}
%end
%hook YTSimpleInfoCardDarkTeaserView
- (id)initWithFrame:(CGRect)arg1 {
    return NULL;
}
%end
%hook YTSimpleInfoCardTeaserView
- (id)initWithFrame:(CGRect)arg1 {
    return NULL;
}
%end
%hook YTPaidContentViewController
- (id)initWithParentResponder:(id)arg1 paidContentRenderer:(id)arg2 enableNewPaidProductDisclosure:(BOOL)arg3 {
    return %orig(arg1, NULL, NO);
}
%end
%hook YTPaidContentOverlayView
- (id)initWithParentResponder:(id)arg1 paidContentRenderer:(id)arg2 enableNewPaidProductDisclosure:(BOOL)arg3 {
    return %orig(arg1, NULL, NO);
}
%end
%end

%group gNoSearchButton
%hook YTRightNavigationButtons
- (void)layoutSubviews {
	%orig();
	self.searchButton.hidden = YES;
}
%end
%end

%group gHideTabBarLabels
%hook YTPivotBarItemView
- (void)layoutSubviews {
    %orig();
    [[self navigationButton] setTitle:@"" forState:UIControlStateNormal];
    [[self navigationButton] setTitle:@"" forState:UIControlStateSelected];
}
%end

%hook YTPivotBarIndicatorView
- (void)didMoveToWindow {
    [self setHidden:YES];
    %orig();
}
%end
%end

%group gHideChannelWatermark
%hook YTAnnotationsViewController
- (void)loadFeaturedChannelWatermark {
}
%end
%hook YTColdConfig
- (BOOL)iosEnableFeaturedChannelWatermarkOverlayFix { return NO; }
%end
%end

%group gHideShortsChannelAvatarButton
%hook YTReelWatchPlaybackOverlayView
- (void)setNativePivotButton:(id)arg1 {
    %orig;
}
%end
%end

%group gHideShortsLikeButton
%hook YTReelWatchPlaybackOverlayView
- (void)layoutSubviews {
	%orig();
	MSHookIvar<YTQTMButton *>(self, "_reelLikeButton").hidden = YES;
}
- (void)setReelLikeButton:(id)arg1 {
    %orig;
}
%end
%end

%group gHideShortsDislikeButton
%hook YTReelWatchPlaybackOverlayView
- (void)layoutSubviews {
	%orig();
	MSHookIvar<YTQTMButton *>(self, "_reelDislikeButton").hidden = YES;
}
- (void)setReelDislikeButton:(id)arg1 {
    %orig;
}
%end
%end

%group gHideShortsCommentsButton
%hook YTReelWatchPlaybackOverlayView
- (void)layoutSubviews {
	%orig();
	MSHookIvar<YTQTMButton *>(self, "_viewCommentButton").hidden = YES;
}
- (void)setViewCommentButton:(id)arg1 {
    %orig;
}
%end
%end

%group gHideShortsRemixButton
%hook YTReelWatchPlaybackOverlayView
- (void)layoutSubviews {
	%orig();
	MSHookIvar<YTQTMButton *>(self, "_remixButton").hidden = YES;
}
- (void)setRemixButton:(id)arg1 {
    %orig;
}
%end
%end

%group gHideShortsShareButton
%hook YTReelWatchPlaybackOverlayView
- (void)layoutSubviews {
	%orig();
	MSHookIvar<YTQTMButton *>(self, "_shareButton").hidden = YES;
}
- (void)setShareButton:(id)arg1 {
    %orig;
}
%end
%end

%group gHideShortsMoreActionsButton
%hook YTReelWatchPlaybackOverlayView
- (void)layoutSubviews {
	%orig();
	MSHookIvar<YTQTMButton *>(self, "_moreButton").hidden = YES;
}
- (void)setMoreButton:(id)arg1 {
    %orig;
}
%end
%end

%group gHideShortsSearchButton
%hook YTReelTransparentStackView
- (void)layoutSubviews {
    %orig;
    if (self.subviews.count >= 3 && [self.subviews[0].accessibilityIdentifier isEqualToString:@"id.ui.generic.button"]) {
        self.subviews[0].hidden = YES;
    }
}
%end
%end

%group gHideShortsBuySuperThanks
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig();
    if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.suggested_action"]) { 
        self.hidden = YES; 
    }
}
%end
%end

%group gHideShortsSubscriptionsButton
%hook YTReelWatchRootViewController
- (void)setPausedStateCarouselView {
}
%end
%end

%group gDisableResumeToShorts
%hook YTShortsStartupCoordinator
- (id)evaluateResumeToShorts {
    return nil;
}
%end
%end

%group gAlwaysShowShortsPlayerBar
%hook YTShortsPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTReelPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTColdConfig
- (BOOL)iosEnableVideoPlayerScrubber { return YES; }
- (BOOL)mobileShortsTablnlinedExpandWatchOnDismiss { return YES; }
%end

%hook YTHotConfig
- (BOOL)enablePlayerBarForVerticalVideoWhenControlsHiddenInFullscreen { return YES; }
%end
%end

%group gColourOptions
%hook YTCommonColorPalette
- (UIColor *)background1 {
    return rebornHexColour;
}
- (UIColor *)background2 {
    return rebornHexColour;
}
- (UIColor *)background3 {
    return rebornHexColour;
}
- (UIColor *)baseBackground {
    return rebornHexColour;
}
- (UIColor *)brandBackgroundSolid {
    return rebornHexColour;
}
- (UIColor *)brandBackgroundPrimary {
    return rebornHexColour;
}
- (UIColor *)brandBackgroundSecondary {
    return rebornHexColour;
}
- (UIColor *)raisedBackground {
    return rebornHexColour;
}
- (UIColor *)staticBrandBlack {
    return rebornHexColour;
}
- (UIColor *)generalBackgroundA {
    return rebornHexColour;
}
- (UIColor *)generalBackgroundB {
    return rebornHexColour;
}
- (UIColor *)menuBackground {
    return rebornHexColour;
}
%end
%hook UITableViewCell
- (void)_layoutSystemBackgroundView {
    %orig;
    NSString *backgroundViewKey = class_getInstanceVariable(self.class, "_colorView") ? @"_colorView" : @"_backgroundView";
    ((UIView *)[[self valueForKey:@"_systemBackgroundView"] valueForKey:backgroundViewKey]).backgroundColor = rebornHexColour;
}
- (void)_layoutSystemBackgroundView:(BOOL)arg1 {
    %orig;
    ((UIView *)[[self valueForKey:@"_systemBackgroundView"] valueForKey:@"_colorView"]).backgroundColor = rebornHexColour;
}
%end
%hook settingsReorderTable
- (void)viewDidLayoutSubviews {
    %orig;
    self.tableView.backgroundColor = rebornHexColour;
}
%end
%hook FRPSelectListTable
- (void)viewDidLayoutSubviews {
    %orig;
    self.tableView.backgroundColor = rebornHexColour;
}
%end
%hook FRPreferences
- (void)viewDidLayoutSubviews {
    %orig;
    self.tableView.backgroundColor = rebornHexColour;
}
%end
%hook SponsorBlockSettingsController
- (void)viewDidLoad {
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        %orig;
        self.tableView.backgroundColor = rebornHexColour;
    } else { return %orig; }
}
%end
%hook SponsorBlockViewController
- (void)viewDidLoad {
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        %orig;
        self.view.backgroundColor = rebornHexColour;
    } else { return %orig; }
}
%end
%hook YTAsyncCollectionView
- (void)layoutSubviews {
    %orig();
    if ([self.nextResponder isKindOfClass:NSClassFromString(@"YTWatchNextResultsViewController")]) {
        self.subviews[0].subviews[0].backgroundColor = rebornHexColour;
    }
}
%end
%hook YTPivotBarView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTHeaderView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTSubheaderContainerView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTAppView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTCollectionView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTChannelListSubMenuView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTSettingsCell
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTSlideForActionsView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTPageView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTWatchView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTPlaylistMiniBarView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTEngagementPanelView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTEngagementPanelHeaderView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTPlaylistPanelControlsView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTHorizontalCardListView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTWatchMiniBarView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTCommentView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTCommentDetailHeaderCell
- (void)didMoveToWindow {
    %orig;
    self.subviews[2].backgroundColor = rebornHexColour;
}
%end
%hook YTCreateCommentAccessoryView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTCreateCommentTextView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTSearchView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTVideoView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTSearchBoxView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTTabTitlesView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTPrivacyTosFooterView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTOfflineStorageUsageView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTInlineSignInView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTFeedChannelFilterHeaderView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YCHLiveChatView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YCHLiveChatActionPanelView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTEmojiTextView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTTopAlignedView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
- (void)layoutSubviews {
    %orig();
    MSHookIvar<YTTopAlignedView *>(self, "_contentView").backgroundColor = rebornHexColour;
}
%end
%hook GOODialogView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTNavigationBar
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
- (void)setBarTintColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTChannelMobileHeaderView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTChannelSubMenuView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTWrapperSplitView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTReelShelfCell
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTReelShelfItemView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTReelShelfView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTChannelListSubMenuAvatarView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTSearchBarView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YCHLiveChatBannerCell
- (void)layoutSubviews {
	%orig();
	MSHookIvar<UIImageView *>(self, "_bannerContainerImageView").hidden = YES;
    MSHookIvar<UIView *>(self, "_bannerContainerView").backgroundColor = rebornHexColour;
}
%end
%hook YTDialogContainerScrollView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTShareTitleView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTShareBusyView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTELMView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTActionSheetHeaderView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(rebornHexColour);
}
%end
%hook YTCreateCommentTextView
- (void)setTextColor:(UIColor *)color {
    long long ytDarkModeCheck = [ytThemeSettings appThemeSetting];
    if (ytDarkModeCheck == 0 || ytDarkModeCheck == 1) {
        if (UIScreen.mainScreen.traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight) {
            color = [UIColor blackColor];
        } else {
            color = [UIColor whiteColor];
        }
    }
    if (ytDarkModeCheck == 2) {
        color = [UIColor blackColor];
    }
    if (ytDarkModeCheck == 3) {
        color = [UIColor whiteColor];
    }
    %orig;
}
%end
%hook YTShareMainView
- (void)layoutSubviews {
	%orig();
    MSHookIvar<YTQTMButton *>(self, "_cancelButton").backgroundColor = rebornHexColour;
    MSHookIvar<UIControl *>(self, "_safeArea").backgroundColor = rebornHexColour;
}
%end
%hook _ASDisplayView
- (void)layoutSubviews {
	%orig();
    UIResponder *responder = [self nextResponder];
    while (responder != nil) {
        if ([responder isKindOfClass:NSClassFromString(@"YTActionSheetDialogViewController")]) {
            self.backgroundColor = rebornHexColour;
        }
        if ([responder isKindOfClass:NSClassFromString(@"YTPanelLoadingStrategyViewController")]) {
            self.backgroundColor = rebornHexColour;
        }
        if ([responder isKindOfClass:NSClassFromString(@"YTTabHeaderElementsViewController")]) {
            self.backgroundColor = rebornHexColour;
        }
        if ([responder isKindOfClass:NSClassFromString(@"YTEditSheetControllerElementsContentViewController")]) {
            self.backgroundColor = rebornHexColour;
        }
        responder = [responder nextResponder];
    }
}
- (void)didMoveToWindow {
    %orig;
        if ([self.nextResponder isKindOfClass:%c(ASScrollView)]) { self.backgroundColor = [UIColor clearColor]; }
        if ([self.accessibilityIdentifier isEqualToString:@"brand_promo.view"]) { self.superview.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"eml.cvr"]) { self.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"eml.live_chat_text_message"]) { self.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"rich_header"]) { self.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"id.ui.comment_cell"]) { self.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"id.ui.comment_thread"]) { self.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"id.ui.cancel.button"]) { self.superview.backgroundColor = [UIColor clearColor]; }
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.comment_composer"]) { self.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.filter_chip_bar"]) { self.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.video_list_entry"]) { self.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"id.comment.guidelines_text"]) { self.superview.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"id.comment.timed_comments_welcome"]) { self.superview.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"id.comment.channel_guidelines_bottom_sheet_container"]) { self.backgroundColor = rebornHexColour; }
        if ([self.accessibilityIdentifier isEqualToString:@"id.comment.channel_guidelines_entry_banner_container"]) { self.backgroundColor = rebornHexColour; }
	if ([self.accessibilityIdentifier isEqualToString:@"id.comment.comment_group_detail_container"]) { self.backgroundColor = [UIColor clearColor]; }
}
%end
%end

%group gAutoFullScreen
%hook YTPlayerViewController
- (void)loadWithPlayerTransition:(id)arg1 playbackConfig:(id)arg2 {
    %orig();
    [NSTimer scheduledTimerWithTimeInterval:0.75 target:self selector:@selector(autoFullscreen) userInfo:nil repeats:NO];
}
%new
- (void)autoFullscreen {
    YTWatchController *watchController = [self valueForKey:@"_UIDelegate"];
    [watchController showFullScreen];
}
%end
%end

// YouTube Premium Logo - @arichornlover & @bhackel
%group gPremiumYouTubeLogo
%hook YTHeaderLogoController
- (void)setTopbarLogoRenderer:(YTITopbarLogoRenderer *)renderer {
    YTIIcon *iconImage = renderer.iconImage;
    iconImage.iconType = 537;
    %orig;
}
- (void)setPremiumLogo:(BOOL)isPremiumLogo {
    isPremiumLogo = YES;
    %orig;
}
- (BOOL)isPremiumLogo {
    return YES;
}
%end

%hook YTAppCollectionViewController
%new
- (void)uYouEnhancedFakePremiumModel:(YTISectionListRenderer *)model {
    Class YTVersionUtilsClass = %c(YTVersionUtils);
    NSString *appVersion = [YTVersionUtilsClass performSelector:@selector(appVersion)];
    NSComparisonResult result = [appVersion compare:@"18.35.4" options:NSNumericSearch];
    if (result == NSOrderedAscending) {
        return;
    }
    NSUInteger yourVideosCellIndex = -1;
    NSMutableArray <YTISectionListSupportedRenderers *> *overallContentsArray = model.contentsArray;
    YTISectionListSupportedRenderers *supportedRenderers;
    for (supportedRenderers in overallContentsArray) {
        YTIItemSectionRenderer *itemSectionRenderer = supportedRenderers.itemSectionRenderer;
        NSMutableArray <YTIItemSectionSupportedRenderers *> *subContentsArray = itemSectionRenderer.contentsArray;
        YTIItemSectionSupportedRenderers *itemSectionSupportedRenderers;
        for (itemSectionSupportedRenderers in subContentsArray) {
            if ([itemSectionSupportedRenderers hasCompactLinkRenderer]) {
                YTICompactLinkRenderer *compactLinkRenderer = [itemSectionSupportedRenderers compactLinkRenderer];
                if ([compactLinkRenderer hasIcon]) {
                    YTIIcon *icon = [compactLinkRenderer icon];
                    if ([icon hasIconType] && icon.iconType == 741) {
                        if ([((YTIStringRun *)(compactLinkRenderer.title.runsArray.firstObject)).text isEqualToString:@"Downloads"]) {
                            DownloadsController *downloadsController = [[DownloadsController alloc] init];
                            [self.navigationController pushViewController:downloadsController animated:YES];
                            return; // Prevent opening the Your Videos menu
                        }
                    }
                }
            }
            if ([itemSectionSupportedRenderers hasCompactListItemRenderer]) {
                YTICompactListItemRenderer *compactListItemRenderer = itemSectionSupportedRenderers.compactListItemRenderer;
                if ([compactListItemRenderer hasThumbnail]) {
                    YTICompactListItemThumbnailSupportedRenderers *thumbnail = compactListItemRenderer.thumbnail;
                    if ([thumbnail hasIconThumbnailRenderer]) {
                        YTIIconThumbnailRenderer *iconThumbnailRenderer = thumbnail.iconThumbnailRenderer;
                        if ([iconThumbnailRenderer hasIcon]) {
                            YTIIcon *icon = iconThumbnailRenderer.icon;
                            if ([icon hasIconType] && icon.iconType == 658) {
                                yourVideosCellIndex = [subContentsArray indexOfObject:itemSectionSupportedRenderers];
                            }
                        }
                    }
                }
            }
        }
        if (yourVideosCellIndex != -1 && subContentsArray[yourVideosCellIndex].accessibilityLabel == nil) {
            YTIItemSectionSupportedRenderers *newItemSectionSupportedRenderers = [subContentsArray[yourVideosCellIndex] copy];
            ((YTIStringRun *)(newItemSectionSupportedRenderers.compactListItemRenderer.title.runsArray.firstObject)).text = @"Downloads";
            newItemSectionSupportedRenderers.compactListItemRenderer.thumbnail.iconThumbnailRenderer.icon.iconType = 147;
            [subContentsArray insertObject:newItemSectionSupportedRenderers atIndex:yourVideosCellIndex + 1];
            subContentsArray[yourVideosCellIndex].accessibilityLabel = @"uYouEnhanced Modified";
            yourVideosCellIndex = -1;
        }
    }
}
- (void)loadWithModel:(YTISectionListRenderer *)model {
    [self uYouEnhancedFakePremiumModel:model];
    %orig;
}
- (void)setupSectionListWithModel:(YTISectionListRenderer *)model isLoadingMore:(BOOL)isLoadingMore isRefreshingFromContinuation:(BOOL)isRefreshingFromContinuation {
    [self uYouEnhancedFakePremiumModel:model];
    %orig;
}
%end
%end

%group gHideYouTubeLogo
%hook YTHeaderLogoController
- (YTHeaderLogoController *)init {
    return NULL;
}
%end
%end

%group gStickNavigationBar
%hook YTHeaderView
- (BOOL)stickyNavHeaderEnabled { return YES; } 
%end
%end

%group gHideOverlayQuickActions
%hook YTFullscreenActionsView
- (id)initWithElementView:(id)arg1 {
    return NULL;
}
- (id)initWithElementRenderer:(id)arg1 parentResponder:(id)arg2 {
    return NULL;
}
- (BOOL)enabled {
    return NO;
}
%end
%end

%group gAlwaysShowPlayerBar
%hook YTPlayerBarController
- (void)setPlayerViewLayout:(int)arg1 {
    %orig(2);
} 
%end
%end

// Red Progress Bar - @dayanch96
%group gRedProgressBar
%hook YTSegmentableInlinePlayerBarView
- (void)setBufferedProgressBarColor:(id)arg1 {
     [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:0.50];
}
%end
%hook YTInlinePlayerBarContainerView
- (id)quietProgressBarColor {
    return [UIColor redColor];
}
%end
%end

// Gray Buffer Progress - @dayanch96 
%group gGrayBufferProgress
%hook YTSegmentableInlinePlayerBarView
- (void)setBufferedProgressBarColor:(id)arg1 {
     [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:0.90];
}
%end
%end

// Hide Collapse (Arrow - V) Button in Video Player - @arichornlover
%group gHideCollapseButton
%hook YTMainAppControlsOverlayView
- (BOOL)watchCollapseButtonHidden { return YES; }
- (void)setWatchCollapseButtonAvailable:(BOOL)available { %orig(available); }
%end
%end

// Hide Fullscreen Button in Video Player - @arichornlover
%group gHideFullscreenButton
%hook YTInlinePlayerBarContainerView
- (void)layoutSubviews {
    %orig;
        if (self.exitFullscreenButton) {
            [self.exitFullscreenButton removeFromSuperview];
            self.exitFullscreenButton.frame = CGRectZero;
        }
        if (self.enterFullscreenButton) {
            [self.enterFullscreenButton removeFromSuperview];
            self.enterFullscreenButton.frame = CGRectZero;
        }
        self.fullscreenButtonDisabled = YES;
}
%end
%end

%group gHidePlayerBarHeatwave
%hook YTPlayerBarHeatwaveView
- (id)initWithFrame:(CGRect)frame heatmap:(id)heat {
    return NULL;
}
%end
%hook YTPlayerBarController
- (void)setHeatmap:(id)arg1 {
    %orig(NULL);
}
%end
%end

%group gHidePictureInPictureAdsBadge
%hook YTPlayerPIPController
- (void)displayAdsBadge {
}
%end
%end

%group gHidePictureInPictureSponsorBadge
%hook YTPlayerPIPController
- (void)displaySponsorBadge {
}
%end
%end

%group gEnableCustomDoubleTapToSkipDuration
%hook YTSettings
- (NSInteger)doubleTapSeekDuration {
    if ([[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"];
    }
    return 10;
}
- (void)setDoubleTapSeekDuration:(NSInteger)arg1 {
    if ([[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"]) {
        arg1 = [[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"];
    } else {
        arg1 = 10;
    }
    %orig;
}
%end
%hook YTMainAppVideoPlayerOverlayView
- (NSInteger)doubleTapSeekDuration {
    if ([[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"];
    }
    return 10;
}
%end
%hook YTUserDefaults
- (NSInteger)doubleTapSeekDuration {
    if ([[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"];
    }
    return 10;
}
- (void)setDoubleTapSeekDuration:(NSInteger)arg1 {
    if ([[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"]) {
        arg1 = [[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"];
    } else {
        arg1 = 10;
    }
    %orig;
}
%end
%hook YTVideoPlayerOverlayConfigTransformer
+ (double)doubleTapSeekIntervalForVideoPlayerOverlayConfig:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"];
    }
    return 10;
}
+ (NSInteger)doubleTapSeekDurationForVideoPlayerOverlayConfig:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"]) {
        return [[NSUserDefaults standardUserDefaults] doubleForKey:@"kCustomDoubleTapToSkipDuration"];
    }
    return 10;
}
%end
%end

%group gHideCurrentTimeLabel
%hook YTInlinePlayerBarContainerView
- (void)layoutSubviews {
	%orig();
    self.currentTimeLabel.hidden = YES;
}
%end
%end

%group gHideDurationLabel
%hook YTInlinePlayerBarContainerView
- (void)layoutSubviews {
	%orig();
	self.durationLabel.hidden = YES;
}
%end
%end

BOOL selectedTabIndex = NO;

%hook YTPivotBarViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig();
    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"kStartupPageIntVTwo"]) {
        int selectedTab = [[NSUserDefaults standardUserDefaults] integerForKey:@"kStartupPageIntVTwo"];
        if (selectedTab == 0 && !selectedTabIndex) {
            [self selectItemWithPivotIdentifier:@"FEwhat_to_watch"];
            selectedTabIndex = YES;
        }
        if (selectedTab == 1 && !selectedTabIndex) {
            [self selectItemWithPivotIdentifier:@"FEexplore"];
            selectedTabIndex = YES;
        }
        if (selectedTab == 2 && !selectedTabIndex) {
            [self selectItemWithPivotIdentifier:@"FEshorts"];
            selectedTabIndex = YES;
        }
        if (selectedTab == 3 && !selectedTabIndex) {
            [self selectItemWithPivotIdentifier:@"FEsubscriptions"];
            selectedTabIndex = YES;
        }
        if (selectedTab == 4 && !selectedTabIndex) {
            [self selectItemWithPivotIdentifier:@"FElibrary"];
            selectedTabIndex = YES;
        }
    }
}
%end

%hook YTIPivotBarItemRender

- (void)viewDidLoad {
    %orig();
    NSArray *tabOrder = [[NSUserDefaults standardUserDefaults] objectForKey:@"kTabOrder"];
    
    NSDictionary *tabPositions = @{
        @"FEwhat_to_watch": @(0), // Home
        @"FEshorts": @(1), // Shorts
        @"FEuploads": @(2), // Create
        @"FEsubscriptions": @(3), // Subscriptions
        @"FElibrary": @(4) // You
    };
    NSArray *sortedTabOrder = [tabOrder sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSNumber *position1 = tabPositions[obj1];
        NSNumber *position2 = tabPositions[obj2];
        return [position1 compare:position2];
    }];
    NSMutableArray *reorderedTabs = [NSMutableArray array];
    for (NSString *tabIdentifier in sortedTabOrder) {
        for (id tabItem in self.tabItems) {
            if ([tabItem respondsToSelector:@selector(pivotIdentifier)]) {
                NSString *pivotIdentifier = [tabItem pivotIdentifier];
                if ([pivotIdentifier isEqualToString:tabIdentifier]) {
                    [reorderedTabs addObject:tabItem];
                    break;
                }
            }
        }
    }
    [self setTabItems:reorderedTabs];
}
%end

%hook YTColdConfig
- (BOOL)shouldUseAppThemeSetting {
    return YES;
}
%end

%ctor {
    @autoreleasepool {
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"kEnableNoVideoAds"] == nil) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kEnableNoVideoAds"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"kEnablePictureInPictureVTwo"] == nil) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kEnablePictureInPictureVTwo"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kEnableNoVideoAds"] == YES && [[NSUserDefaults standardUserDefaults] boolForKey:@"kRebornIHaveYouTubePremium"] == NO) {
            %init(gNoVideoAds);
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kEnableBackgroundPlayback"] == YES && [[NSUserDefaults standardUserDefaults] boolForKey:@"kRebornIHaveYouTubePremium"] == NO) {
            %init(gBackgroundPlayback);
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHidePlayNextInQueue"] == YES) %init(gHidePlayNextInQueue);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kNoCastButton"] == YES) %init(gNoCastButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kNoNotificationButton"] == YES) %init(gNoNotificationButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kAllowHDOnCellularData"] == YES) %init(gAllowHDOnCellularData);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableDoubleTapToSkip"] == YES) %init(gDisableDoubleTapToSkip);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableVideoEndscreenPopups"] == YES) %init(gDisableVideoEndscreenPopups);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableYouTubeKidsPopup"] == YES) %init(gDisableYouTubeKids);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kEnableExtraSpeedOptions"] == YES) %init(gExtraSpeedOptions);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableHints"] == YES) %init(gDisableHints);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kPremiumYouTubeLogo"] == YES) %init(gPremiumYouTubeLogo);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideYouTubeLogo"] == YES) %init(gHideYouTubeLogo);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kStickNavigationBar"] == YES) %init(gStickNavigationBar);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kLowContrastMode"] == YES) %init(gLowContrastMode);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kAutoHideHomeBar"] == YES) %init(gAutoHideHomeBar);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideTabBarLabels"] == YES) %init(gHideTabBarLabels);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideExploreTab"] == YES) %init(gHideExploreTab);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsTab"] == YES) %init(gHideShortsTab);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideUploadTab"] == YES) %init(gHideUploadTab);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideSubscriptionsTab"] == YES) %init(gHideSubscriptionsTab);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideYouTab"] == YES) %init(gHideYouTab);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideOverlayDarkBackground"] == YES) %init(gHideOverlayDarkBackground);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHidePreviousButtonInOverlay"] == YES) %init(gHidePreviousButtonInOverlay);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideNextButtonInOverlay"] == YES) %init(gHideNextButtonInOverlay);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableVideoAutoPlay"] == YES) %init(gDisableVideoAutoPlay);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideAutoPlaySwitchInOverlay"] == YES) %init(gHideAutoPlaySwitchInOverlay);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideCaptionsSubtitlesButtonInOverlay"] == YES) %init(gHideCaptionsSubtitlesButtonInOverlay);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableVideoInfoCards"] == YES) %init(gDisableVideoInfoCards);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kNoSearchButton"] == YES) %init(gNoSearchButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideChannelWatermark"] == YES) %init(gHideChannelWatermark);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsChannelAvatarButton"] == YES) %init(gHideShortsChannelAvatarButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsLikeButton"] == YES) %init(gHideShortsLikeButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsDislikeButton"] == YES) %init(gHideShortsDislikeButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsCommentsButton"] == YES) %init(gHideShortsCommentsButton);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsRemixButton"] == YES) %init(gHideShortsRemixButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsShareButton"] == YES) %init(gHideShortsShareButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsMoreActionsButton"] == YES) %init(gHideShortsMoreActionsButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsSearchButton"] == YES) %init(gHideShortsSearchButton);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsBuySuperThanks"] == YES) %init(gHideShortsBuySuperThanks);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideShortsSubscriptionsButton"] == YES) %init(gHideShortsSubscriptionsButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableResumeToShorts"] == YES) %init(gDisableResumeToShorts);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kAlwaysShowShortsPlayerBar"] == YES) %init(gAlwaysShowShortsPlayerBar);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideOverlayQuickActions"] == YES) %init(gHideOverlayQuickActions);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kAutoFullScreen"] == YES) %init(gAutoFullScreen);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableRelatedVideosInOverlay"] == YES) %init(gDisableRelatedVideosInOverlay);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kEnableiPadStyleOniPhone"] == YES) %init(gEnableiPadStyleOniPhone);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kEnableiPhoneStyleOniPad"] == YES) %init(gEnableiPhoneStyleOniPad);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kPortraitFullscreen"] == YES) %init(gPortraitFullscreen);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kRedProgressBar"] == YES) %init(gRedProgressBar);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kGrayBufferProgress"] == YES) %init(gGrayBufferProgress);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideCollapseButton"] == YES) %init(gHideCollapseButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideFullscreenButton"] == YES) %init(gHideFullscreenButton);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHidePlayerBarHeatwave"] == YES) %init(gHidePlayerBarHeatwave);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHidePictureInPictureAdsBadge"] == YES) %init(gHidePictureInPictureAdsBadge);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHidePictureInPictureSponsorBadge"] == YES) %init(gHidePictureInPictureSponsorBadge);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHidePreviousButtonShadowInOverlay"] == YES) %init(gHidePreviousButtonShadowInOverlay);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideNextButtonShadowInOverlay"] == YES) %init(gHideNextButtonShadowInOverlay);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideSeekBackwardButtonShadowInOverlay"] == YES) %init(gHideSeekBackwardButtonShadowInOverlay);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideSeekForwardButtonShadowInOverlay"] == YES) %init(gHideSeekForwardButtonShadowInOverlay);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHidePlayPauseButtonShadowInOverlay"] == YES) %init(gHidePlayPauseButtonShadowInOverlay);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kEnableCustomDoubleTapToSkipDuration"] == YES) %init(gEnableCustomDoubleTapToSkipDuration);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideCurrentTime"] == YES) %init(gHideCurrentTimeLabel);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kHideDuration"] == YES) %init(gHideDurationLabel);
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kDisableRelatedVideosInOverlay"] == YES & [[NSUserDefaults standardUserDefaults] boolForKey:@"kHideOverlayQuickActions"] == YES & [[NSUserDefaults standardUserDefaults] boolForKey:@"kAlwaysShowPlayerBarVTwo"] == YES) {
            %init(gAlwaysShowPlayerBar);
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"kEnableiPadStyleOniPhone"] == NO & hasDeviceNotch() == NO & [[NSUserDefaults standardUserDefaults] boolForKey:@"kShowStatusBarInOverlay"] == YES) {
            %init(gShowStatusBarInOverlay);
        }
        NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"kYTRebornColourOptionsVFour"];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:colorData error:nil];
        [unarchiver setRequiresSecureCoding:NO];
        NSString *hexString = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
        if (hexString != nil) {
            rebornHexColour = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
            %init(gColourOptions);
        }
        %init(_ungrouped);
    }
}
