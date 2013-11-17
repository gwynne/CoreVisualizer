//
//  ECVIMachOLoadCommand.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIMachOLoadCommand.h"
#import "ECVIMachOEntryCommand.h"
#import "ECVIMachOSegmentCommand.h"

@interface ECVIMachOLoadCommand ()
@property(nonatomic,readwrite,weak) ECVIMachOBinary *binary;
@end

@implementation ECVIMachOLoadCommand

- (instancetype)initWithCommandInFile:(ECVIMachOBinary *)binary fromCmdAt:(const struct load_command *)cmd error:(NSError * __autoreleasing *)error
{
	switch (cmd->cmd) {
		case LC_SEGMENT:
		case LC_SEGMENT_64:
			return [[ECVIMachOSegmentCommand alloc] initWithCommandInFile:binary fromCmdAt:cmd error:error];
		case LC_THREAD:
		case LC_UNIXTHREAD:
		case LC_MAIN:
			return [[ECVIMachOEntryCommand alloc] initWithCommandInFile:binary fromCmdAt:cmd error:error];
		default:
			return [self initWithBinary:binary type:cmd->cmd size:cmd->cmdsize cmd:cmd error:error];
	}
	return nil;
}

- (instancetype)initWithBinary:(ECVIMachOBinary *)binary type:(uint32_t)type size:(uint64_t)size cmd:(const struct load_command *)cmd error:(NSError * __autoreleasing *)error
{
	if ((self = [super init])) {
		_binary = binary;
		_type = type;
		_size = size;
		_baseCommand = cmd;
	}
	return self;
}

- (void)awakeFromBinary
{
}

@end
