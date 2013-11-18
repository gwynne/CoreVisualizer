//
//  ECVIMachOFatBinary.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIMachOFatBinary.h"
#import "ECVIMachOBinary.h"
#import <mach-o/fat.h>
#import <mach-o/loader.h>

@implementation ECVIMachOFatBinary
{
	NSData *_fileData;
}

- (instancetype)initWithURL:(NSURL *)url error:(NSError * __autoreleasing *)error
{
	if ((self = [super init])) {
		_url = url;
		if (![self loadAndReturnError:error])
			return nil;
	}
	return self;
}

- (bool)loadAndReturnError:(NSError * __autoreleasing *)error
{
	if (!(_fileData = [NSData dataWithContentsOfURL:_url options:NSDataReadingMappedAlways error:error]))
		return false;

	const struct fat_header *header = reinterpret_cast<const struct fat_header *>(_fileData.bytes);
	int64_t nfat_arch = 0;
	
	if (header->magic == FAT_MAGIC || header->magic == FAT_CIGAM) {
		nfat_arch = NSSwapBigIntToHost(header->nfat_arch);
	} else if (header->magic == MH_MAGIC || header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM || header->magic == MH_CIGAM_64) {
		nfat_arch = -1;
	} else {
		return LoadError(false, @"Not a fat or thin Mach-O binary!");
	}
	
	if (nfat_arch == -1) { // it's a plain Mach-O binary
		ECVIMachOBinary *binary = [[ECVIMachOBinary alloc] initWithData:_fileData basedOnURL:_url error:error];
		
		if (!binary)
			return false;
		_architectures = @[binary];
	} else {
		const struct fat_arch *arch = reinterpret_cast<const struct fat_arch *>(header + 1);
		NSMutableArray *archs = @[].mutableCopy;
		
		for (int64_t narch = 0; narch < nfat_arch; ++narch, ++arch) {
			NSData *subdata = [_fileData subdataWithRange:(NSRange){ NSSwapBigIntToHost(arch->offset), NSSwapBigIntToHost(arch->size) }];
			ECVIMachOBinary *binary = [[ECVIMachOBinary alloc] initWithData:subdata basedOnURL:_url error:error];
			
			if (!binary)
				return false;
			[archs addObject:binary];
		}
		_architectures = archs;
	}
	return true;
}

- (ECVIMachOBinary *)binaryForCPUType:(cpu_type_t)type
{
	return [self binaryForCPUType:type subtype:CPU_SUBTYPE_MULTIPLE];
}

- (ECVIMachOBinary *)binaryForCPUType:(cpu_type_t)type subtype:(cpu_subtype_t)subtype
{
	return _architectures[[_architectures indexOfObjectPassingTest:^ BOOL (ECVIMachOBinary *binary, NSUInteger idx, BOOL *stop) {
		if (type == CPU_TYPE_ANY && subtype == CPU_SUBTYPE_MULTIPLE)
			return (*stop = YES);
		else if (type == CPU_TYPE_ANY)
			return (*stop = (binary.cpusubtype == subtype));
		else if (subtype == CPU_SUBTYPE_MULTIPLE)
			return (*stop = (binary.cputype == type));
		else
			return (*stop = (binary.cputype == type && binary.cpusubtype == subtype));
	}]];
}

@end
