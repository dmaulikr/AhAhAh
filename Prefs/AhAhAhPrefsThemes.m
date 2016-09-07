//
//  AhAhAhPrefsTheme.m
//  Preferences for Ah!Ah!Ah!
//
//  Copyright (c) 2014-2016 Sticktron. All rights reserved.
//
//

#import "Common.h"

#import <Preferences/PSViewController.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>


#define THEMES_PATH				@"/Library/AhAhAh/Themes"
#define USER_VIDEOS_PATH		[NSHomeDirectory() stringByAppendingPathComponent:@"Library/AhAhAh/Videos"]
#define USER_BACKGROUNDS_PATH	[NSHomeDirectory() stringByAppendingPathComponent:@"Library/AhAhAh/Backgrounds"]

typedef NS_ENUM(NSInteger, AhAhAhSection) {
    kAhAhAhThemeSection,
    kAhAhAhVideoSection,
    kAhAhAhBackgroundSection
};

typedef NS_ENUM(NSInteger, AhAhAhTag) {
    kAhAhAhThumbnailTag = 1,
    kAhAhAhTitleTag 	= 2,
    kAhAhAhSubtitleTag 	= 3
};

static NSString *const kAhAhAhFileKey = @"file";
static NSString *const kAhAhAhSizeKey = @"size";

#define ID_NONE			@"_none"
#define ID_DEFAULT		@"_default"
#define ID_KEVIN		@"_kevin"
#define ID_DEX			@"_dex"

 
/* UIImage Helpers */

@implementation UIImage (AhAhAh)
+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)size {
	BOOL opaque = YES;
	
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
		// In next line, pass 0.0 to use the current device's pixel scaling factor
		// (and thus account for Retina resolution).
		// Pass 1.0 to force exact pixel size.
        //UIGraphicsBeginImageContextWithOptions(size, opaque, [[UIScreen mainScreen] scale]);
        UIGraphicsBeginImageContextWithOptions(size, opaque, 0.0f);
    } else {
        UIGraphicsBeginImageContext(size);
    }
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	
    return newImage;
}
+ (UIImage *)imageWithImage:(UIImage *)image scaledToMaxWidth:(CGFloat)width maxHeight:(CGFloat)height {
    CGFloat oldWidth = image.size.width;
    CGFloat oldHeight = image.size.height;
	
    CGFloat scaleFactor = (oldWidth > oldHeight) ? width / oldWidth : height / oldHeight;
	
    CGFloat newHeight = oldHeight * scaleFactor;
    CGFloat newWidth = oldWidth * scaleFactor;
    CGSize newSize = CGSizeMake(newWidth, newHeight);
	
    return [self imageWithImage:image scaledToSize:newSize];
}
- (UIImage *)normalizedImage {
	if (self.imageOrientation == UIImageOrientationUp) {
		return self;
	} else {
		UIGraphicsBeginImageContextWithOptions(self.size, NO, self.scale);
		[self drawInRect:(CGRect){{0, 0}, self.size}];
		UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		
		return normalizedImage;
	}
}
- (NSString *)orientation {
	NSString *result;
	
	switch (self.imageOrientation) {
		case UIImageOrientationUp:
			result = @"UIImageOrientationUp";
			break;
		case UIImageOrientationDown:
			result = @"UIImageOrientationDown";
			break;
		case UIImageOrientationLeft:
			result = @"UIImageOrientationLeft";
			break;
		case UIImageOrientationRight:
			result = @"UIImageOrientationRight";
			break;
		case UIImageOrientationUpMirrored:
			result = @"UIImageOrientationUpMirrored";
			break;
		case UIImageOrientationDownMirrored:
			result = @"UIImageOrientationDownMirrored";
			break;
		case UIImageOrientationLeftMirrored:
			result = @"UIImageOrientationLeftMirrored";
			break;
		case UIImageOrientationRightMirrored:
			result = @"UIImageOrientationRightMirrored";
			break;
		default:
			result = @"Error";
	}
	
	return result;
}
@end


/* Theme Controller */

