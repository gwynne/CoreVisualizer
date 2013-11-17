//
//  ECVIGenericCPUCore.h
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ECVIGenericCPUCoreDelegate;
@class ECVIMemoryMap;

@interface ECVIGenericCPUCore : NSObject

- (instancetype)initWithMemoryMap:(ECVIMemoryMap *)memoryMap;

@property(nonatomic,weak) id<ECVIGenericCPUCoreDelegate> delegate;
@property(nonatomic,assign) uint64_t startPC;

- (void)reset;
- (void)step;

@end

@protocol ECVIGenericCPUCoreDelegate <NSObject>

@optional
- (void)CPUcore:(ECVIGenericCPUCore *)core didUpdateRegister:(uint32_t)rnum toValue:(uint64_t)value;

@end
