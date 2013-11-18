//
//  ECVIMemoryMap.h
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <set>

const uint64_t ECVIInvalidRegionAddress = UINT64_MAX;

struct ECVIMemoryRegion {
	uint64_t baseAddress;
	uint64_t length;
	NSString *name;
};

typedef void *__ECVIMemoryRegionIteratorInternal;
class ECVIMemoryRegionIterator : public std::iterator<std::bidirectional_iterator_tag, const ECVIMemoryRegion> {
	private:
		__ECVIMemoryRegionIteratorInternal internal;
	public:
		ECVIMemoryRegionIterator(void);
		ECVIMemoryRegionIterator(__ECVIMemoryRegionIteratorInternal internal_);
		ECVIMemoryRegionIterator(const ECVIMemoryRegionIterator &i);
		~ECVIMemoryRegionIterator();
		ECVIMemoryRegionIterator &operator++(void);
		ECVIMemoryRegionIterator operator++(int);
		ECVIMemoryRegionIterator &operator--(void);
		ECVIMemoryRegionIterator operator--(int);
		bool operator==(const ECVIMemoryRegionIterator &i) const;
		bool operator!=(const ECVIMemoryRegionIterator &i) const;
		reference operator*(void) const;
};

@protocol ECVIMemoryMapDelegate;

@interface ECVIMemoryMap : NSObject

- (instancetype)initWithPageSize:(uint64_t)pageSize;

@property(nonatomic,weak) id<ECVIMemoryMapDelegate> delegate;
@property(nonatomic,assign) uint64_t pageSize;
@property(nonatomic,assign) ECVIMemoryRegionIterator regionsBegin, regionsEnd;

- (const ECVIMemoryRegion &)regionByName:(NSString *)name;

- (const ECVIMemoryRegion &)mapRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName;
- (const ECVIMemoryRegion &)mapRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName atAddress:(uint64_t)regionBase empty:(bool)emptyRegion;

- (bool)unmapRegionAt:(uint64_t)regionBase unmappingMultiple:(bool)multiple;
- (bool)unmapRegion:(const ECVIMemoryRegion &)region;

- (uint64_t)readValueOfLength:(uint64_t)length fromAddress:(uint64_t)address;
- (void)writeValue:(uint64_t)value ofLength:(uint64_t)length toAddress:(uint64_t)address;

@end

@protocol ECVIMemoryMapDelegate <NSObject>

@optional
- (void)memoryMap:(ECVIMemoryMap *)memoryMap didMapNewRegion:(const ECVIMemoryRegion &)region;
- (void)memoryMap:(ECVIMemoryMap *)memoryMap didUnmapRegion:(const ECVIMemoryRegion &)region;

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeReadFromAddress:(uint64_t)address ofSize:(uint64_t)writeLen ofValue:(uint64_t)value inRegion:(const ECVIMemoryRegion &)region;
- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeWriteToAddress:(uint64_t)address ofSize:(uint64_t)writeLen ofValue:(uint64_t)value inRegion:(const ECVIMemoryRegion &)region;

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeReadFromUnmappedAddress:(uint64_t)address ofSize:(uint64_t)writeLen;
- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeWriteToUnmappedAddress:(uint64_t)address ofSize:(uint64_t)writeLen;

@end