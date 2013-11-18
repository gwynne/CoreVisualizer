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
#import "ECVIMachOSymbol.h"
#import <mach-o/nlist.h>

@implementation ECVIMachOBinary
{
	NSData *_fileData;
	std::map<uint64_t, ECVIMachOSymbol *> _symbolAddressMap;
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
	// Map binary in
	if (!(_fileData = [NSData dataWithContentsOfURL:_url options:NSDataReadingMappedAlways error:error])) {
		return false;
	}
	_loadAddress = _fileData.bytes;
	
	// Read header
	const struct mach_header *header = reinterpret_cast<const struct mach_header *>(_loadAddress);
	
	if (header->magic != MH_MAGIC && header->magic != MH_CIGAM && header->magic != MH_MAGIC_64 && header->magic != MH_CIGAM_64) {
		return LoadError(false, @"Not a Mach-O binary");
	}
	if (header->magic == MH_CIGAM || header->magic == MH_CIGAM_64) {
		return LoadError(false, @"Don't support opposite-endian binaries yet");
	}
	
	_is64Bit = (header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64);
	_type = header->filetype;
	_cputype = header->cputype;
	_cpusubtype = header->cpusubtype;
	
	// Read load commands
	const uint8_t *load_command_start = reinterpret_cast<const uint8_t *>(_loadAddress) + (_is64Bit ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
	const struct load_command *current_command = reinterpret_cast<const struct load_command *>(load_command_start);
	NSMutableArray *allCommands = @[].mutableCopy;
	
	for (uint32_t ncmd = 0; ncmd < header->ncmds; ++ncmd) {
		ECVIMachOLoadCommand *cmd = [[ECVIMachOLoadCommand alloc] initWithCommandInFile:self fromCmdAt:current_command error:error];
		
		if (!cmd)
			return false;
		[allCommands addObject:cmd];
		load_command_start += current_command->cmdsize;
		current_command = reinterpret_cast<const struct load_command *>(load_command_start);
	}
	_loadCommandList = allCommands.copy;
	
	// Load segments - run these segments before awaking commands from binary so the text segment load address is available
	NSMutableArray *segments = @[].mutableCopy, *sections = @[].mutableCopy;
	
	[[self loadCommandsOfType:LC_SEGMENT] enumerateObjectsUsingBlock:^ (ECVIMachOSegmentCommand *obj, NSUInteger idx, BOOL *stop) {
		if ([obj.name isEqualToString:@"__TEXT"]) {
			NSAssert(self->_textSegment == nil, @"Two __TEXT segments?!");
			
			self->_textSegment = obj;
		}
		[segments addObject:obj];
		[sections addObjectsFromArray:obj.sections];
	}];
	_segments = segments.copy;
	_sections = sections.copy;
	
	// Awaken the load commands
	[_loadCommandList enumerateObjectsUsingBlock:^ (ECVIMachOLoadCommand *obj, NSUInteger idx, BOOL *stop) { [obj awakeFromBinary]; }];
	
	// Grab the UUID, if any
	ECVIMachOLoadCommand *uuidCommand = [self loadCommandOfType:LC_UUID];

	if (uuidCommand) {
		_uuid = [[NSUUID alloc] initWithUUIDBytes:reinterpret_cast<const struct uuid_command *>(uuidCommand.baseCommand)->uuid];
	}
	
	// Load the symbol table
	ECVIMachOLoadCommand *symtabCommand = [self loadCommandOfType:LC_SYMTAB];
	const struct symtab_command *symtabcmd = reinterpret_cast<const struct symtab_command *>(symtabCommand.baseCommand);
	const char **strtab = const_cast<const char **>(reinterpret_cast<const char * const *>(reinterpret_cast<const uint8_t *>(_loadAddress) + symtabcmd->stroff));
	
	if (!symtabCommand) {
		return LoadError(false, @"No symbol table!? We can't handle that!");
	}
	for (uint32_t nsym = 0; nsym < symtabcmd->nsyms; ++nsym) {
		ECVIMachOSymbol *symbol = nil;
		
		if (_is64Bit) {
			symbol = [[ECVIMachOSymbol alloc] initWithBinary:self symbol64:reinterpret_cast<const struct nlist_64 *>(reinterpret_cast<const uint8_t *>(_loadAddress) + symtabcmd->symoff) + nsym idx:nsym strings:strtab error:error];
		} else {
			symbol = [[ECVIMachOSymbol alloc] initWithBinary:self symbol:reinterpret_cast<const struct nlist *>(reinterpret_cast<const uint8_t *>(_loadAddress) + symtabcmd->symoff) + nsym idx:nsym strings:strtab error:error];
		}
		if (!symbol) {
			continue; //return false;
		}
		_symbolTable.insert({ symbol.rawName, symbol });
		_symbolAddressMap.insert({ symbol.address, symbol });
	}
	
	return true;
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
	if (exact) {
		auto loc = _symbolAddressMap.find(address);
		
		if (loc != _symbolAddressMap.end())
			return (*loc).second;
	} else {
		auto loc = _symbolAddressMap.lower_bound(address);
		
		if (loc == _symbolAddressMap.end()) {
			--loc;
		} else if (loc == _symbolAddressMap.begin()) {
			if ((*loc).second.address != address)
				loc = _symbolAddressMap.end();
		}
		
		if (loc != _symbolAddressMap.end())
			return (*loc).second;
	}
	return nil;
}

- (ECVIMachOSegmentCommand *)segmentNamed:(NSString *)segname
{
	return _segments[[_segments indexOfObjectPassingTest:^ BOOL (ECVIMachOSegmentCommand *obj, NSUInteger idx, BOOL *stop) { return [obj.name isEqualToString:segname]; }]];
}

@end
