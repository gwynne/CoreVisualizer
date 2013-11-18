//
//  ECVIMachOSymbol.h
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach-o/nlist.h>

@class ECVIMachOSection, ECVIMachOBinary;

typedef NS_ENUM(uint8_t, ECVISymbolGroup) {
	ECVISymbolGroupNone = 0,
	ECVISymbolGroupLocal,
	ECVISymbolGroupExternal,
	ECVISymbolGroupUndefined,
};

@interface ECVIMachOSymbol : NSObject

- (instancetype)initWithBinary:(ECVIMachOBinary *)binary symbol:(const struct nlist *)symbol idx:(uint32_t)nsym strings:(const char **)strings error:(NSError **)error;
- (instancetype)initWithBinary:(ECVIMachOBinary *)binary symbol64:(const struct nlist_64 *)symbol idx:(uint32_t)nsym strings:(const char **)strings error:(NSError **)error;

@property(nonatomic,readonly) ECVIMachOBinary *binary;
@property(nonatomic,readonly) NSString *rawName;
@property(nonatomic,readonly) NSString *unmangledName;
@property(nonatomic,readonly) uint32_t idx;
@property(nonatomic,readonly) uint64_t address;
@property(nonatomic,readonly) const void *codeStart;
@property(nonatomic,readonly) uint8_t type;
@property(nonatomic,readonly) bool isExternal;
@property(nonatomic,readonly) bool isPrivateExternal;
@property(nonatomic,readonly) ECVIMachOSection *section;
@property(nonatomic,readonly) uint8_t referenceFlags;
@property(nonatomic,readonly) bool isDynamicallyReferenced;
@property(nonatomic,readonly) uint8_t libraryOrdinal;
@property(nonatomic,readonly) bool isWeakDefinition;
@property(nonatomic,readonly) bool isWeakReference;
@property(nonatomic,readonly) bool isARMThumb;
@property(nonatomic,readonly) ECVISymbolGroup group;

@end
