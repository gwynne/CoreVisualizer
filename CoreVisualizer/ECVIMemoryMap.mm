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

class _ECVIMemoryRegion : public ECVIMemoryRegion {
	
	public:
		NSMutableData *area;
		
		_ECVIMemoryRegion(void) : ECVIMemoryRegion() {
			baseAddress = ECVIInvalidRegionAddress;
			length = 0;
			name = nil;
			area = nil;
		}
		_ECVIMemoryRegion(uint64_t base, uint64_t len, NSString *label, bool empty) : ECVIMemoryRegion() {
			baseAddress = base;
			length = len;
			name = label;
			area = empty ? nil : [NSMutableData dataWithLength:len];
		}
		virtual ~_ECVIMemoryRegion();
		
		bool operator==(const ECVIMemoryRegion &r) const { return r.baseAddress == baseAddress && r.length == length && (r.name == name || [r.name isEqualToString:name]); }
		bool operator==(const _ECVIMemoryRegion &r) const { return r.baseAddress == baseAddress && r.length == length && (r.name == name || [r.name isEqualToString:name]); }
		bool operator!=(const ECVIMemoryRegion &r) const { return !(*this == r); }
		bool operator!=(const _ECVIMemoryRegion &r) const { return !(r == *this); }
		bool operator<(const ECVIMemoryRegion &r) const { return baseAddress < r.baseAddress; }
		bool operator<(const _ECVIMemoryRegion &r) const { return baseAddress < r.baseAddress; }
		bool operator<=(const ECVIMemoryRegion &r) const { return baseAddress <= r.baseAddress; }
		bool operator<=(const _ECVIMemoryRegion &r) const { return baseAddress <= r.baseAddress; }
		bool operator>(const ECVIMemoryRegion &r) const { return baseAddress > r.baseAddress; }
		bool operator>(const _ECVIMemoryRegion &r) const { return baseAddress > r.baseAddress; }
		bool operator>=(const ECVIMemoryRegion &r) const { return baseAddress >= r.baseAddress; }
		bool operator>=(const _ECVIMemoryRegion &r) const { return baseAddress >= r.baseAddress; }
};

_ECVIMemoryRegion::~_ECVIMemoryRegion()
{
}

typedef std::set<_ECVIMemoryRegion>::const_iterator *__ECVIMemoryRegionIteratorInternal2;

ECVIMemoryRegionIterator::ECVIMemoryRegionIterator(void) : internal(nullptr) {}
ECVIMemoryRegionIterator::ECVIMemoryRegionIterator(__ECVIMemoryRegionIteratorInternal internal_) : internal(internal_) {}
ECVIMemoryRegionIterator::ECVIMemoryRegionIterator(const ECVIMemoryRegionIterator &i) : internal(i.internal) {}
ECVIMemoryRegionIterator::~ECVIMemoryRegionIterator() {}
ECVIMemoryRegionIterator &ECVIMemoryRegionIterator::operator++(void) { ++(*reinterpret_cast<__ECVIMemoryRegionIteratorInternal2>(internal)); return *this; }
ECVIMemoryRegionIterator ECVIMemoryRegionIterator::operator++(int) { ECVIMemoryRegionIterator tmp(*this); operator++(); return tmp; }
ECVIMemoryRegionIterator &ECVIMemoryRegionIterator::operator--(void) { --(*reinterpret_cast<__ECVIMemoryRegionIteratorInternal2>(internal)); return *this; }
ECVIMemoryRegionIterator ECVIMemoryRegionIterator::operator--(int) { ECVIMemoryRegionIterator tmp(*this); operator--(); return tmp; }
bool ECVIMemoryRegionIterator::operator==(const ECVIMemoryRegionIterator &i) const { return *reinterpret_cast<__ECVIMemoryRegionIteratorInternal2>(internal) == *reinterpret_cast<__ECVIMemoryRegionIteratorInternal2>(i.internal); }
bool ECVIMemoryRegionIterator::operator!=(const ECVIMemoryRegionIterator &i) const { return *reinterpret_cast<__ECVIMemoryRegionIteratorInternal2>(internal) != *reinterpret_cast<__ECVIMemoryRegionIteratorInternal2>(i.internal); }
ECVIMemoryRegionIterator::reference ECVIMemoryRegionIterator::operator*(void) const { return *(*reinterpret_cast<__ECVIMemoryRegionIteratorInternal2>(internal)); }

