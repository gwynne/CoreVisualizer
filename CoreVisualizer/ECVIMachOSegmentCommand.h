//
//  ECVIMachOSegmentCommand.h
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ECVIMachOLoadCommand.h"

@interface ECVIMachOSegmentCommand : ECVIMachOLoadCommand

@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) uint64_t loadAddress; // intended VM address
@property(nonatomic,readonly) uint64_t loadedSize;
@property(nonatomic,readonly) const uint8_t *segmentBase; // in actual memory
@property(nonatomic,readonly) vm_prot_t initialPermissions;
@property(nonatomic,readonly) vm_prot_t maximumPermissions;
@property(nonatomic,readonly) NSArray *sections;

@end

@interface ECVIMachOSection : NSObject

@property(nonatomic,readonly) ECVIMachOSegmentCommand *segment;
@property(nonatomic,readonly) NSString *name;
@property(nonatomic,readonly) uint64_t loadAddress; // intended VM address
@property(nonatomic,readonly) uint64_t loadedSize;
@property(nonatomic,readonly) const uint8_t *sectionBase; // in actual memory
@property(nonatomic,readonly) uint32_t alignment;
@property(nonatomic,readonly) uint32_t type;
@property(nonatomic,readonly) uint32_t attributes;
@property(nonatomic,readonly) uint32_t symbolIndex;
@property(nonatomic,readonly) uint32_t symbolSize;

@end