@interface AhAhAhPrefsThemeController : PSViewController <UITableViewDataSource, UITableViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *themes;
@property (nonatomic, strong) NSMutableArray *videos;
@property (nonatomic, strong) NSMutableArray *backgrounds;
@property (nonatomic, strong) NSString *selectedTheme;
@property (nonatomic, strong) NSString *selectedVideo;
@property (nonatomic, strong) NSString *selectedBackground;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSCache *imageCache;
@property (nonatomic, strong) UIPopoverController *popover;
- (void)scanForMedia;
- (UIImage *)thumbnailForVideo:(NSString *)filename withMaxSize:(CGSize)size;
- (void)savePrefs:(BOOL)notificate;
- (BOOL)startPicker;
@end


@implementation AhAhAhPrefsThemeController

- (instancetype)init {
	self = [super init];
	
	if (self) {
		[self setTitle:@"Customize"];
		
		_queue = [[NSOperationQueue alloc] init];
		_queue.maxConcurrentOperationCount = 4;
		_imageCache = [[NSCache alloc] init];
		
		_themes =
		_backgrounds = nil;
		_videos = nil;
		
		// load user prefs...
		
		NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREFS_PLIST_PATH];
		DebugLog(@"Read user prefs: %@", prefs);
		_selectedVideo = prefs[@"VideoFile"] ?: nil;
		_selectedBackground = prefs[@"BackgroundFile"] ?: nil;
				
		// create directories for user media (if needed)...
		
		[[NSFileManager defaultManager] createDirectoryAtPath:USER_BACKGROUNDS_PATH
								  withIntermediateDirectories:YES
												   attributes:nil
														error:nil];
		
		[[NSFileManager defaultManager] createDirectoryAtPath:USER_VIDEOS_PATH
								  withIntermediateDirectories:YES
												   attributes:nil
														error:nil];
	}
	return self;
}

- (void)loadView {
	DebugLog(@"loadView");

	self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	self.tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]
												  style:UITableViewStyleGrouped];
	self.tableView.delegate = self;
	self.tableView.dataSource = self;
	self.tableView.rowHeight = 44.0f;
	self.tableView.tintColor = TINT_COLOR;
	
	self.view = self.tableView;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];	
	[self scanForMedia];
}

- (void)didReceiveMemoryWarning {
	DebugLog(@"emptying image cache");
	[self.imageCache removeAllObjects];
	[super didReceiveMemoryWarning];
}

- (void)viewWillDisappear:(BOOL)animated {
	DebugLog(@"emptying image cache");
	[self.imageCache removeAllObjects];
	[super viewWillDisappear:animated];
}

// tableview data

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	NSString *title = nil;
	
	switch (section) {
		case kAhAhAhThemeSection: title = @"Themes";
		break;
		
		case kAhAhAhVideoSection: title = @"Your Videos";
		break;
		
		case kAhAhAhBackgroundSection: title = @"Your Backgrounds";
		break;
	}
	
	return title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger num = 0;
	
	switch (section) {
		case kAhAhAhThemeSection: num = self.themes.count;
			break;
		case kAhAhAhVideoSection: num = self.videos.count + 1; // add extra row for Import Cell
			break;
		case kAhAhAhBackgroundSection: num = self.backgrounds.count + 1; // add extra row for Import Cell
			break;
	}
	
	return num;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell;
	
	// for the last row in the Video and Background sections,
	// make Import cells...
		
	if ([self isPathToLastRowInSection:indexPath]) {
		if (indexPath.section == kAhAhAhVideoSection || indexPath.section == kAhAhAhBackgroundSection) {			
			cell = [self createImportCell];
			return cell;
		}
	}
			
	// for the rest,
	// make Media Item cells...
	
	cell = [self createMediaItemCell];	
	[self customizeMediaItemCell:cell atIndexPath:indexPath];
		
	return cell;		
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == kAhAhAhThemeSection) {
		return @"Themes can be found in Cydia, or copied to /Library/AhAhAh/Themes.";
	} else {
		return nil;
	}
}

