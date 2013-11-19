//
//  ECVIAppDelegate.m
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIAppDelegate.h"
#import "ECVIBinaryWindowController.h"

@interface ECVIAppDelegate () <NSApplicationDelegate>

@property(nonatomic,weak) IBOutlet NSWindow *window;

@end

@implementation ECVIAppDelegate
{
	NSMutableArray *_controllers;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	_controllers = @[].mutableCopy;
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
		ECVIBinaryWindowController *controller = [[ECVIBinaryWindowController alloc] initWithURL:panel.URL];
		
		[controller showWindow:self];
		[_controllers addObject:controller];
	}
}

@end