static const _ECVIMemoryRegion ECVIInvalidRegion;

@interface ECVIMemoryMap ()
@property(nonatomic,assign) std::set<_ECVIMemoryRegion> regions;
- (const _ECVIMemoryRegion &)regionContainingAddress:(uint64_t)address;
- (uint64_t)findEmptyRegionofSize:(uint64_t)regionLen;
@end

@implementation ECVIMemoryMap
{
	std::vector<std::set<_ECVIMemoryRegion>::const_iterator> _begIters, _endIters;
}

- (instancetype)initWithPageSize:(uint64_t)pageSize
{
	NSAssert(__builtin_popcount(pageSize) == 1, @"page size must be a power of two");
		
	if ((self = [super init])) {
		_regions.clear();
		_pageSize = pageSize;
	}
	return self;
}

- (ECVIMemoryRegionIterator)regionsBegin
{
	_begIters.emplace_back(_regions.cbegin());
	return ECVIMemoryRegionIterator(const_cast<void *>(reinterpret_cast<const void *>(&_begIters[_begIters.size() - 1])));
}

- (ECVIMemoryRegionIterator)regionsEnd
{
	_endIters.emplace_back(_regions.cend());
	return ECVIMemoryRegionIterator(const_cast<void *>(reinterpret_cast<const void *>(&_endIters[_endIters.size() - 1])));
}

- (const ECVIMemoryRegion &)regionByName:(NSString *)name
{
	for (auto i = self.regionsBegin; i != self.regionsEnd; ++i) {
		const ECVIMemoryRegion &r = *i;
		
		if ([r.name isEqualToString:name])
			return r;
	}
	return ECVIInvalidRegion;
}

- (const ECVIMemoryRegion &)mapRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName
{
	NSAssert((regionLen & (_pageSize - 1)) == 0, @"length must be a multiple of the page size");
	
	uint64_t base = [self findEmptyRegionofSize:regionLen];
	
	if (base == ECVIInvalidRegionAddress) {
		return ECVIInvalidRegion;
	}
	return [self mapRegionOfSize:regionLen withName:regionName atAddress:base empty:false];
}

- (const ECVIMemoryRegion &)mapRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName atAddress:(uint64_t)regionBase empty:(bool)emptyRegion
{
	NSAssert((regionBase & (_pageSize - 1)) == 0, @"base address must be aligned to a page boundary");
	NSAssert((regionLen & (_pageSize - 1)) == 0, @"length must be a multiple of the page size");
	
//	if (!overlap) {
		bool doesOverlap = false;
		
		for (auto i = self.regionsBegin; i != self.regionsEnd && !doesOverlap; ++i) {
			if ((*i).baseAddress <= regionBase + regionLen - 1 && regionBase <= (*i).baseAddress + (*i).length - 1)
				doesOverlap = true;
		}
		if (doesOverlap)
			return ECVIInvalidRegion;
//	}
	const ECVIMemoryRegion &region = *(_regions.insert(_ECVIMemoryRegion(regionBase, regionLen, regionName, emptyRegion)).first);
	
	if ([self.delegate respondsToSelector:@selector(memoryMap:didMapNewRegion:)]) {
		[self.delegate memoryMap:self didMapNewRegion:region];
	}
	return region;
}

- (bool)unmapRegionAt:(uint64_t)regionBase unmappingMultiple:(bool)multiple
{
	for (auto i = self.regionsBegin; i != self.regionsEnd; ++i) {
		if ((*i).baseAddress == regionBase) {
			[self unmapRegion:*i];
			if (!multiple)
				return true;
		}
	}
	return false;
}

- (bool)unmapRegion:(const ECVIMemoryRegion &)region
{
	bool didErase = (_regions.erase(reinterpret_cast<const _ECVIMemoryRegion &>(region)) > 0);
	
	if (didErase && [self.delegate respondsToSelector:@selector(memoryMap:didUnmapRegion:)]) {
		[self.delegate memoryMap:self didUnmapRegion:region];
	}
	return didErase;
}