// tableview selecting & deleting

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	DebugLog(@"User selected row: %ld, section: %ld", (long)indexPath.row, (long)indexPath.section);
	
	if (indexPath.row == [self.tableView numberOfRowsInSection:indexPath.section]) {		
		if (indexPath.section == kAhAhAhVideoSection || indexPath.section == kAhAhAhBackgroundSection) {
			[self startPicker];
		}
			
	} else {
		UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
		
		if (cell.accessoryType == UITableViewCellAccessoryCheckmark) {
			
			// uncheck cell...
			
			cell.accessoryType = UITableViewCellAccessoryNone;
			
			if (indexPath.section == kAhAhAhVideoSection) {
				self.selectedVideo = ID_NONE;
			} else {
				self.selectedBackground = ID_NONE;
			}
			
		} else {
			
			// check cell...
			
			// uncheck old selection
			for (NSInteger i = 0; i < [tableView numberOfRowsInSection:indexPath.section]; i++) {
				NSIndexPath	 *path = [NSIndexPath indexPathForRow:i inSection:indexPath.section];
				UITableViewCell *cell = [tableView cellForRowAtIndexPath:path];
				cell.accessoryType = UITableViewCellAccessoryNone;
			}
			
			// check new selection
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
			
			// get the file name
			UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:kAhAhAhTitleTag];
			
			// save selection
			if (indexPath.section == kAhAhAhVideoSection) {
				if (indexPath.row == 0) {
					self.selectedVideo = ID_DEFAULT;
				} else if (indexPath.row == 1) {
					self.selectedVideo = ID_KEVIN;
				} else if (indexPath.row == 2) {
					self.selectedVideo = ID_DEX;
				} else {
					self.selectedVideo = titleLabel.text;
				}
				DebugLog(@"selected video: %@", self.selectedVideo);
				
			} else if (indexPath.section == kAhAhAhBackgroundSection) {
				if (indexPath.row == 0) {
					self.selectedBackground = ID_DEFAULT;
				} else {
					self.selectedBackground = titleLabel.text;
				}
				DebugLog(@" selected background: %@", self.selectedBackground);
			}
		}
			
		[self savePrefs:YES];
		[tableView reloadData];
	}
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row <= 2) {
		return NO;
	} else {
		return YES;
	}
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	DebugLog(@"User wants to delete media");
	
    if (editingStyle == UITableViewCellEditingStyleDelete) {
		
		if (indexPath.section == kAhAhAhVideoSection) {
			//
			// delete video
			//
			NSString *file = self.videos[indexPath.row][kAhAhAhFileKey];
			NSString *path = [NSString stringWithFormat:@"%@/%@", USER_VIDEOS_PATH, file];
			DebugLog(@"deleting video at path: %@", path);
			[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
			
			// if row was checked, check the default row instead
			if ([file isEqualToString:self.selectedVideo]) {
				self.selectedVideo = ID_DEFAULT;
			}
			
			[self.videos removeObjectAtIndex:indexPath.row];
			
		} else if (indexPath.section == kAhAhAhBackgroundSection) {
			//
			// delete image
			//
			NSString *file = self.backgrounds[indexPath.row][kAhAhAhFileKey];
			NSString *path = [NSString stringWithFormat:@"%@/%@", USER_BACKGROUNDS_PATH, file];
			DebugLog(@"deleting image at path: %@", path);
			[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
			
			// if image was selected, select default after deletion
			if ([file isEqualToString:self.selectedBackground]) {
				self.selectedBackground = ID_DEFAULT;
			}
			
			[self.backgrounds removeObjectAtIndex:indexPath.row];
		}
		
		[self savePrefs:YES];
		
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
		[tableView reloadData];
    }
}

// helpers

- (UITableViewCell *)createImportCell {
	static NSString *ImportCellIdentifier = @"ImportCell";	
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:ImportCellIdentifier];	
	
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:ImportCellIdentifier];
		cell.opaque = YES;
		cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
		cell.selectionStyle = UITableViewCellSelectionStyleDefault;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.textLabel.text = @"➕ Import From Camera Roll";
	}
	
	return cell;
}

