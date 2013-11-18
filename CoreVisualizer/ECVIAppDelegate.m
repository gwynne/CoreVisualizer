//
//  ECVIAppDelegate.m
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIAppDelegate.h"
#import "ECVIInstance.h"

@interface ECVIAppDelegate () <NSApplicationDelegate>

@property(nonatomic,weak) IBOutlet NSWindow *window;

@end

@implementation ECVIAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}

- (IBAction)openDocument:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	panel.resolvesAliases = YES;
	panel.canChooseDirectories = NO;
	panel.allowsMultipleSelection = NO;
	panel.canChooseFiles = YES;
	panel.directoryURL = nil;
	panel.allowedFileTypes = nil;
	panel.canCreateDirectories = NO;
	panel.treatsFilePackagesAsDirectories = YES;
	panel.showsHiddenFiles = NO;
	if ([panel runModal] == NSFileHandlingPanelOKButton) {
		ECVIInstance *instance = [[ECVIInstance alloc] init];
		NSError *error = nil;
		
		[instance reset];
		if (![instance loadBinary:panel.URL error:&error]) {
			NSLog(@"Error %@", error);
		} else {
			NSLog(@"%@", instance);
			[instance stepOne];
			NSLog(@"%@", instance);
		}
	}
}

@end
