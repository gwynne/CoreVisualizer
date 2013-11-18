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
#import "ECVIMachOFatBinary.h"
#import "ECVIMachOBinary.h"
#import "ECVIMachOSegmentCommand.h"
#import "ECVIMachOEntryCommand.h"
#import "ECVIMachOSymbol.h"
#import <vector>
#import <mach-o/arch.h>

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
}

- (bool)loadBinary:(NSURL *)binary error:(NSError * __autoreleasing *)error
{
	ECVIMachOFatBinary *fimage = [[ECVIMachOFatBinary alloc] initWithURL:binary error:error];
	
	if (!fimage)
		return false;

	ECVIMachOBinary *image = [fimage binaryForCPUType:CPU_TYPE_ARM | CPU_ARCH_ABI64];
	
	if (!image)
		return LoadError(false, @"Only loading ARM64 binaries right now");
	
	__block bool didFailImage = false;
	
	[image.segments enumerateObjectsUsingBlock:^ (ECVIMachOSegmentCommand *seg, NSUInteger idx, BOOL *stop) {
		if ([self->_map mapRegionOfSize:seg.loadedSize withName:seg.name atAddress:seg.loadAddress empty:[seg.name isEqualToString:@"__PAGEZERO"]].baseAddress == ECVIInvalidRegionAddress) {
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
	
	[desc appendFormat:@"Core visualizer instance %@\n", [super description]];
	[desc appendFormat:@"CPU core: %@\n", _core];
	[desc appendFormat:@"Memory maps:\n"];
	for (auto i = _map.regionsBegin; i != _map.regionsEnd; ++i) {
		const ECVIMemoryRegion &region = *i;
		
		[desc appendFormat:@"%@: 0x%016llx - 0x%016llx (0x%llx bytes)\n", region.name, region.baseAddress, region.baseAddress + region.length - 1, region.length];
	}
	[desc appendFormat:@"\nLoaded images:\n"];
	[_loadedImages enumerateObjectsUsingBlock:^ (ECVIMachOBinary *binary, NSUInteger idx, BOOL *stop) {
		const NXArchInfo *ai = NXGetArchInfoFromCpuType(binary.cputype, binary.cpusubtype);

		[desc appendFormat:@"%@ (%@):\n", binary.url.lastPathComponent, binary.uuid];
		[desc appendFormat:@"Arch: %s (%d/%d)\n", ai ? ai->name : "(unknown)", ai ? ai->cputype : binary.cputype, ai ? ai->cpusubtype : binary.cpusubtype];
		[desc appendFormat:@"Loaded from: %@\n", binary.url];
		[desc appendFormat:@"Address in memory: 0x%016llx\n", reinterpret_cast<uint64_t>(binary.loadAddress)];
		[desc appendFormat:@"Type: %u (%d-bit)\n", binary.type, binary.is64Bit ? 64 : 32];
		[desc appendFormat:@"Load commands:\n"];
		[binary.loadCommandList enumerateObjectsUsingBlock:^ (ECVIMachOLoadCommand *cmd, NSUInteger idx2, BOOL *stop2) {
			[desc appendFormat:@"\tcmd %u size %llu\n", cmd.type, cmd.size];
		}];
		[desc appendFormat:@"Segments:\n"];
		[binary.segments enumerateObjectsUsingBlock:^ (ECVIMachOSegmentCommand *seg, NSUInteger idx2, BOOL *stop2) {
			[desc appendFormat:@"\t%@ - VM 0x%016llx + 0x%llx (@ 0x%016llx)\n", seg.name, seg.loadAddress, seg.loadedSize, reinterpret_cast<uint64_t>(seg.segmentBase)];
			[desc appendFormat:@"\tPermissions %x (max %x)\n", seg.initialPermissions, seg.maximumPermissions];
			[desc appendFormat:@"\tSections:\n"];
			[seg.sections enumerateObjectsUsingBlock:^ (ECVIMachOSection *sect, NSUInteger idx3, BOOL *stop3) {
				[desc appendFormat:@"\t\t%@ (type %u) - VM 0x%016llx + 0x%llx (@ 0x%016llx)\n", sect.name, sect.type, sect.loadAddress, sect.loadedSize, reinterpret_cast<uint64_t>(sect.sectionBase)];
			}];
		}];
		[ desc appendFormat:@"Symbols:\n"];
		for (auto i = binary.symbolTable.begin(); i != binary.symbolTable.end(); ++i) {
			ECVIMachOSymbol *sym = (*i).second;
			
			[desc appendFormat:@"\t%u: 0x%016llx = %@ (type %hhu)\n", sym.idx, sym.address, sym.rawName, sym.type];
		}
	}];
	return desc;
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
