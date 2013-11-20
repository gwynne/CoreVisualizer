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
	[_map unmapAllRegions];
	[self mapMemoryRegionsFromImage:_loadedImages[0] error:NULL];
	[_core reset];
}

- (bool)mapMemoryRegionsFromImage:(ECVIMachOBinary *)image error:(NSError * __autoreleasing *)error
{
	__block bool didFailImage = false;
	
	[image.segments enumerateObjectsUsingBlock:^ (ECVIMachOSegmentCommand *seg, NSUInteger idx, BOOL *stop) {
		ECVIMemoryRegion *region = nil;
		
		if (seg.maximumPermissions == 0) {
			region = [self->_map mapVirtualRegionOfSize:seg.loadedSize withName:seg.name atAddress:seg.loadAddress];
		} else if ((seg.maximumPermissions & VM_PROT_WRITE) != 0) {
			region = [self->_map mapExternalRegionWithMutableBacking:[NSMutableData dataWithBytes:(void *)seg.segmentBase length:seg.loadedSize] withName:seg.name atAddress:seg.loadAddress];
		} else {
			region = [self->_map mapExternalRegionWithBacking:[NSData dataWithBytesNoCopy:(void *)seg.segmentBase length:seg.loadedSize freeWhenDone:NO] withName:seg.name atAddress:seg.loadAddress];
		}
		
		if (!region) {
			*stop = YES;
			didFailImage = true;
		}
	}];
	if (didFailImage)
		return LoadError(false, @"Failed to map a segment");

	ECVIMachOEntryCommand *entry = (ECVIMachOEntryCommand *)[image loadCommandOfType:LC_MAIN];
	
	ECVIMemoryRegion *stack = [_map mapInternalRegionOfSize:entry.initialStackSize withName:@"__STACK"];
	ECVIMemoryRegion *shim = [_map mapInternalRegionOfSize:4096 withName:@"__LOAD_SHIM"];
	
	_core.startPC = shim.baseAddress;
	shim.mutableLongs[0] = (0x58U << 24)/*opc*/ | (0x4U << 5)/*imm19*/ | (0x00U << 0)/*Rt*/;													// LDR x0, 4*4(pc)
	shim.mutableLongs[1] = (0x91U << 24)/*opc*/ | (0x00U << 22)/*shift*/ | (0x00U << 10)/*imm12*/ | (0x00U << 5)/*Rn*/ | (0x1fU << 0)/*Rd*/;	// MOV sp, x0
	shim.mutableLongs[2] = (0x58U << 24)/*opc*/ | (0x4U << 5)/*imm19*/ | (0x01U << 0)/*Rt*/;													// LDR x1, 6*4(pc)
	shim.mutableLongs[3] = (0x3587c0U << 10)/*opc*/ | (0x01U << 5)/*Rn*/ | (0x00U << 0);														// BR x1
	shim.mutableQuads[2] = stack.lastAddress + 1;
	shim.mutableQuads[3] = entry.entryAddress;
	
	[_core reset];
	return true;
}

- (bool)loadBinary:(NSURL *)binary error:(NSError * __autoreleasing *)error
{
	ECVIMachOFatBinary *fimage = [[ECVIMachOFatBinary alloc] initWithURL:binary error:error];
	
	if (!fimage)
		return false;

	ECVIMachOBinary *image = [fimage binaryForCPUType:CPU_TYPE_ARM | CPU_ARCH_ABI64];
	
	if (!image)
		return LoadError(false, @"Only loading ARM64 binaries right now");
	
	if (![self mapMemoryRegionsFromImage:image error:error])
		return false;
	
	_loadedImages = @[image];
	return true;
}