- (uint64_t)readValueOfLength:(uint64_t)length fromAddress:(uint64_t)address
{
	const _ECVIMemoryRegion &region = [self regionContainingAddress:address];
	
	if (region == ECVIInvalidRegion || address + length >= region.baseAddress + region.length || __builtin_popcount(length) > 1 || length > 8) {
		if ([self.delegate respondsToSelector:@selector(memoryMap:didSeeReadFromUnmappedAddress:ofSize:ofValue:)]) {
			[self.delegate memoryMap:self didSeeReadFromUnmappedAddress:address ofSize:length];
		}
		return 0;
	}
	
	uint64_t value = 0;
	
	switch (length) {
		case 1:
			value = static_cast<uint64_t>(reinterpret_cast<uint8_t *>(region.area.mutableBytes)[address - region.baseAddress]);
			break;
		case 2:
			value = static_cast<uint64_t>(reinterpret_cast<uint16_t *>(reinterpret_cast<uint8_t *>(region.area.mutableBytes))[address - region.baseAddress]);
			break;
		case 4:
			value = static_cast<uint64_t>(reinterpret_cast<uint32_t *>(reinterpret_cast<uint8_t *>(region.area.mutableBytes))[address - region.baseAddress]);
			break;
		case 8:
			value = static_cast<uint64_t>(reinterpret_cast<uint64_t *>(reinterpret_cast<uint8_t *>(region.area.mutableBytes))[address - region.baseAddress]);
			break;
		default:
			NSAssert(NO, @"How did we get here?");
			break;
	}
	
	if ([self.delegate respondsToSelector:@selector(memoryMap:didSeeReadFromAddress:ofSize:ofValue:inRegion:)]) {
		[self.delegate memoryMap:self didSeeReadFromAddress:address ofSize:length ofValue:value inRegion:region];
	}
	return value;
}

- (void)writeValue:(uint64_t)value ofLength:(uint64_t)length toAddress:(uint64_t)address
{
	const _ECVIMemoryRegion &region = [self regionContainingAddress:address];
	
	if (region == ECVIInvalidRegion || address + length >= region.baseAddress + region.length || __builtin_popcount(length) > 1 || length > 8) {
		if ([self.delegate respondsToSelector:@selector(memoryMap:didSeeWriteToUnmappedAddress:ofSize:)]) {
			[self.delegate memoryMap:self didSeeWriteToUnmappedAddress:address ofSize:length];
		}
		return 0;
	}
	
	switch (length) {
		case 1:
			reinterpret_cast<uint8_t *>(region.area.mutableBytes)[address - region.baseAddress] = static_cast<uint8_t>(value);
			break;
		case 2:
			*reinterpret_cast<uint16_t *>(&reinterpret_cast<uint8_t *>(region.area.mutableBytes)[address - region.baseAddress]) = static_cast<uint16_t>(value);
			break;
		case 4:
			*reinterpret_cast<uint32_t *>(&reinterpret_cast<uint8_t *>(region.area.mutableBytes)[address - region.baseAddress]) = static_cast<uint32_t>(value);
			break;
		case 8:
			*reinterpret_cast<uint64_t *>(&reinterpret_cast<uint8_t *>(region.area.mutableBytes)[address - region.baseAddress]) = static_cast<uint64_t>(value);
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

- (const _ECVIMemoryRegion &)regionContainingAddress:(uint64_t)address
{
	for (auto i = _regions.cbegin(); i != _regions.cend(); ++i) {
		if ((*i).baseAddress <= address && (*i).baseAddress + (*i).length > address)
			return *i;
	}
	return ECVIInvalidRegion;
}

- (uint64_t)findEmptyRegionofSize:(uint64_t)regionLen
{
	uint64_t base = 0;
	
	while (base + regionLen > base) {
		const _ECVIMemoryRegion &region1 = [self regionContainingAddress:base];
		
		if (region1 != ECVIInvalidRegion) {
			base = region1.baseAddress + region1.length;
			continue;
		}
		const _ECVIMemoryRegion &region2 = [self regionContainingAddress:base + regionLen];
		
		if (region2 != ECVIInvalidRegion) {
			base = region2.baseAddress + region2.length;
			continue;
		}
		
		return base;
	}
	return ECVIInvalidRegionAddress;
}

@end
