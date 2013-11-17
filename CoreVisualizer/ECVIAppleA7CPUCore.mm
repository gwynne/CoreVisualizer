//
//  ECVIAppleA7CPUCore.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIAppleA7CPUCore.h"
#import "ECVIMemoryMap.h"

class ECVIARMv8Core {

	public:
		uint64_t pc;
		uint64_t sp;
		uint64_t x[31];
		__uint128_t v[32];
		uint32_t fpcr;
		uint32_t fpsr;
		bool n, z, c, vv;
		
		ECVIMemoryMap *map;
		id<ECVIGenericCPUCoreDelegate> __weak delegate;
		
		void reset(uint64_t startPC);
		void step(void);
};

@interface ECVIAppleA7CPUCore ()
@end

@implementation ECVIAppleA7CPUCore
{
	ECVIARMv8Core innerCore;
}

- (instancetype)initWithMemoryMap:(ECVIMemoryMap *)memoryMap
{
	if ((self = [super initWithMemoryMap:memoryMap])) {
		innerCore.map = memoryMap;
	}
	return self;
}

- (id<ECVIGenericCPUCoreDelegate>)delegate
{
	return innerCore.delegate;
}

- (void)setDelegate:(id<ECVIGenericCPUCoreDelegate>)delegate
{
	innerCore.delegate = delegate;
}

- (void)reset
{
	innerCore.reset(self.startPC);
}

- (void)step
{
	innerCore.step();
}

@end

void ECVIARMv8Core::reset(uint64_t startPC)
{
	pc = startPC;
	sp = 0;
	memset(x, 0, sizeof(x));
	memset(v, 0, sizeof(v));
	fpcr = 0x00000000;
	fpsr = 0x00000000;
	n = false;
	z = false;
	c = false;
	vv = false;
}

void ECVIARMv8Core::step()
{
	uint32_t opcode = [map readValueOfLength:sizeof(uint32_t) fromAddress:pc];
	
	if ((opcode & 0x7fe00000) == 0x1c0) { // adc
		uint32_t d = (opcode & 0x0000001f),
				 nn = (opcode & 0x000003e0) >> 5,
				 m = (opcode & 0x001f0000) >> 16;
		
		if ((opcode & 0x80000000)) {
			__uint128_t r = x[nn] + x[m] + !!c;
			
			x[d] = r & 0xffffffffffffffff;
			n = x[d] & 0x8000000000000000 ? true : false;
			z = x[d] == 0;
			c = r == x[d];
			vv = (__int128_t)r == (__int128_t)((int64_t)x[d]);
		}
	} else {
		NSLog(@"UNKNOWN OPCODE 0x%08x", opcode);
	}
	pc += 4;
}
