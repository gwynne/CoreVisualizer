//
//  ECVIInstance.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIInstance.h"
#import "ECVIAppleA7CPUCore.h"
#import "ECVIMemoryMap.h"
#import "ECVIMachOBinary.h"
#import "ECVIMachOSegmentCommand.h"
#import "ECVIMachOEntryCommand.h"
#import <vector>

@interface ECVIInstance () <ECVIMemoryMapDelegate, ECVIGenericCPUCoreDelegate>
@end

@implementation ECVIInstance
{
	ECVIAppleA7CPUCore *_core;
	ECVIMemoryMap *_map;
	NSArray *_loadedImages;
}

- (instancetype)init
{
	if ((self = [super init])) {
		_map = [[ECVIMemoryMap alloc] initWithPageSize:4096];
		_map.delegate = self;
		_core = [[ECVIAppleA7CPUCore alloc] initWithMemoryMap:_map];
		_core.startPC = 0;
		_core.delegate = self;
	}
	return self;
}

- (void)reset
{
	std::vector<const ECVIMemoryRegion *> regions;
	
	for (auto i = _map.regionsBegin; i != _map.regionsEnd; ++i) {
		regions.push_back(&(*i));
	}
	for (auto i = regions.begin(); i != regions.end(); ++i) {
		[_map unmapRegion:*(*i)];
	}
	
	[_core reset];
	
	[_map mapRegionOfSize:4096 withName:@"__PAGEZERO"];
}

- (bool)loadBinary:(NSURL *)binary error:(NSError * __autoreleasing *)error
{
	ECVIMachOBinary *image = [[ECVIMachOBinary alloc] initWithURL:binary error:error];
	
	if (!image)
		return false;
	if (image.cputype != (CPU_TYPE_ARM | CPU_ARCH_ABI64))
		return LoadError(false, @"Only loading ARM64 binaries right now");
	
	__block bool didFailImage = false;
	
	[image.segments enumerateObjectsUsingBlock:^ (ECVIMachOSegmentCommand *seg, NSUInteger idx, BOOL *stop) {
		if ([self->_map mapRegionOfSize:seg.size withName:seg.name atAddress:seg.loadAddress].baseAddress == ECVIInvalidRegionAddress) {
			*stop = YES;
			didFailImage = true;
		}
	}];
	if (didFailImage)
		return LoadError(false, @"Failed to map a segment");
	
	ECVIMachOEntryCommand *entry = (ECVIMachOEntryCommand *)[image loadCommandOfType:LC_MAIN];
	
	_core.startPC = entry.entryAddress;
	[_map mapRegionOfSize:entry.initialStackSize withName:@"__STACK"];
	[_core reset];
	
	_loadedImages = @[image];
	return true;
}

- (NSString *)description
{
	NSMutableString *desc = @"".mutableCopy;
	
	[desc appendFormat:@"CPU core: %@ <start address = 0x%016llx>\n", [_core class], _core.startPC];
	[desc appendFormat:@"Memory maps:\n"];
	for (auto i = _map.regionsBegin; i != _map.regionsEnd; ++i) {
		const ECVIMemoryRegion &region = *i;
		
		[desc appendFormat:@"\t%@: 0x%016llx - 0x%016llx (0x%llx bytes)\n", region.name, region.baseAddress, region.baseAddress + region.length, region.length];
	}
	[desc appendFormat:@"Loaded images:\n"];
	[_loadedImages enumerateObjectsUsingBlock:^ (ECVIMachOBinary *binary, NSUInteger idx, BOOL *stop) {
		[desc appendFormat:@"\t%@ (%@):\n", binary.url.lastPathComponent, binary.url];
	}];
}

- (void)stepOne
{
	[_core step];
}

- (void)CPUcore:(ECVIGenericCPUCore *)core didUpdateRegister:(uint32_t)rnum toValue:(uint64_t)value
{
	NSLog(@"Register %u updated to %llu!", rnum, value);
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didMapNewRegion:(const ECVIMemoryRegion &)region
{
	NSLog(@"Mapped region %@ at 0x%016llx + 0x%llx", region.name, region.baseAddress, region.length);
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didUnmapRegion:(const ECVIMemoryRegion &)region
{
	NSLog(@"Unmapped region %@", region.name);
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeReadFromAddress:(uint64_t)address ofSize:(uint64_t)readLen ofValue:(uint64_t)value inRegion:(const ECVIMemoryRegion &)region
{
	NSLog(@"Read from 0x%016llx size %llu in %@ == 0x%016llx", address, readLen, region.name, value);
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeReadFromUnmappedAddress:(uint64_t)address ofSize:(uint64_t)readLen
{
	NSLog(@"Unmapped read from 0x%016llx size %llu", address, readLen);
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeWriteToAddress:(uint64_t)address ofSize:(uint64_t)writeLen ofValue:(uint64_t)value inRegion:(const ECVIMemoryRegion &)region
{
	NSLog(@"Write to 0x%016llx size %llu in %@ == 0x%016llx", address, writeLen, region.name, value);
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeWriteToUnmappedAddress:(uint64_t)address ofSize:(uint64_t)writeLen
{
	NSLog(@"Unmapped write to 0x%016llx size %llu", address, writeLen);
}

@end
