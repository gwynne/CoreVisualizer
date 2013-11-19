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

@class ECVIMemoryMap;
@protocol ECVIMemoryMapDelegate;

@interface ECVIMemoryRegion : NSObject

- (instancetype)initWithInternalBackingOfLength:(uint64_t)length atAddress:(uint64_t)baseAddress name:(NSString *)name inMap:(ECVIMemoryMap *)map;
- (instancetype)initWithVirtualBackingOfLength:(uint64_t)length atAddress:(uint64_t)baseAddress name:(NSString *)name inMap:(ECVIMemoryMap *)map;
- (instancetype)initWithExternalBacking:(NSData *)backing atAddress:(uint64_t)baseAddress name:(NSString *)name inMap:(ECVIMemoryMap *)map;
- (instancetype)initWithMutableExternalBacking:(NSMutableData *)backing atAddress:(uint64_t)baseAddress name:(NSString *)name inMap:(ECVIMemoryMap *)map;

@property(nonatomic,readonly) ECVIMemoryMap *map;
@property(nonatomic,readonly) uint64_t baseAddress;
@property(nonatomic,readonly) uint64_t lastAddress;
@property(nonatomic,readonly) uint64_t length;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) NSData *backing;
@property(nonatomic,readonly) const uint8_t *bytes;
@property(nonatomic,readonly) const uint16_t *words;
@property(nonatomic,readonly) const uint32_t *longs;
@property(nonatomic,readonly) const uint64_t *quads;
@property(nonatomic,readonly) const __uint128_t *octets;
@property(nonatomic,readonly) NSMutableData *mutableBacking;
@property(nonatomic,readonly) uint8_t *mutableBytes;
@property(nonatomic,readonly) uint16_t *mutableWords;
@property(nonatomic,readonly) uint32_t *mutableLongs;
@property(nonatomic,readonly) uint64_t *mutableQuads;
@property(nonatomic,readonly) uint128_t *mutableOctets;

@end

@interface ECVIMemoryMap : NSObject

- (instancetype)initWithPageSize:(uint64_t)pageSize;

@property(nonatomic,weak) id<ECVIMemoryMapDelegate> delegate;
@property(nonatomic,assign) uint64_t pageSize;
@property(nonatomic,readonly) NSArray *regions;

- (ECVIMemoryRegion *)regionByName:(NSString *)name;

- (ECVIMemoryRegion *)mapInternalRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName;
- (ECVIMemoryRegion *)mapInternalRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName atAddress:(uint64_t)regionBase;
- (ECVIMemoryRegion *)mapVirtualRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName;
- (ECVIMemoryRegion *)mapVirtualRegionOfSize:(uint64_t)regionLen withName:(NSString *)regionName atAddress:(uint64_t)regionBase;
- (ECVIMemoryRegion *)mapExternalRegionWithBacking:(NSData *)backing withName:(NSString *)regionName;
- (ECVIMemoryRegion *)mapExternalRegionWithBacking:(NSData *)backing withName:(NSString *)regionName atAddress:(uint64_t)regionBase;
- (ECVIMemoryRegion *)mapExternalRegionWithMutableBacking:(NSMutableData *)backing withName:(NSString *)regionName;
- (ECVIMemoryRegion *)mapExternalRegionWithMutableBacking:(NSMutableData *)backing withName:(NSString *)regionName atAddress:(uint64_t)regionBase;

- (bool)unmapRegionAt:(uint64_t)regionBase unmappingMultiple:(bool)multiple;
- (bool)unmapRegion:(ECVIMemoryRegion *)region;

- (void)unmapAllRegions;

- (uint128_t)readValueOfLength:(uint64_t)length fromAddress:(uint64_t)address;
- (void)writeValue:(uint128_t)value ofLength:(uint64_t)length toAddress:(uint64_t)address;

@end

@protocol ECVIMemoryMapDelegate <NSObject>

@optional
- (void)memoryMap:(ECVIMemoryMap *)memoryMap didMapNewRegion:(ECVIMemoryRegion *)region;
- (void)memoryMap:(ECVIMemoryMap *)memoryMap didUnmapRegion:(ECVIMemoryRegion *)region;

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeReadFromAddress:(uint64_t)address ofSize:(uint64_t)writeLen ofValue:(uint128_t)value inRegion:(ECVIMemoryRegion *)region;
- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeWriteToAddress:(uint64_t)address ofSize:(uint64_t)writeLen ofValue:(uint128_t)value inRegion:(ECVIMemoryRegion *)region;

- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeReadFromUnmappedAddress:(uint64_t)address ofSize:(uint64_t)readLen;
- (void)memoryMap:(ECVIMemoryMap *)memoryMap didSeeWriteToUnmappedAddress:(uint64_t)address ofSize:(uint64_t)writeLen;

@end