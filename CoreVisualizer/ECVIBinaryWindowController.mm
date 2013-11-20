//
//  ECVIBinaryWindowController.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/19/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIBinaryWindowController.h"
#import "ECVIInstance.h"

@interface ECVIBinaryWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, ECVIInstanceDelegate>

@property(nonatomic,strong) IBOutlet NSTextField *URLLabel;
@property(nonatomic,strong) IBOutlet NSTextField *URLField;
@property(nonatomic,strong) IBOutlet NSTextField *coreLabel;
@property(nonatomic,strong) IBOutlet NSTextField *coreField;
@property(nonatomic,strong) IBOutlet NSTableView *listTable;
@property(nonatomic,strong) IBOutlet NSButton *resetButton;
@property(nonatomic,strong) IBOutlet NSButton *stepButton;
- (IBAction)resetAction:(id)sender;
- (IBAction)stepAction:(id)sender;

@property(nonatomic,strong) NSURL *originalURL;
@property(nonatomic,strong) ECVIInstance *instance;

@end

@implementation ECVIBinaryWindowController

- (instancetype)initWithURL:(NSURL *)url
{
	if ((self = [super initWithWindowNibName:NSStringFromClass(self.class)])) {
		NSError *error = nil;
		
		_originalURL = url;
		_instance = [[ECVIInstance alloc] init];
		_instance.delegate = self;
		if (![_instance loadBinary:url error:&error]) {
			[NSApp presentError:error];
			return nil;
		}
	}
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	_URLField.stringValue = _originalURL.absoluteString;
	_coreField.stringValue = @"Apple arm64 A7 Core";
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return _instance.core.numRegisters;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSTableCellView *view = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
	NSString *rnam = [_instance.core nameForRegister:row];
	uint64_t rsiz = [_instance.core sizeOfRegister:row];
	uint128_t rval = [_instance.core valueForRegister:row];
	
	if ([tableColumn.identifier isEqualToString:@"name"]) {
		view.textField.stringValue = rnam;
	} else if ([tableColumn.identifier isEqualToString:@"value"]) {
		if (rsiz > 8) {
			view.textField.stringValue = [NSString stringWithFormat:@"0x%016llx%016llx", (uint64_t)(rval >> 64), (uint64_t)(rval & (uint128_t)UINT64_MAX)];
		} else {
			view.textField.stringValue = [NSString stringWithFormat:@"0x%0*llx", (int)rsiz << 1, (uint64_t)rval];
		}
	}
	return view;
}

- (void)CPUcore:(ECVIGenericCPUCore *)core didUpdateRegister:(uint32_t)rnum toValue:(uint128_t)value
{
	[_listTable reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:rnum] columnIndexes:[NSIndexSet indexSetWithIndex:1]];
}

- (void)resetAction:(id)sender
{
	[_instance reset];
	[_listTable reloadData];
}

- (void)stepAction:(id)sender
{
	[_instance stepOne];
}

@end