- (UITableViewCell *)createMediaItemCell {
	static NSString *CustomCellIdentifier = @"MediaItemCell";
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CustomCellIdentifier];
	
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
		   		  					   reuseIdentifier:CustomCellIdentifier];
		cell.opaque = YES;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.accessoryType = UITableViewCellAccessoryNone;
		
		// thumbnail
		UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(15.0f, 2.0f, 40.0f, 40.0f)];
		imageView.opaque = YES;
		imageView.contentMode = UIViewContentModeScaleAspectFit;
		imageView.tag = kAhAhAhThumbnailTag;
		[cell.contentView addSubview:imageView];
		
		// title
		UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(70.0f, 10.0f, 215.0f, 16.0f)];
		titleLabel.opaque = YES;
		titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
		titleLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
		titleLabel.tag = kAhAhAhTitleTag;
		[cell.contentView addSubview:titleLabel];
		
		// subtitle
		UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(70.0f, 28.0f, 215.0f, 12.0f)];
		subtitleLabel.opaque = YES;
		subtitleLabel.font = [UIFont italicSystemFontOfSize:10.0];
		subtitleLabel.textColor = [UIColor grayColor];
		subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
		subtitleLabel.tag = kAhAhAhSubtitleTag;
		[cell.contentView addSubview:subtitleLabel];
	}
	
	return cell;
}

- (void)customizeMediaItemCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
	
	UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:kAhAhAhThumbnailTag];
	UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:kAhAhAhTitleTag];
	UILabel *subtitleLabel = (UILabel *)[cell.contentView viewWithTag:kAhAhAhSubtitleTag];
	
	// a Video cell...
	
	if (indexPath.section == kAhAhAhVideoSection) {
		
		NSDictionary *video = self.videos[indexPath.row];		
		NSString *filename = video[kAhAhAhFileKey];
		titleLabel.text = filename;
		subtitleLabel.text = video[kAhAhAhSizeKey];
		
		// get thumbnail from cache, or else load and cache it in the background
		UIImage *thumbnail = [self.imageCache objectForKey:filename];
		if (thumbnail) {
			imageView.image = thumbnail;			
		} else {
			[self.queue addOperationWithBlock:^{
				UIImage *image = [self thumbnailForVideo:filename withMaxSize:imageView.bounds.size];				
				if (image) {
					[self.imageCache setObject:image forKey:filename];
					
					// update UI on the main thread
					[[NSOperationQueue mainQueue] addOperationWithBlock:^{
						UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];						
						if (cell) {
							UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:kAhAhAhThumbnailTag];
							imageView.image = image;
						}
					}];
				}
			}];
		}
		
		if ([self.selectedVideo isEqualToString:video[kAhAhAhFileKey]]) {
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		} else {
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		
		
	// a Background cell...

	} else if (indexPath.section == kAhAhAhBackgroundSection) {
		
		NSDictionary *background = self.backgrounds[indexPath.row];		
		NSString *filename = background[kAhAhAhFileKey];
		titleLabel.text = filename;
		subtitleLabel.text = background[kAhAhAhSizeKey];
		
		// get thumbnail from cache, or else load and cache it in the background...		
		UIImage *thumbnail = [self.imageCache objectForKey:filename];
		if (thumbnail) {
			imageView.image = thumbnail;			
		} else {
			[self.queue addOperationWithBlock:^{
				NSString *path = [NSString stringWithFormat:@"%@/%@", USER_BACKGROUNDS_PATH, filename];
				UIImage *image = [UIImage imageWithContentsOfFile:path];				
				if (image) {
					image = [UIImage imageWithImage:image scaledToMaxWidth:imageView.bounds.size.height
										  maxHeight:imageView.bounds.size.height];
					[self.imageCache setObject:image forKey:filename];
					
					// update UI on main thread
					[[NSOperationQueue mainQueue] addOperationWithBlock:^{
						UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
						
						if (cell) {
							UIImageView *imageView = (UIImageView *)[cell.contentView viewWithTag:kAhAhAhThumbnailTag];
							imageView.image = image;
						}
					}];
				}
			}];
		}
		
		if ([self.selectedBackground isEqualToString:background[kAhAhAhFileKey]]) {
			cell.accessoryType = UITableViewCellAccessoryCheckmark;
		} else {
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		
		
	// a Theme cell...
	
	} else if (indexPath.section == kAhAhAhThemeSection) {
		titleLabel.text = @"Theme";
		subtitleLabel.text = @"Author";
	}
}

