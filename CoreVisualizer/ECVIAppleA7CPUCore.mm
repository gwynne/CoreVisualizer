//
//  ECVIAppleA7CPUCore.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIAppleA7CPUCore.h"
#import "ECVIMemoryMap.h"

static const uint32_t R_x[32] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32 },
					  R_sp = 32, R_pc = 33, R_nzcv = 34,
					  R_v[32] = { 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66 },
					  R_fpsr = 67, R_fpcr = 68;

#define getRegister(reg, wantsp) ({	\
	uint64_t v = 0;	\
	if (R_ ## reg == 32)/*sp!*/	{ \
		if (wantsp) v = sp;	\
	} else {	\
		v = reg;	\
	}	\
	v;	\
})
#define updateRegister(reg, value, wantsp) do {	\
	if (R_ ## reg == 32)/*sp!*/	{ \
		if (wantsp) sp = value;	\
	} else {	\
		reg = value;	\
	}	\
	if (delegateCares && (R_ ## reg != 32 || wantsp))	\
		[delegate CPUcore:outerCore didUpdateRegister:R_ ## reg toValue:R_ ## reg == 32 ? sp : reg];	\
} while (0)
#define updateFlags(n_, z_, c_, v_) do {	\
	n = n_; z = z_; c = c_; vv = v_;	\
	if (delegateCares)	\
		[delegate CPUcore:outerCore didUpdateRegister:R_nzcv toValue:(n << 3) | (z << 2) | (c << 1) | vv];	\
} while (0)

#define OPCODE(...) union { uint32_t opcode; struct { __VA_ARGS__ } bits; } op = { .opcode = opcode }
#define OU(nm, n) uint32_t nm:n
#define OS(nm, n) int32_t nm:n
#define __OR(n,c) uint32_t res ## c:n
#define _OR(n,c) __OR(n, c)
#define OR(n) _OR(n, __COUNTER__)

class ECVIARMv8Core {

	public:
		uint64_t pc;
		uint64_t sp;
		uint64_t x[31];
		uint128_t v[32];
		uint32_t fpcr;
		uint32_t fpsr;
		bool n, z, c, vv;
		
		ECVIAppleA7CPUCore *outerCore;
		ECVIMemoryMap *map;
		bool delegateCares;
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
		innerCore.outerCore = self;
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
	innerCore.delegateCares = [innerCore.delegate respondsToSelector:@selector(CPUcore:didUpdateRegister:toValue:)];
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
			   i + 0, (i + 0) > 9 ? "" : " ", (uint64_t)(innerCore.v[i + 0] >> 64), (uint64_t)(innerCore.v[i + 0] & ((uint128_t)UINT64_MAX)),
			   i + 1, (i + 1) > 9 ? "" : " ", (uint64_t)(innerCore.v[i + 1] >> 64), (uint64_t)(innerCore.v[i + 1] & ((uint128_t)UINT64_MAX))];
	}
	[desc appendFormat:@"fpsr: %08x                           fpcr: %08x\n", innerCore.fpsr, innerCore.fpcr];
	return desc;
}

- (uint32_t)numRegisters
{
	return 32/*gpr*/ + 3/*sp,pc,nzcv*/ + 32/*fpr*/ + 2/*fpsr,fpcr*/;
}

- (NSString *)nameForRegister:(uint32_t)rnum
{
	static NSString * const registerNames[] = {
		@"x0", @"x1", @"x2", @"x3", @"x4", @"x5", @"x6", @"x7", @"x8", @"x9", @"x10", @"x11", @"x12", @"x13", @"x14", @"x15", @"x16", @"x17", @"x18", @"x19", @"x20",
		@"x21", @"x22", @"x23", @"x24", @"x25", @"x26", @"x27", @"x28", @"fp", @"lr", @"zr", @"sp", @"pc", @"nzcv", @"v0", @"v1", @"v2", @"v3", @"v4", @"v5", @"v6",
		@"v7", @"v8", @"v9", @"v10", @"v11", @"v12", @"v13", @"v14", @"v15", @"v16", @"v17", @"v18", @"v19", @"v20", @"v21", @"v22", @"v23", @"v24", @"v25", @"v26",
		@"v27", @"v28", @"v29", @"v30", @"v31", @"fpsr", @"fpcr"
	};
	
	return rnum < self.numRegisters ? registerNames[rnum] : nil;
}

