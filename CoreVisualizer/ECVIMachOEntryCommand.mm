//
//  ECVIMachOEntryCommand.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIMachOEntryCommand.h"
#import "ECVIMachOBinary.h"

struct arch_thread_command {
	uint32_t cmd;
	uint32_t cmdsize;
	uint32_t flavor;
	uint32_t count;
	union {
		struct {
			uint32_t eax, ebx, ecx, edx, edi, esi, ebp, esp, ss, eflags, eip,
					 cs, ds, es, fs, gs;
		} x86_thread_state;
		struct {
			uint64_t rax, rbx, rcx, rdx, rdi, rsi, rbp, rsp, r8, r9, r10, r11,
					 r12, r13, r14, r15, rip, rflags, cs, fs, gs;
		} x86_64_thread_state;
		struct {
			uint32_t r[13], sp, lr, pc, cpsr;
		} arm_thread_state;
		struct {
			uint64_t x[29], fp, lr, sp, pc;
			uint32_t cpsr;
		} arm64_thread_state;
	} state;
};

enum {
	ECVI_ThreadFlavor_x86 = 1, // x86_THREAD_STATE32
	ECVI_ThreadFlavor_x86_64 = 4, // x86_THREAD_STATE64
	ECVI_ThreadFlavor_arm = 1, // ARM_THREAD_STATE
	ECVI_ThreadFlavor_arm64 = 6, // ARM_THREAD_STATE64
};

@implementation ECVIMachOEntryCommand

- (instancetype)initWithCommandInFile:(ECVIMachOBinary *)binary fromCmdAt:(const struct load_command *)cmd error:(NSError *__autoreleasing *)error
{
	NSAssert(cmd->cmd == LC_THREAD || cmd->cmd == LC_UNIXTHREAD || cmd->cmd == LC_MAIN, @"Must be a thread, unix thread, or entry point command.");
	
	if ((self = [super initWithBinary:binary type:LC_MAIN size:cmd->cmdsize cmd:cmd error:error])) {
		if (cmd->cmd == LC_THREAD || cmd->cmd == LC_UNIXTHREAD) {
			const struct arch_thread_command *realcmd = reinterpret_cast<const struct arch_thread_command *>(cmd);
			
			if ((binary.cputype & ~CPU_ARCH_MASK) == CPU_TYPE_X86 && realcmd->flavor == ECVI_ThreadFlavor_x86) {
				_entryAddress = realcmd->state.x86_thread_state.eip;
				_initialStackSize = 65536;
			} else if ((binary.cputype & ~CPU_ARCH_MASK) == CPU_TYPE_X86 && realcmd->flavor == ECVI_ThreadFlavor_x86_64) {
				_entryAddress = realcmd->state.x86_64_thread_state.rip;
				_initialStackSize = 1048576;
			} else if ((binary.cputype & ~CPU_ARCH_MASK) == CPU_TYPE_ARM && realcmd->flavor == ECVI_ThreadFlavor_arm) {
				_entryAddress = realcmd->state.arm_thread_state.pc;
				_initialStackSize = 32768;
			} else if ((binary.cputype & ~CPU_ARCH_MASK) == CPU_TYPE_ARM && realcmd->flavor == ECVI_ThreadFlavor_arm64) {
				_entryAddress = realcmd->state.arm64_thread_state.pc;
				_initialStackSize = 65536;
			} else {
				return nil;
			}
		} else if (cmd->cmd == LC_MAIN) {
			const struct entry_point_command *realcmd = reinterpret_cast<const struct entry_point_command *>(cmd);
			
			_entryAddress = realcmd->entryoff;
			_initialStackSize = (realcmd->stacksize > 0) ? realcmd->stacksize : 1048576;
		}
	}
	return self;
}

- (void)awakeFromBinary
{
	[super awakeFromBinary];
	if (self.baseCommand->cmd == LC_MAIN) {
		_entryAddress += self.binary.textVMAddr;
	}
}

@end
