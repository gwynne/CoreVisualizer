//
//  ECVIMachOLoadCommand.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIMachOLoadCommand.h"
#import "ECVIMachOEntryCommand.h"

@interface ECVIMachOLoadCommand ()
@property(nonatomic,readwrite,weak) ECVIMachOBinary *binary;
@end

@implementation ECVIMachOLoadCommand

- (instancetype)initWithCommandInFile:(ECVIMachOBinary *)binary fromCmdAt:(const struct load_command *)cmd
{
	switch (cmd->cmd) {
		case LC_THREAD:
		case LC_UNIXTHREAD:
		case LC_MAIN:
			return [[ECVIMachOEntryCommand alloc] initWithCommandInFile:binary fromCmdAt:cmd];
		default:
			return [self initWithBinary:binary type:cmd->cmd size:cmd->cmdsize cmd:cmd];
	}
	return nil;
}

- (instancetype)initWithBinary:(ECVIMachOBinary *)binary type:(uint32_t)type size:(uint64_t)size cmd:(const struct load_command *)cmd
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