- (NSString *)nameForRegister:(uint32_t)rnum sized:(uint32_t)s sp:(bool)wantsp
{
	if (rnum == 31) {
		return wantsp ? @"sp" : @"zr";
	} else if (rnum < 32) {
		if (s == 4)
			return [[self nameForRegister:rnum] stringByReplacingOccurrencesOfString:@"x" withString:@"w"];
		else
			return [self nameForRegister:rnum];
	} else if (rnum == 32 || rnum == 33 || rnum == 34 || rnum == 67 || rnum == 68)
		return [self nameForRegister:rnum];
	else {
		static NSString * const p[] = { @"b", @"h", @"s", @"d", @"q" };
		
		return [[self nameForRegister:rnum] stringByReplacingOccurrencesOfString:@"v" withString:p[__builtin_ctz(s)]];
	}
}

- (uint64_t)sizeOfRegister:(uint32_t)rnum
{
	return (rnum < 34/*gpr,sp,pc*/ ? 8 : (rnum == 34/*nzcv*/ ? 1 : (rnum < 67/*fpr*/ ? 16 : (rnum < 69/*fpsr,fpcr*/ ? 4 : 0))));
}

- (uint128_t)valueForRegister:(uint32_t)rnum
{
	if (rnum < 32) {
		return innerCore.x[rnum];
	} else if (rnum == 32) {
		return innerCore.sp;
	} else if (rnum == 33) {
		return innerCore.pc;
	} else if (rnum == 34) {
		return (innerCore.n << 3) | (innerCore.z << 2) | (innerCore.c << 1) | innerCore.vv;
	} else if (rnum < 67) {
		return innerCore.v[rnum - 35];
	} else if (rnum == 67) {
		return innerCore.fpsr;
	} else if (rnum == 68) {
		return innerCore.fpcr;
	} else {
		return 0;
	}
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
	
	if ((opcode & 0x7fe00000) == 0x1c000000 || (opcode & 0x7fe00000) == 0x3c00000) { // adc
		uint32_t d = (opcode & 0x0000001f),
				 nn = (opcode & 0x000003e0) >> 5,
				 m = (opcode & 0x001f0000) >> 16,
				 S = (opcode & 0x20000000) >> 29,
				 sf = (opcode >> 31);
		
		if (sf) {
			uint128_t r = getRegister(x[nn], false) + getRegister(x[m], false) + !!c;
			
			NSLog(@"%@ %@, %@, %@", S ? @"adcs" : @"adc", [outerCore nameForRegister:d sized:8 sp:false], [outerCore nameForRegister:nn sized:8 sp:false], [outerCore nameForRegister:m sized:8 sp:false]);
			updateRegister(x[d], r & 0xffffffffffffffff, false);
			if (S) {
				updateFlags(getRegister(x[d], false) & 0x8000000000000000 ? true : false,
							getRegister(x[d], false) == 0,
							r == getRegister(x[d], false),
							(int128_t)r == (int128_t)((int64_t)getRegister(x[d], false))
				);
			}
		} else {
			uint64_t r = (getRegister(x[nn], false) & 0x00000000ffffffff) + (getRegister(x[m], false) & 0x00000000ffffffff) + !!c;
			
			NSLog(@"%@ %@, %@, %@", S ? @"adcs" : @"adc", [outerCore nameForRegister:d sized:4 sp:false], [outerCore nameForRegister:nn sized:4 sp:false], [outerCore nameForRegister:m sized:4 sp:false]);
			updateRegister(x[d], (getRegister(x[d], false) & 0xffffffff00000000) | (r & 0x00000000ffffffff), false);
			if (S) {
				updateFlags(getRegister(x[d], false) & 0x0000000080000000 ? true : false,
							(getRegister(x[d], false) & 0x00000000ffffffff) == 0,
							r == (getRegister(x[d], false) & 0x00000000ffffffff),
							(int64_t)r == (int64_t)(getRegister(x[d], false) & 0x00000000ffffffff)
				);
			}
		}
	} else if ((opcode & 0x7f000000) == 0x11000000 || (opcode & 0x7f000000) == 0x31000000) { // add, adds
		uint32_t d = (opcode & 0x0000001f),
				 nn = (opcode & 0x000003e0) >> 5,
				 imm = (opcode & 0x003ffc00) >> 10,
				 shift = (opcode & 0x0c000000) >> 22,
				 S = (opcode & 0x20000000) >> 29,
				 sf = (opcode >> 31);
		
		if (shift == 1)
			imm <<= 12;
		if (sf) {
			uint128_t r = getRegister(x[nn], !S) + (uint64_t)imm;
			
			NSLog(@"%@ %@, %@, #%u%@", S ? @"adds" : @"add", [outerCore nameForRegister:d sized:8 sp:!S], [outerCore nameForRegister:nn sized:8 sp:!S], imm, shift ? @", 1" : @"");
			updateRegister(x[d], r & 0xffffffffffffffff, !S);
			if (S) {
				updateFlags(getRegister(x[d], !S) & 0x8000000000000000 ? true : false,
							getRegister(x[d], !S) == 0,
							r == getRegister(x[d], !S),
							(int128_t)r == (int128_t)((int64_t)getRegister(x[d], false))
				);
			}
		} else {
			uint64_t r = (getRegister(x[nn], !S) & 0x00000000ffffffff) + (uint32_t)(imm & 0x00000000ffffffff);
			
			NSLog(@"%@ %@, %@, #%u%@", S ? @"adds" : @"add", [outerCore nameForRegister:d sized:4 sp:!S], [outerCore nameForRegister:nn sized:4 sp:!S], imm, shift ? @", 1" : @"");
			updateRegister(x[d], (getRegister(x[d], !S) & 0xffffffff00000000) | (r & 0x00000000ffffffff), !S);
			if (!S) {
				updateFlags(getRegister(x[d], false) & 0x0000000080000000 ? true : false,
							(getRegister(x[d], false) & 0x00000000ffffffff) == 0,
							r == (getRegister(x[d], false) & 0x00000000ffffffff),
							(int64_t)r == (int64_t)(getRegister(x[d], false) & 0x00000000ffffffff)
				);
			}
		}
	} else if ((opcode & 0xbf000000) == 0x18000000) { // ldr imm
		OPCODE( OU(t, 5); OU(imm, 19); OR(6); OU(sf, 1); OR(1); );
		uint64_t offset = op.bits.imm << 2,
				 addr = getRegister(pc, false) + offset;
		
		NSLog(@"ldr %@, [+0x%llx]", [outerCore nameForRegister:op.bits.t sized:1 << (2 + op.bits.sf) sp:false], offset);
		if (op.bits.sf) {
			updateRegister(x[op.bits.t], [map readValueOfLength:1 << (2 + op.bits.sf) fromAddress:addr], false);
		} else {
			updateRegister(x[op.bits.t], (getRegister(x[op.bits.t], false) & 0xffffffff00000000) | [map readValueOfLength:sizeof(uint32_t) fromAddress:addr], false);
		}
	} else if ((opcode & 0xfffffc1f) == 0xd61f0000) { // br
		OPCODE( OR(5); OU(n, 5); OR(22); );
		
		NSLog(@"br [%@]", [outerCore nameForRegister:op.bits.n sized:8 sp:false]);
		updateRegister(pc, getRegister(x[op.bits.n], false) - 4, false);
	} else if ((opcode & 0x7e400000) == 0x28000000) { // stp
		OPCODE( OU(rt1, 5); OU(rn, 5); OU(rt2, 5); OS(imm, 7); OR(1); OU(wback, 1); OU(preindex, 1); OR(6); OU(sf, 1); );
		
		if (op.bits.preindex) {
			NSLog(@"stp %@, %@, [%@, #%d]%s", [outerCore nameForRegister:op.bits.rt1 sized:2 << op.bits.sf sp:false], [outerCore nameForRegister:op.bits.rt2 sized:2 << op.bits.sf sp:false],
											  [outerCore nameForRegister:op.bits.rn sized:2 << op.bits.sf sp:true], op.bits.imm << (2 + op.bits.sf), op.bits.wback ? "!" : "");
		} else {
			NSLog(@"stp %@, %@, [%@], #%d", [outerCore nameForRegister:op.bits.rt1 sized:2 << op.bits.sf sp:false], [outerCore nameForRegister:op.bits.rt2 sized:2 << op.bits.sf sp:false],
											[outerCore nameForRegister:op.bits.rn sized:2 << op.bits.sf sp:true], op.bits.imm << (2 + op.bits.sf));
		}
		[map writeValue:getRegister(x[op.bits.rt1], false) ofLength:8 toAddress:getRegister(x[op.bits.rn], true) + ((op.bits.imm << (2 + op.bits.sf)) * op.bits.preindex)];
		[map writeValue:getRegister(x[op.bits.rt2], false) ofLength:8 toAddress:getRegister(x[op.bits.rn], true) + ((op.bits.imm << (2 + op.bits.sf)) * op.bits.preindex) + (4 << op.bits.sf)];
		if (op.bits.wback)
			updateRegister(x[op.bits.rn], getRegister(x[op.bits.rn], true) + (op.bits.imm << (2 << op.bits.sf)), true);
	} else {
		NSLog(@"UNKNOWN OPCODE 0x%08x", opcode);
	}
	updateRegister(pc, pc + 4, false);
}
