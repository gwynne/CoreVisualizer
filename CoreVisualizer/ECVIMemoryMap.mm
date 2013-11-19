//
//  ECVIMemoryMap.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIMemoryMap.h"
#import <algorithm>
#import <cstdlib>
#import <vector>

@interface ECVIMemoryRegion ()
@property(nonatomic,readwrite,weak) ECVIMemoryMap *map;
@end

@implementation ECVIMemoryRegion

- (instancetype)initWithInternalBackingOfLength:(uint64_t)length atAddress:(uint64_t)baseAddress name:(NSString *)name inMap:(ECVIMemoryMap *)map
{
	return [self initWithMutableExternalBacking:[[NSMutableData alloc] initWithLength:length] atAddress:baseAddress name:name inMap:map];
}

- (instancetype)initWithVirtualBackingOfLength:(uint64_t)length atAddress:(uint64_t)baseAddress name:(NSString *)name inMap:(ECVIMemoryMap *)map
{
	if ((self = [self initWithExternalBacking:nil atAddress:baseAddress name:name inMap:map])) {
		_length = length;
		_lastAddress = _baseAddress + _length - 1;
	}
	return self;
}

- (instancetype)initWithExternalBacking:(NSData *)backing atAddress:(uint64_t)baseAddress name:(NSString *)name inMap:(ECVIMemoryMap *)map
{
	if ((self = [super init])) {
		_map = map;
		_baseAddress = baseAddress;
		_length = backing.length;
		_lastAddress = _baseAddress + _length - 1;
		_name = name;
		_backing = backing;
		_bytes = reinterpret_cast<const uint8_t *>(_backing.bytes);
		_words = reinterpret_cast<const uint16_t *>(_bytes);
		_longs = reinterpret_cast<const uint32_t *>(_words);
		_quads = reinterpret_cast<const uint64_t *>(_longs);
		_octets = reinterpret_cast<const uint128_t *>(_quads);
	}
	return self;
}

- (instancetype)initWithMutableExternalBacking:(NSMutableData *)backing atAddress:(uint64_t)baseAddress name:(NSString *)name inMap:(ECVIMemoryMap *)map
{
	NSAssert(backing != nil, @"Mutable backing can't be nil!");
	
	if ((self = [self initWithExternalBacking:backing atAddress:baseAddress name:name inMap:map])) {
		_mutableBacking = backing;
		_mutableBytes = reinterpret_cast<uint8_t *>(_mutableBacking.mutableBytes);
		_mutableWords = reinterpret_cast<uint16_t *>(_mutableBytes);
		_mutableLongs = reinterpret_cast<uint32_t *>(_mutableWords);
		_mutableQuads = reinterpret_cast<uint64_t *>(_mutableLongs);
		_mutableOctets = reinterpret_cast<uint128_t *>(_mutableQuads);
	}
	return self;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"Region %@ (%@): 0x%016llx - 0x%016llx (0x%llx bytes)", self.name, self.backing ? (self.mutableBacking ? @"writeable" : @"external") : @"virtual", self.baseAddress, self.lastAddress, self.length];
}

@end

@interface ECVIMemoryMap ()
- (ECVIMemoryRegion *)regionContainingAddress:(uint64_t)address;
- (uint64_t)findEmptyRegionofSize:(uint64_t)regionLen;
@end

@implementation ECVIMemoryMap
{
	NSMutableArray *_regions;
}

- (instancetype)initWithPageSize:(uint64_t)pageSize
{
	NSAssert(__builtin_popcount(pageSize) == 1, @"page size must be a power of two");
		
	if ((self = [super init])) {
		_regions = @[].mutableCopy;
		_pageSize = pageSize;
	}
	return self;
}

- (ECVIMemoryRegion *)regionByName:(NSString *)name
{
	NSUInteger idx = [_regions indexOfObjectPassingTest:^ BOOL (ECVIMemoryRegion *region, NSUInteger idx, BOOL *stop) { return *stop = [region.name isEqualToString:name]; }];
	
	return idx == NSNotFound ? nil : _regions[idx];
}

