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
#import <vector>

@interface ECVIInstance () <ECVIMemoryMapDelegate, ECVIGenericCPUCoreDelegate>
@end

@implementation ECVIInstance
{
	ECVIAppleA7CPUCore *_core;
	ECVIMemoryMap *_map;
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
	std::vector<const ECVIMemoryRegion *> regions;
	
	for (auto i = _map.regionsBegin; i != _map.regionsEnd; ++i) {
		regions.push_back(&(*i));
	}
	for (auto i = regions.begin(); i != regions.end(); ++i) {
		[_map unmapRegion:*(*i)];
	}
	
	[_core reset];
	[_map mapRegionOfSize:4096 withName:@"__PAGEZERO"];
	[_map mapRegionOfSize:1048576 withName:@"__STACK"];
}

- (bool)loadBinary:(NSURL *)binary error:(NSError * __autoreleasing *)error
{

}

@end
