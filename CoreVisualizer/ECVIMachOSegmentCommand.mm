//
//  ECVIMachOSegmentCommand.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIMachOSegmentCommand.h"
#import "ECVIMachOBinary.h"
#import <mach-o/loader.h>

@interface ECVIMachOSection ()
@property(nonatomic,readwrite,weak) ECVIMachOSegmentCommand *segment;
- (instancetype)initWithSection:(const struct section *)sect inSegment:(ECVIMachOSegmentCommand *)seg error:(NSError **)error;
- (instancetype)initWithSection64:(const struct section_64 *)sect inSegment:(ECVIMachOSegmentCommand *)seg error:(NSError **)error;
@end

@implementation ECVIMachOSegmentCommand

- (instancetype)initWithBinary:(ECVIMachOBinary *)binary type:(uint32_t)type size:(uint64_t)size cmd:(const struct load_command *)cmd error:(NSError *__autoreleasing *)error
{
	NSAssert(cmd->cmd == LC_SEGMENT || cmd->cmd == LC_SEGMENT_64, @"Command must be a segment");
	
	if ((self = [super initWithBinary:binary type:LC_SEGMENT size:size cmd:cmd error:error])) {
		NSMutableArray *sections = @[].mutableCopy;

		if (cmd->cmd == LC_SEGMENT) {
			const struct segment_command *realcmd = reinterpret_cast<const struct segment_command *>(cmd);
			
			if (realcmd->segname[15] == 0)
				_name = [[NSString alloc] initWithUTF8String:realcmd->segname];
			else
				_name = [[NSString alloc] initWithBytes:realcmd->segname length:16 encoding:NSUTF8StringEncoding];
			_loadAddress = realcmd->vmaddr;
			_loadedSize = realcmd->vmsize;
			_segmentBase = reinterpret_cast<const uint8_t *>(binary.loadAddress) + realcmd->fileoff;
			_initialPermissions = realcmd->initprot;
			_maximumPermissions = realcmd->maxprot;
			
			for (uint32_t nsect = 0; nsect < realcmd->nsects; ++nsect) {
				const struct section *sect = reinterpret_cast<const struct section *>(realcmd + 1) + nsect;
				ECVIMachOSection *section = [[ECVIMachOSection alloc] initWithSection:sect inSegment:self error:error];
				
				if (!section)
					return nil;
				[sections addObject:section];
			}
		} else if (cmd->cmd == LC_SEGMENT_64) {
			const struct segment_command_64 *realcmd = reinterpret_cast<const struct segment_command_64 *>(cmd);

			if (realcmd->segname[15] == 0)
				_name = [[NSString alloc] initWithUTF8String:realcmd->segname];
			else
				_name = [[NSString alloc] initWithBytes:realcmd->segname length:16 encoding:NSUTF8StringEncoding];
			_loadAddress = realcmd->vmaddr;
			_loadedSize = realcmd->vmsize;
			_segmentBase = reinterpret_cast<const uint8_t *>(binary.loadAddress) + realcmd->fileoff;
			_initialPermissions = realcmd->initprot;
			_maximumPermissions = realcmd->maxprot;
			
			for (uint32_t nsect = 0; nsect < realcmd->nsects; ++nsect) {
				const struct section_64 *sect = reinterpret_cast<const struct section_64 *>(realcmd + 1) + nsect;
				ECVIMachOSection *section = [[ECVIMachOSection alloc] initWithSection64:sect inSegment:self error:error];
				
				if (!section)
					return nil;
				[sections addObject:section];
			}
		}
		_sections = sections.copy;
	}
	return self;
}

- (void)awakeFromBinary
{
	[super awakeFromBinary];
}

@end

@implementation ECVIMachOSection

- (instancetype)initWithSection:(const struct section *)sect inSegment:(ECVIMachOSegmentCommand *)seg error:(NSError * __autoreleasing *)error
{
	if ((self = [super init])) {
		_segment = seg;
		if (sect->sectname[15] == 0)
			_name = [[NSString alloc] initWithUTF8String:sect->sectname];
		else
			_name = [[NSString alloc] initWithBytes:sect->sectname length:16 encoding:NSUTF8StringEncoding];
		_loadAddress = sect->addr;
		_loadedSize = sect->size;
		_sectionBase = reinterpret_cast<const uint8_t *>(seg.binary.loadAddress) + sect->offset;
		_alignment = sect->align;
		_type = sect->flags & SECTION_TYPE;
		_attributes = sect->flags & SECTION_ATTRIBUTES;
		if (_type == S_NON_LAZY_SYMBOL_POINTERS || _type == S_LAZY_SYMBOL_POINTERS) {
			_symbolIndex = sect->reserved1;
			_symbolSize = sizeof(uint32_t);
		} else if (_type == S_SYMBOL_STUBS) {
			_symbolIndex = sect->reserved1;
			_symbolSize = sect->reserved2;
		}
	}
	return self;
}

- (instancetype)initWithSection64:(const struct section_64 *)sect inSegment:(ECVIMachOSegmentCommand *)seg error:(NSError * __autoreleasing *)error
{
	if ((self = [super init])) {
		_segment = seg;
		if (sect->sectname[15] == 0)
			_name = [[NSString alloc] initWithUTF8String:sect->sectname];
		else
			_name = [[NSString alloc] initWithBytes:sect->sectname length:16 encoding:NSUTF8StringEncoding];
		_loadAddress = sect->addr;
		_loadedSize = sect->size;
		_sectionBase = reinterpret_cast<const uint8_t *>(seg.binary.loadAddress) + sect->offset;
		_alignment = sect->align;
		_type = sect->flags & SECTION_TYPE;
		_attributes = sect->flags & SECTION_ATTRIBUTES;
		if (_type == S_NON_LAZY_SYMBOL_POINTERS || _type == S_LAZY_SYMBOL_POINTERS) {
			_symbolIndex = sect->reserved1;
			_symbolSize = sizeof(uint64_t);
		} else if (_type == S_SYMBOL_STUBS) {
			_symbolIndex = sect->reserved1;
			_symbolSize = sect->reserved2;
		}
	}
	return self;
}

@end