- (NSString *)description
{
	NSMutableString *desc = @"".mutableCopy;
	
	[desc appendFormat:@"Core visualizer instance %@\n", [super description]];
	[desc appendFormat:@"CPU core: %@\n", _core];
	[desc appendFormat:@"%@\n", _map];
	[desc appendFormat:@"Loaded images:\n"];
	[_loadedImages enumerateObjectsUsingBlock:^ (ECVIMachOBinary *binary, NSUInteger idx, BOOL *stop) {
		const NXArchInfo *ai = NXGetArchInfoFromCpuType(binary.cputype, binary.cpusubtype);

		[desc appendFormat:@"%@ (%@):\n", binary.url.lastPathComponent, binary.uuid];
		[desc appendFormat:@"\tArch: %s (%d/%d)\n", ai ? ai->name : "(unknown)", ai ? ai->cputype : binary.cputype & ~CPU_ARCH_MASK, ai ? ai->cpusubtype : binary.cpusubtype & ~CPU_SUBTYPE_MASK];
		[desc appendFormat:@"\tLoaded from: %@\n", binary.url];
		[desc appendFormat:@"\tAddress in memory: 0x%016llx\n", reinterpret_cast<uint64_t>(binary.loadAddress)];
		[desc appendFormat:@"\tType: %u (%d-bit)\n", binary.type, binary.is64Bit ? 64 : 32];
		[desc appendFormat:@"\tLoad commands:\n"];
		[binary.loadCommandList enumerateObjectsUsingBlock:^ (ECVIMachOLoadCommand *cmd, NSUInteger idx2, BOOL *stop2) {
			[desc appendFormat:@"\t\tcmd %u size %llu\n", cmd.type & ~LC_REQ_DYLD, cmd.size];
		}];
		[desc appendFormat:@"\tSegments:\n"];
		[binary.segments enumerateObjectsUsingBlock:^ (ECVIMachOSegmentCommand *seg, NSUInteger idx2, BOOL *stop2) {
			[desc appendFormat:@"\t\t%@ - VM 0x%016llx + 0x%llx (@ 0x%016llx)\n", seg.name, seg.loadAddress, seg.loadedSize, reinterpret_cast<uint64_t>(seg.segmentBase)];
			[desc appendFormat:@"\t\t\tPermissions %x (max %x)\n", seg.initialPermissions, seg.maximumPermissions];
			[desc appendFormat:@"\t\t\tSections:\n"];
			[seg.sections enumerateObjectsUsingBlock:^ (ECVIMachOSection *sect, NSUInteger idx3, BOOL *stop3) {
				[desc appendFormat:@"\t\t\t\t%@ (type %u) - VM 0x%016llx + 0x%llx (@ 0x%016llx)\n", sect.name, sect.type, sect.loadAddress, sect.loadedSize, reinterpret_cast<uint64_t>(sect.sectionBase)];
			}];
		}];
		[ desc appendFormat:@"\tSymbols:\n"];
		for (auto i = binary.symbolTable.begin(); i != binary.symbolTable.end(); ++i) {
			ECVIMachOSymbol *sym = (*i).second;
			
			[desc appendFormat:@"\t\t%u: 0x%016llx = %@ (type %hhu)\n", sym.idx, sym.address, sym.rawName, sym.type];
		}
	}];
	return desc;
}

- (void)stepOne
{
	[_core step];
}

- (void)CPUcore:(ECVIGenericCPUCore *)core didUpdateRegister:(uint32_t)rnum toValue:(uint128_t)value
{
	NSLog(@"Register %u updated to 0x%016llx%016llx", rnum, (uint64_t)(value >> 64), (uint64_t)(value & (uint128_t)UINT64_MAX));
	if ([self.delegate respondsToSelector:_cmd])
		[self.delegate CPUcore:core didUpdateRegister:rnum toValue:value];
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didMapNewRegion:(ECVIMemoryRegion *)region
{
	NSLog(@"Mapped region %@", region);
	if ([self.delegate respondsToSelector:_cmd])
		[self.delegate memoryMap:memoryMap didMapNewRegion:region];
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didUnmapRegion:(ECVIMemoryRegion *)region
{
	NSLog(@"Unmapped region %@", region);
	if ([self.delegate respondsToSelector:_cmd])
		[self.delegate memoryMap:memoryMap didUnmapRegion:region];
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeReadFromAddress:(uint64_t)address ofSize:(uint64_t)readLen ofValue:(uint128_t)value inRegion:(ECVIMemoryRegion *)region
{
	if (readLen > 8) {
		NSLog(@"Read from 0x%016llx size %llu in %@ == 0x%016llx%016llx", address, readLen, region.name, (uint64_t)(value >> 64), (uint64_t)(value & (uint128_t)UINT64_MAX));
	} else {
		NSLog(@"Read from 0x%016llx size %llu in %@ == 0x%0*llx", address, readLen, region.name, (int)readLen << 1, (uint64_t)(value & (uint128_t)UINT64_MAX));
	}
	if ([self.delegate respondsToSelector:_cmd])
		[self.delegate memoryMap:memoryMap didSeeReadFromAddress:address ofSize:readLen ofValue:value inRegion:region];
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeReadFromUnmappedAddress:(uint64_t)address ofSize:(uint64_t)readLen
{
	NSLog(@"Unmapped read from 0x%016llx size %llu", address, readLen);
	if ([self.delegate respondsToSelector:_cmd])
		[self.delegate memoryMap:memoryMap didSeeReadFromUnmappedAddress:address ofSize:readLen];
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeWriteToAddress:(uint64_t)address ofSize:(uint64_t)writeLen ofValue:(uint128_t)value inRegion:(ECVIMemoryRegion *)region
{
	if (writeLen > 8) {
		NSLog(@"Write to 0x%016llx size %llu in %@ == 0x%016llx%016llx", address, writeLen, region.name, (uint64_t)(value >> 64), (uint64_t)(value & (uint128_t)UINT64_MAX));
	} else {
		NSLog(@"Write to 0x%016llx size %llu in %@ == 0x%0*llx", address, writeLen, region.name, (int)writeLen << 1, (uint64_t)(value & (uint128_t)UINT64_MAX));
	}
	if ([self.delegate respondsToSelector:_cmd])
		[self.delegate memoryMap:memoryMap didSeeWriteToAddress:address ofSize:writeLen ofValue:value inRegion:region];
}

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeWriteToUnmappedAddress:(uint64_t)address ofSize:(uint64_t)writeLen
{
	NSLog(@"Unmapped write to 0x%016llx size %llu", address, writeLen);
	if ([self.delegate respondsToSelector:_cmd])
		[self.delegate memoryMap:memoryMap didSeeWriteToUnmappedAddress:address ofSize:writeLen];
}

@end
