//
//  ECVIMachOBinary.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIMachOBinary.h"

@implementation ECVIMachOBinary
{
	NSData *_fileData;
}

- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error
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
	#define LoadError(message) ({ if (error) *error = [NSError errorWithDomain:@"ECVIMachOLoadingErrorDomain" code:__COUNTER__ userInfo:@{ NSLocalizedDescriptionKey: message }]; false; })
	
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
		ECVIMachOLoadCommand *cmd = [ECVIMachOLoadCommand loadCommandInFile:self fromCmdAt:current_command error:error];
		
		if (!cmd) {
			return false;
		}
		[allCommands addObject:cmd];
	}
	_loadCommandList = allCommands.copy;
	
	NSMutableArray *dylinkerCmds = @[].mutableCopy;
	
	for (ECVIMachOLoadCommand *cmd in _loadCommandList) {
		if ([cmd isKindOfClass:[ECVIMachOEntryCommand class]]) {
			_entryPoint = cmd;
		}
	}
}

@property(nonatomic,readonly) NSURL *url;
@property(nonatomic,readonly) void *loadAddress;
@property(nonatomic,readonly) uint32_t type;
@property(nonatomic,readonly) cpu_type_t cputype;
@property(nonatomic,readonly) cpu_subtype_t cpusubtype;
@property(nonatomic,readonly) bool is64Bit;
@property(nonatomic,readonly) NSArray *loadCommandList;
@property(nonatomic,readonly) NSArray *segments;
@property(nonatomic,readonly) ECVIMachOEntryCommand *entryPoint;
@property(nonatomic,readonly) ECVIMachODynamicInfoCommands *dynamicInfo;
@property(nonatomic,readonly) NSUUID *uuid;
@property(nonatomic,readonly) std::map<NSString *, ECVIMachOSymbol *> symbolTable;

- (ECVIMachOSymbol *)lookupSymbolUsingAddress:(uint64_t)address exactMatch:(bool)exact symtableOnly:(bool)noExtraInfo;

@end