- (ECVIMemoryRegion *)mapRegion:(ECVIMemoryRegion *)region
{
	NSAssert((region.baseAddress & (_pageSize - 1)) == 0, @"base address must be aligned to a page boundary");
	NSAssert((region.length & (_pageSize - 1)) == 0, @"length must be a multiple of the page size");
	
	if (!region || [_regions indexesOfObjectsPassingTest:^ BOOL (ECVIMemoryRegion *reg, NSUInteger idx, BOOL *stop) { return (*stop = reg.baseAddress <= region.lastAddress && region.baseAddress <= reg.lastAddress); }].count > 0) {
		return nil;
	}
	[_regions insertObject:region atIndex:[_regions indexOfObject:region inSortedRange:(NSRange){ 0, _regions.count } options:NSBinarySearchingInsertionIndex | NSBinarySearchingFirstEqual
			  usingComparator:^ NSComparisonResult (ECVIMemoryRegion *region1, ECVIMemoryRegion *region2) {
		return (region1.baseAddress < region2.baseAddress ? NSOrderedAscending : (region1.baseAddress == region2.baseAddress ? NSOrderedSame : NSOrderedDescending));
	}]];
	if ([self.delegate respondsToSelector:@selector(memoryMap:didMapNewRegion:)])
		[self.delegate memoryMap:self didMapNewRegion:region];
	return region;
}

- (ECVIMemoryRegion *)mapInternalRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName
{
	return [self mapInternalRegionOfSize:regionLen withName:regionName atAddress:[self findEmptyRegionofSize:regionLen]];
}

- (ECVIMemoryRegion *)mapInternalRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName atAddress:(uint64_t)regionBase
{
	return [self mapRegion:[[ECVIMemoryRegion alloc] initWithInternalBackingOfLength:regionLen atAddress:regionBase name:regionName inMap:self]];
}

- (ECVIMemoryRegion *)mapVirtualRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName
{
	return [self mapVirtualRegionOfSize:regionLen withName:regionName atAddress:[self findEmptyRegionofSize:regionLen]];
}

- (ECVIMemoryRegion *)mapVirtualRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName atAddress:(uint64_t)regionBase
{
	return [self mapRegion:[[ECVIMemoryRegion alloc] initWithVirtualBackingOfLength:regionLen atAddress:regionBase name:regionName inMap:self]];
}

- (ECVIMemoryRegion *)mapExternalRegionWithBacking:(NSData *)backing withName:(NSString *)regionName
{
	return [self mapExternalRegionWithBacking:backing withName:regionName atAddress:[self findEmptyRegionofSize:backing.length]];
}

- (ECVIMemoryRegion *)mapExternalRegionWithBacking:(NSData *)backing withName:(NSString *)regionName atAddress:(uint64_t)regionBase
{
	return [self mapRegion:[[ECVIMemoryRegion alloc] initWithExternalBacking:backing atAddress:regionBase name:regionName inMap:self]];
}

- (ECVIMemoryRegion *)mapExternalRegionWithMutableBacking:(NSMutableData *)backing withName:(NSString *)regionName
{
	return [self mapExternalRegionWithMutableBacking:backing withName:regionName atAddress:[self findEmptyRegionofSize:backing.length]];
}

- (ECVIMemoryRegion *)mapExternalRegionWithMutableBacking:(NSMutableData *)backing withName:(NSString *)regionName atAddress:(uint64_t)regionBase
{
	return [self mapRegion:[[ECVIMemoryRegion alloc] initWithMutableExternalBacking:backing atAddress:regionBase name:regionName inMap:self]];
}

- (bool)unmapRegionAt:(uint64_t)regionBase unmappingMultiple:(bool)multiple
{
	NSIndexSet *deadRegions = [_regions indexesOfObjectsPassingTest:^ BOOL (ECVIMemoryRegion *obj, NSUInteger idx, BOOL *stop) {
		*stop = multiple;
		return obj.baseAddress == regionBase;
	}];

	if (deadRegions.count) {
		[_regions removeObjectsAtIndexes:deadRegions];
		return true;
	}
	return false;
}

- (bool)unmapRegion:(ECVIMemoryRegion *)region
{
	NSUInteger idx = [_regions indexOfObject:region inSortedRange:(NSRange){ 0, _regions.count } options:NSBinarySearchingFirstEqual
							   usingComparator:^ NSComparisonResult (ECVIMemoryRegion *obj1, ECVIMemoryRegion *obj2) { return [@(obj1.baseAddress) compare:@(obj2.baseAddress)]; }];
	
	if (idx != NSNotFound)
		[_regions removeObjectAtIndex:idx];
	return idx == NSNotFound;
}

- (void)unmapAllRegions
{
	if ([self.delegate respondsToSelector:@selector(memoryMap:didUnmapRegion:)]) {
		[_regions enumerateObjectsUsingBlock:^ (ECVIMemoryRegion *region, NSUInteger idx, BOOL *stop) {
			[self.delegate memoryMap:self didUnmapRegion:region];
		}];
	}
	[_regions removeAllObjects];
}

