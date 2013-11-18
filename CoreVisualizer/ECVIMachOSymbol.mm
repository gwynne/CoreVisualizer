//
//  ECVIMachOSymbol.mm
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import "ECVIMachOSymbol.h"
#import "ECVIMachOBinary.h"
#import "ECVIMachOSegmentCommand.h"

@interface ECVIMachOSymbol ()
@property(nonatomic,readwrite,weak) ECVIMachOBinary *binary;
@property(nonatomic,readwrite,weak) ECVIMachOSection *section;
@end

@implementation ECVIMachOSymbol

- (instancetype)initWithBinary:(ECVIMachOBinary *)binary symbol:(const struct nlist *)symbol idx:(uint32_t)nsym strings:(const char **)strings error:(NSError *__autoreleasing *)error
{
	return [self initWithBinary:binary strx:symbol->n_un.n_strx type:symbol->n_type sect:symbol->n_sect desc:symbol->n_desc value:symbol->n_value idx:nsym strings:strings error:error];
}

- (instancetype)initWithBinary:(ECVIMachOBinary *)binary symbol64:(const struct nlist_64 *)symbol idx:(uint32_t)nsym strings:(const char **)strings error:(NSError *__autoreleasing *)error
{
	return [self initWithBinary:binary strx:symbol->n_un.n_strx type:symbol->n_type sect:symbol->n_sect desc:symbol->n_desc value:symbol->n_value idx:nsym strings:strings error:error];
}

- (instancetype)initWithBinary:(ECVIMachOBinary *)binary strx:(uint32_t)n_strx type:(uint8_t)n_type sect:(uint8_t)n_sect desc:(uint16_t)n_desc value:(uint64_t)n_value
				idx:(uint32_t)nsym strings:(const char **)strings error:(NSError * __autoreleasing *)error
{
	if ((self = [super init])) {
		if ((n_type & N_STAB) != 0) {
			return LoadError(nullptr, @"Can't load STABS symbols yet!");
		}
		_binary = binary;
		_rawName = [NSString stringWithUTF8String:reinterpret_cast<const char *>(strings) + n_strx];
		_unmangledName = _rawName.copy;
		_idx = nsym;
		_address = n_value;
		_codeStart = reinterpret_cast<const uint8_t *>(binary.textSegment.loadAddress) + _address;
		_type = n_type & N_TYPE;
		_isExternal = (n_type & N_EXT) ? true : false;
		_isPrivateExternal = (n_type & N_PEXT) ? true : false;
		_section = (n_sect == NO_SECT ? nil : binary.textSegment.sections[n_sect - 1]);
		_referenceFlags = (n_desc & REFERENCE_TYPE);
		_isDynamicallyReferenced = (n_desc & REFERENCED_DYNAMICALLY) ? true : false;
		_libraryOrdinal = GET_LIBRARY_ORDINAL(n_desc);
		_isWeakDefinition = (n_desc & N_WEAK_REF) ? true : false;
		_isWeakReference = (n_desc & N_REF_TO_WEAK) ? true : false;
		_isARMThumb = (n_desc & N_ARM_THUMB_DEF) ? true : false;
		
		ECVIMachOLoadCommand *dysymtab = [binary loadCommandOfType:LC_DYSYMTAB];
		
		if (!dysymtab) {
			_group = ECVISymbolGroupNone;
		} else {
			const struct dysymtab_command *dysymtabcmd = reinterpret_cast<const struct dysymtab_command *>(dysymtab.baseCommand);
			
			if (dysymtabcmd->ilocalsym <= _idx && dysymtabcmd->ilocalsym + dysymtabcmd->nlocalsym >= _idx)
				_group = ECVISymbolGroupLocal;
			else if (dysymtabcmd->iextdefsym <= _idx && dysymtabcmd->iextdefsym + dysymtabcmd->nextdefsym >= _idx)
				_group = ECVISymbolGroupExternal;
			else if (dysymtabcmd->iundefsym <= _idx && dysymtabcmd->iundefsym + dysymtabcmd->nundefsym >= _idx)
				_group = ECVISymbolGroupUndefined;
			else
				_group = ECVISymbolGroupNone;
		}
	}
	return self;
}

@end