- (BOOL)isPathToLastRowInSection:(NSIndexPath *)indexPath {
	if (indexPath.row == [self.tableView numberOfRowsInSection:indexPath.section] - 1) {		
		return YES;
	}
	return NO;
}

- (void)scanForMedia {
	DebugLog0;
	
	// look for Themes...
	
	self.themes = nil;
	
	
	// look for Imported Assets...
	
	self.videos = [self loadMediaAtPath:USER_VIDEOS_PATH];
	DebugLog(@"self.videos = %@", self.videos);
	
	self.backgrounds = [self loadMediaAtPath:USER_BACKGROUNDS_PATH];
	DebugLog(@"self.backgrounds = %@", self.backgrounds);
}

- (NSMutableArray *)loadMediaAtPath:(NSString *)path {
	NSArray *keys = @[ NSURLContentModificationDateKey, NSURLFileSizeKey, NSURLNameKey ];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSURL *url = [NSURL fileURLWithPath:path isDirectory:YES];
	
	NSMutableArray *files = (NSMutableArray *)[fm contentsOfDirectoryAtURL:url
									includingPropertiesForKeys:keys
													   options:NSDirectoryEnumerationSkipsHiddenFiles
														 error:nil];
	DebugLog(@"Contents of (%@): %@", url, files);
	
	if (!files) {
		DebugLog(@"No files.");
		return nil;
	}
	
	// sort files by creation date, newest first
	[files sortUsingComparator:^(NSURL *a, NSURL *b) {
		NSDate *date1 = [[a resourceValuesForKeys:keys error:nil] objectForKey:NSURLContentModificationDateKey];
		NSDate *date2 = [[b resourceValuesForKeys:keys error:nil] objectForKey:NSURLContentModificationDateKey];
		return [date2 compare:date1];
	}];
	
	NSMutableArray *media = [NSMutableArray array];
	
	// add files to array
	for (NSURL *fileURL in files) {
		NSString *file = [fileURL resourceValuesForKeys:keys error:nil][NSURLNameKey];
		NSString *size = [fileURL resourceValuesForKeys:keys error:nil][NSURLFileSizeKey];
		
		if ([size floatValue] < 1024*1024) {
			size = [NSString stringWithFormat:@"%.0f KB", [size floatValue] / 1024.0f];
		} else {
			size = [NSString stringWithFormat:@"%.1f MB", [size floatValue] / 1024.0f / 1024.f];
		}
		
		[media addObject:@{ kAhAhAhFileKey: file, kAhAhAhSizeKey: size }];
	}
	DebugLog(@"Results: %@", media);
	return media;
}

- (UIImage *)thumbnailForVideo:(NSString *)filename withMaxSize:(CGSize)size {
	UIImage *thumbnail = nil;
	
	NSString *path = [NSString stringWithFormat:@"%@/%@", USER_VIDEOS_PATH, filename];
	NSURL *url = [NSURL fileURLWithPath:path];
	DebugLog(@"Requested thumbnail for file at url: %@", url);
	
	AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
	DebugLog(@"found asset (%@)", asset);
	
	if (asset) {
		AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
		generator.appliesPreferredTrackTransform = YES;
		
		CMTime time = CMTimeMake(1, 1);
		CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:NULL error:NULL];
		
		UIImage *image = [UIImage imageWithCGImage:imageRef];
		DebugLog(@"got thumbnail image (size=%@)", NSStringFromCGSize(image.size));
		
		thumbnail = [UIImage imageWithImage:image scaledToMaxWidth:size.width maxHeight:size.height];
		DebugLog(@"scaled thumbnail to size: %@", NSStringFromCGSize(thumbnail.size));
		
		CFRelease(imageRef);
	}
	
	return thumbnail;
}

- (void)savePrefs:(BOOL)notificate {
	NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PREFS_PLIST_PATH];
	
	if (!prefs) {
		prefs = [NSMutableDictionary dictionary];
	}
	
	// new settings
	prefs[@"VideoFile"] = self.selectedVideo;
	prefs[@"BackgroundFile"] = self.selectedBackground;
	
	DebugLog(@"##### Writing Preferences: %@", prefs);
	[prefs writeToFile:PREFS_PLIST_PATH atomically:YES];
	
	// apply settings to tweak
	if (notificate) {
		DebugLog(@"notified tweak");
		
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
											 CFSTR("com.sticktron.ahahah.prefschanged"),
											 NULL,
											 NULL,
											 true);
	}
}

