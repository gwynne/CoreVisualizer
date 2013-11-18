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

- (NSString *)description
{
	NSMutableString *desc = @"".mutableCopy;
	
	[desc appendFormat:@"%@ <resets to 0x%016llx>\n", self.class, self.startPC];
	[desc appendFormat:@"Register state:\n"];
	[desc appendFormat:@"x0:  %016llx     x1:  %016llx     x2:  %016llx     x3:  %016llx\n", innerCore.x[0], innerCore.x[1], innerCore.x[2], innerCore.x[3]];
	[desc appendFormat:@"x4:  %016llx     x5:  %016llx     x6:  %016llx     x7:  %016llx\n", innerCore.x[4], innerCore.x[5], innerCore.x[6], innerCore.x[7]];
	[desc appendFormat:@"x8:  %016llx     x9:  %016llx     x10: %016llx     x11: %016llx\n", innerCore.x[8], innerCore.x[9], innerCore.x[10], innerCore.x[11]];
	[desc appendFormat:@"x12: %016llx     x13: %016llx     x14: %016llx     x15: %016llx\n", innerCore.x[12], innerCore.x[13], innerCore.x[14], innerCore.x[15]];
	[desc appendFormat:@"x16: %016llx     x17: %016llx     x18: %016llx     x19: %016llx\n", innerCore.x[16], innerCore.x[17], innerCore.x[18], innerCore.x[19]];
	[desc appendFormat:@"x20: %016llx     x21: %016llx     x22: %016llx     x23: %016llx\n", innerCore.x[20], innerCore.x[21], innerCore.x[22], innerCore.x[23]];
	[desc appendFormat:@"x24: %016llx     x25: %016llx     x26: %016llx     x27: %016llx\n", innerCore.x[24], innerCore.x[25], innerCore.x[26], innerCore.x[27]];
	[desc appendFormat:@"x28: %016llx  x29/fp: %016llx  x30/lr: %016llx     x31: %016llx\n", innerCore.x[28], innerCore.x[29], innerCore.x[30], 0ULL];
	[desc appendFormat:@" sp: %016llx      pc: %016llx    nzcv: %01x\n",					 innerCore.sp, innerCore.pc, (innerCore.n << 3) | (innerCore.z << 2) | (innerCore.c << 1) | innerCore.vv];
	for (uint32_t i = 0; i < 32; i += 2) {
		[desc appendFormat:@"v%u:%s %016llx%016llx    v%u:%s %016llx%016llx\n",
			   i, i > 9 ? "" : " ", (uint64_t)(innerCore.v[i] >> 64), (uint64_t)(innerCore.v[i] & ((__uint128_t)UINT64_MAX)),
			   i + 1, (i + 1) > 9 ? "" : " ", (uint64_t)(innerCore.v[i + 1] >> 64), (uint64_t)(innerCore.v[i + 1] & ((__uint128_t)UINT64_MAX))];
	}
	[desc appendFormat:@"fpsr: %08x                           fpcr: %08x\n", innerCore.fpsr, innerCore.fpcr];
	return desc;
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
