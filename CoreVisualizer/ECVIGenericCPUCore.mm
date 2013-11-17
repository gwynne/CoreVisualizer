//
//  ECVIGenericCPUCore.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIGenericCPUCore.h"

@interface ECVIGenericCPUCore ()
@property(nonatomic,strong) ECVIMemoryMap *memoryMap;
@end

@implementation ECVIGenericCPUCore

- (instancetype)initWithMemoryMap:(ECVIMemoryMap *)memoryMap
{
	if ((self = [super init])) {
		_memoryMap = memoryMap;
	}
	return self;
}

- (void)reset
{
	NSAssert(NO, @"Must be implemented by subclasses.");
}

- (void)step
{
	NSAssert(NO, @"Must be implemented by subclasses.");
}

@end