// image picker

- (BOOL)startPicker {
	DebugLog0;
	
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary] == NO) {
		return NO;
	}
	
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.modalPresentationStyle = UIModalPresentationCurrentContext;
	picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	picker.mediaTypes = @[ (NSString *)kUTTypeMovie, (NSString *)kUTTypeImage ];	
	picker.allowsEditing = YES;	
	picker.navigationBar.barStyle = UIBarStyleDefault;
	picker.delegate = self;
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		[self presentViewController:picker animated:YES completion:NULL];
		
	} else {
		self.popover = [[UIPopoverController alloc] initWithContentViewController:picker];
		[self.popover presentPopoverFromRect:CGRectZero inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	}
	
	return YES;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	/*
		< Info Object Format >
	 
		image: {
			UIImagePickerControllerMediaType = "public.image";
			UIImagePickerControllerOriginalImage = <UIImage>;
			UIImagePickerControllerReferenceURL = "assets-library://asset/asset.PNG?id={GUID}&ext=PNG";
		}

		movie: {
			UIImagePickerControllerMediaType = "public.movie";
			UIImagePickerControllerMediaURL = "file:///var/tmp/trim.{GUID}.MOV";
			UIImagePickerControllerReferenceURL = "assets-library://asset/asset.mp4?id={GUID}&ext=mp4";
		}
	*/
	DebugLog(@"picker returned with this: %@", info);
	
	
	// callback
	ALAssetsLibraryAssetForURLResultBlock resultHandler = ^(ALAsset *asset) {
		NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
		
		if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) {
			
			// handle image ...
			
			ALAssetRepresentation *imageRep = [asset defaultRepresentation];
			DebugLog(@"Picked image asset with representation: %@", imageRep);
			
			NSString *filename = [imageRep filename];
			NSString *path = [NSString stringWithFormat:@"%@/%@", USER_BACKGROUNDS_PATH, filename];
			
			UIImage *image = (UIImage *)info[UIImagePickerControllerOriginalImage];
			DebugLog(@"image size=%@", NSStringFromCGSize(image.size));
			
			DebugLog(@"image orientation=%@", [image orientation]);
			image = [image normalizedImage];
			DebugLog(@"normalized image orientation: %@", [image orientation]);
			
			NSData *imageData = UIImagePNGRepresentation(image);
			[imageData writeToFile:path atomically:YES];
			
			// auto-select as new background
			self.selectedBackground = filename;
			
		} else if ([mediaType isEqualToString:(NSString *)kUTTypeMovie]) {
			
			// handle video ...
			
			ALAssetRepresentation *videoRep = [asset defaultRepresentation];
			DebugLog(@"Picked video asset with representation: %@", videoRep);
			
			NSString *filename = [videoRep filename];
			
			// save to disk
			NSString *path = [NSString stringWithFormat:@"%@/%@", USER_VIDEOS_PATH, filename];
			NSURL *videoURL = info[UIImagePickerControllerMediaURL];
			NSData *videoData = [NSData dataWithContentsOfURL:videoURL];
			[videoData writeToFile:path atomically:YES];
			
			// auto-select new video
			self.selectedVideo = filename;
		}
		
		[self savePrefs:YES];
		[self scanForMedia];
		[self.tableView reloadData];
		
		
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
			[picker dismissViewControllerAnimated:YES completion:NULL];
		} else {
			[self.popover dismissPopoverAnimated:YES];
		}
	};
	
	
	// fetch the asset from the library
	NSURL *assetURL = [info valueForKey:UIImagePickerControllerReferenceURL];
	ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
	[library assetForURL:assetURL resultBlock:resultHandler failureBlock:nil];
}

- (void)imagePickerControllerDidCancel: (UIImagePickerController *)picker {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
		[picker dismissViewControllerAnimated:YES completion:NULL];
	} else {
		[self.popover dismissPopoverAnimated:YES];
	}
}

@end

