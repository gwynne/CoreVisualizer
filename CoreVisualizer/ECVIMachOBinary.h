//
//  ECVIMachOBinary.h
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <map>

#define LoadError(rval, message) ({ if (error) *error = [NSError errorWithDomain:@"ECVIMachOLoadingErrorDomain_" __FILE__ code:__COUNTER__ userInfo:@{ NSLocalizedDescriptionKey: message }]; rval; })

@class ECVIMachOLoadCommand, ECVIMachOSymbol, ECVIMachOEntryCommand, ECVIMachOSegmentCommand, EVCIMachODynamicInfoCommands;

@interface ECVIMachOBinary : NSObject

- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;

@property(nonatomic,readonly) NSURL *url;
@property(nonatomic,readonly) const void *loadAddress;
@property(nonatomic,readonly) uint32_t type;
@property(nonatomic,readonly) cpu_type_t cputype;
@property(nonatomic,readonly) cpu_subtype_t cpusubtype;
@property(nonatomic,readonly) bool is64Bit;
@property(nonatomic,readonly) NSArray *loadCommandList;
@property(nonatomic,readonly) NSArray *segments;
@property(nonatomic,readonly) NSArray *sections; // combined array from all segments
@property(nonatomic,readonly) ECVIMachOSegmentCommand *textSegment;
@property(nonatomic,readonly) NSUUID *uuid;
@property(nonatomic,readonly) std::map<NSString *, ECVIMachOSymbol *> symbolTable;

- (ECVIMachOLoadCommand *)loadCommandOfType:(uint32_t)type;
- (NSArray *)loadCommandsOfType:(uint32_t)type;

- (ECVIMachOSegmentCommand *)segmentNamed:(NSString *)segname;

- (ECVIMachOSymbol *)lookupSymbolUsingAddress:(uint64_t)address exactMatch:(bool)exact symtableOnly:(bool)noExtraInfo;

@end
