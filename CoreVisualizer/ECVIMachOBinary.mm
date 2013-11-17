//
//  ECVIMachOBinary.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIMachOBinary.h"
#import "ECVIMachOLoadCommand.h"
#import "ECVIMachOEntryCommand.h"
#import "ECVIMachOSegmentCommand.h"

@implementation ECVIMachOBinary
{
	NSData *_fileData;
}

- (instancetype)initWithURL:(NSURL *)url error:(NSError * __autoreleasing *)error
{
	if ((self = [super init])) {
		_url = url;
		if (![self loadAndReturnError:error]) {
			return nil;
		}
	}
	return self;
}

- (bool)loadAndReturnError:(NSError * __autoreleasing *)error
{
	if (!(_fileData = [NSData dataWithContentsOfURL:_url options:NSDataReadingMappedAlways error:error])) {
		return false;
	}
	_loadAddress = _fileData.bytes;
	
	const struct mach_header *header = reinterpret_cast<const struct mach_header *>(_loadAddress);
	
	if (header->magic != MH_MAGIC && header->magic != MH_CIGAM && header->magic != MH_MAGIC_64 && header->magic != MH_CIGAM_64) {
		return LoadError(@"Not a Mach-O binary");
	}
	if (header->magic == MH_CIGAM || header->magic == MH_CIGAM_64) {
		return LoadError(@"Don't support opposite-endian binaries yet");
	}
	
	_is64Bit = (header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64);
	_type = header->filetype;
	_cputype = header->cputype;
	_cpusubtype = header->cpusubtype;
	
	const uint8_t *load_command_start = reinterpret_cast<const uint8_t *>(_loadAddress) + (_is64Bit ? sizeof(struct mach_header) : sizeof(struct mach_header_64));
	const struct load_command *current_command = reinterpret_cast<const struct load_command *>(load_command_start);
	NSMutableArray *allCommands = @[].mutableCopy;
	
	for (uint32_t ncmd = 0; ncmd < header->ncmds; ++ncmd) {
		ECVIMachOLoadCommand *cmd = [[ECVIMachOLoadCommand alloc] initWithCommandInFile:self fromCmdAt:current_command error:error];
		
		if (!cmd)
			return false;
		[allCommands addObject:cmd];
	}
	_loadCommandList = allCommands.copy;
	
	// Run the segments before awaking commands from binary so we get a textVMAddr set
	NSMutableArray *segments = @[].mutableCopy;
	
	[[self loadCommandsOfType:LC_SEGMENT] enumerateObjectsUsingBlock:^ (ECVIMachOSegmentCommand *obj, NSUInteger idx, BOOL *stop) {
		if ([obj.name isEqualToString:@"__TEXT"]) {
			self->_textVMAddr = obj.loadAddress;
		}
		[segments addObject:obj];
	}];
	_segments = segments.copy;
	
	[_loadCommandList enumerateObjectsUsingBlock:^ (ECVIMachOLoadCommand *obj, NSUInteger idx, BOOL *stop) { [obj awakeFromBinary]; }];
	
	if (([self loadCommandOfType:LC_UUID])) {
		; // _uuid = [self loadCommandOfType:LC_UUID].UUID;
	}
	
	// SYMBOL TABLE
}


- (ECVIMachOLoadCommand *)loadCommandOfType:(uint32_t)type
{
	return [_loadCommandList objectAtIndex:[_loadCommandList indexOfObjectPassingTest:^ BOOL (ECVIMachOLoadCommand *obj, NSUInteger idx, BOOL *stop) { return obj.type == type; }]];
}

- (NSArray *)loadCommandsOfType:(uint32_t)type
{
	return [_loadCommandList objectsAtIndexes:[_loadCommandList indexesOfObjectsPassingTest:^ BOOL (ECVIMachOLoadCommand *obj, NSUInteger idx, BOOL *stop) { return obj.type == type; }]];
}

- (ECVIMachOSymbol *)lookupSymbolUsingAddress:(uint64_t)address exactMatch:(bool)exact symtableOnly:(bool)noExtraInfo
{
	return nil;
}

@end
