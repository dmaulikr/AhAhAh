//
//  AhAhAhPrefs.m
//  Preferences for Ah!Ah!Ah!
//
//  Main controller.
//
//  Copyright (c) 2014-2016 Sticktron. All rights reserved.
//
//

#import "../Common.h"
#import "Prefs.h"
#import <Social/Social.h>


@interface AhAhAhPrefsController : PSListController
@end


@implementation AhAhAhPrefsController

- (id)specifiers {
	if (_specifiers == nil) {
		_specifiers = [self loadSpecifiersFromPlistName:@"AhAhAhPrefs" target:self];

		// disable Touch ID settings for devices without Touch ID
		if (hasTouchID() == NO) {
			PSSpecifier *specifier = [self specifierForID:@"IgnoreBioFailure"];
			[specifier setProperty:@NO forKey:@"enabled"];
			[specifier setProperty:@NO forKey:@"default"];
		}
	}
	return _specifiers;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	// add the Show Love button to the navbar
	NSString *path = [BUNDLE_PATH stringByAppendingPathComponent:@"Heart.png"];
	UIImage *heartImage = [[UIImage alloc] initWithContentsOfFile:path];
	UIBarButtonItem *heartButton = [[UIBarButtonItem alloc] initWithImage:heartImage
																	style:UIBarButtonItemStylePlain
																   target:self
																   action:@selector(showLove)];
	heartButton.imageInsets = (UIEdgeInsets){2, 0, -2, 0};
	heartButton.tintColor = TINT_COLOR;
	[self.navigationItem setRightBarButtonItem:heartButton];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	// make the Theme link cell update it's label
	//[self reloadSpecifierID:@"Theme" animated:NO]; // this causes the header cell to mis-render!?
	[self reloadSpecifiers];

	// tint navbar
	if (IS_IOS_OR_NEWER(iOS_8_0)) {
		self.navigationController.navigationController.navigationBar.tintColor = TINT_COLOR;
	} else {
		self.navigationController.navigationBar.tintColor = TINT_COLOR;
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	// un-tint navbar
	if (IS_IOS_OR_NEWER(iOS_8_0)) {
		self.navigationController.navigationController.navigationBar.tintColor = nil;
	} else {
		self.navigationController.navigationBar.tintColor = nil;
	}

	[super viewWillDisappear:animated];
}

- (void)setTitle:(id)title {
	// no thanks
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:PREFS_PLIST_PATH];

	if (!settings[specifier.properties[@"key"]]) {
		return specifier.properties[@"default"];
	}
	return settings[specifier.properties[@"key"]];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	[settings addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:PREFS_PLIST_PATH]];
	[settings setObject:value forKey:specifier.properties[@"key"]];
	[settings writeToFile:PREFS_PLIST_PATH atomically:YES];

	CFStringRef notificationValue = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
	if (notificationValue) {
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationValue, NULL, NULL, YES);
	}
}

//

- (void)showLove {
	// send a nice tweet ;)
	SLComposeViewController *composeController = [SLComposeViewController
												  composeViewControllerForServiceType:SLServiceTypeTwitter];

	[composeController setInitialText:@"I'm using Ah!Ah!Ah! by @Sticktron to scare away nosey people."];

	[self presentViewController:composeController
					   animated:YES
					 completion:nil];
}

- (void)openEmail {
	NSString *subject = @"Support for Ah!Ah!Ah! 2";
	NSString *body = @"(Please type something here.)";
	NSString *urlString = [NSString stringWithFormat:@"mailto:sticktron@hotmail.com?subject=%@&body=%@", subject, body];
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
}

- (void)openTwitter {
	NSURL *url;

	if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot:"]]) {
		url = [NSURL URLWithString:@"tweetbot:///user_profile/sticktron"];

	} else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitterrific:"]]) {
		url = [NSURL URLWithString:@"twitterrific:///profile?screen_name=sticktron"];

	} else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetings:"]]) {
		url = [NSURL URLWithString:@"tweetings:///user?screen_name=sticktron"];

	} else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter:"]]) {
		url = [NSURL URLWithString:@"twitter://user?screen_name=sticktron"];

	} else {
		url = [NSURL URLWithString:@"http://twitter.com/sticktron"];
	}

	[[UIApplication sharedApplication] openURL:url];
}

- (void)openGitHub {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://github.com/Sticktron/AhAhAh/"]];
}

- (void)openReddit {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://reddit.com/r/jailbreak/"]];
}

- (void)openPayPal {
	NSString *url = @"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=BKGYMJNGXM424&lc=CA&item_name=Donation%20to%20Sticktron&item_number=AhAhAh2&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donate_SM%2egif%3aNonHosted";
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

@end