- (uint128_t)readValueOfLength:(uint64_t)length fromAddress:(uint64_t)address
{
	ECVIMemoryRegion *region = [self regionContainingAddress:address];
	
	if (region == nil || address + length >= region.lastAddress || __builtin_popcount(length) > 1 || length > 16) {
		if ([self.delegate respondsToSelector:@selector(memoryMap:didSeeReadFromUnmappedAddress:ofSize:)]) {
			[self.delegate memoryMap:self didSeeReadFromUnmappedAddress:address ofSize:length];
		}
		return 0;
	}
	
	uint128_t value = 0;
	
	if (region.bytes != nullptr) {
		switch (length) {
			case 1:
				value = region.bytes[address - region.baseAddress];
				break;
			case 2:
				value = *(const uint16_t *)(&region.bytes[address - region.baseAddress]);
				break;
			case 4:
				value = *(const uint32_t *)(&region.bytes[address - region.baseAddress]);
				break;
			case 8:
				value = *(const uint64_t *)(&region.bytes[address - region.baseAddress]);
				break;
			case 16:
				value = *(const uint128_t *)(&region.bytes[address - region.baseAddress]);
				break;
			default:
				NSAssert(NO, @"How did we get here?");
				break;
		}
	}
	
	if ([self.delegate respondsToSelector:@selector(memoryMap:didSeeReadFromAddress:ofSize:ofValue:inRegion:)]) {
		[self.delegate memoryMap:self didSeeReadFromAddress:address ofSize:length ofValue:value inRegion:region];
	}
	return value;
}

- (void)writeValue:(uint128_t)value ofLength:(uint64_t)length toAddress:(uint64_t)address
{
	ECVIMemoryRegion *region = [self regionContainingAddress:address];
	
	if (region == nil || region.mutableBacking == nil || address + length >= region.lastAddress || __builtin_popcount(length) > 1 || length > 16) {
		if ([self.delegate respondsToSelector:@selector(memoryMap:didSeeWriteToUnmappedAddress:ofSize:)]) {
			[self.delegate memoryMap:self didSeeWriteToUnmappedAddress:address ofSize:length];
		}
		return 0;
	}
	
	switch (length) {
		case 1:
			region.mutableBytes[address - region.baseAddress] = static_cast<uint8_t>(value);
			break;
		case 2:
			*(uint16_t *)(&region.mutableBytes[address - region.baseAddress]) = static_cast<uint16_t>(value);
			break;
		case 4:
			*(uint32_t *)(&region.mutableBytes[address - region.baseAddress]) = static_cast<uint32_t>(value);
			break;
		case 8:
			*(uint64_t *)(&region.mutableBytes[address - region.baseAddress]) = static_cast<uint64_t>(value);
			break;
		case 16:
			*(uint128_t *)(&region.mutableBytes[address - region.baseAddress]) = value;
			break;
		default:
			NSAssert(NO, @"How did we get here?");
			break;
	}
	
	if ([self.delegate respondsToSelector:@selector(memoryMap:didSeeWriteToAddress:ofSize:ofValue:inRegion:)]) {
		[self.delegate memoryMap:self didSeeWriteToAddress:address ofSize:length ofValue:value inRegion:region];
	}
	return value;
}

- (ECVIMemoryRegion *)regionContainingAddress:(uint64_t)address
{
	NSUInteger idx = [_regions indexOfObjectPassingTest:^ BOOL (ECVIMemoryRegion *region, NSUInteger idx, BOOL *stop) { return (*stop = region.baseAddress <= address && address <= region.lastAddress); }];
				
	return idx == NSNotFound ? nil : _regions[idx];
}

- (uint64_t)findEmptyRegionofSize:(uint64_t)regionLen
{
	uint64_t base = 0;
	
	while (base + regionLen > base) {
		ECVIMemoryRegion *region1 = [self regionContainingAddress:base];
		
		if (region1) {
			base = region1.lastAddress + 1;
			continue;
		}
		ECVIMemoryRegion *region2 = [self regionContainingAddress:base + regionLen];
		
		if (region2) {
			base = region2.lastAddress + 1;
			continue;
		}
		
		return base;
	}
	return ECVIInvalidRegionAddress;
}

- (NSString *)description
{
	NSMutableString *desc = @"".mutableCopy;
	
	[desc appendFormat:@"Memory map <%p> with %lu regions:\n", self, (unsigned long)_regions.count];
	[_regions enumerateObjectsUsingBlock:^ (ECVIMemoryRegion *region, NSUInteger idx, BOOL *stop) { [desc appendFormat:@"%@\n", region]; }];
	return desc;
}

@end
