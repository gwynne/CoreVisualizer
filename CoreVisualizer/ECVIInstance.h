//
//  ECVIInstance.h
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ECVIGenericCPUCore.h"
#import "ECVIMemoryMap.h"

@protocol ECVIInstanceDelegate <ECVIGenericCPUCoreDelegate, ECVIMemoryMapDelegate>
@end

@interface ECVIInstance : NSObject

@property(nonatomic,readonly) ECVIGenericCPUCore *core;
@property(nonatomic,readonly) ECVIMemoryMap *map;
@property(nonatomic,weak) id<ECVIInstanceDelegate> delegate;
- (void)reset;
- (bool)loadBinary:(NSURL *)binary error:(NSError **)error;
- (void)stepOne;

@end
