//
//  ECVIMachOLoadCommand.h
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach-o/loader.h>

@class ECVIMachOBinary;

@interface ECVIMachOLoadCommand : NSObject

- (instancetype)initWithCommandInFile:(ECVIMachOBinary *)binary fromCmdAt:(const struct load_command *)cmd error:(NSError **)error;
- (void)awakeFromBinary;

@property(nonatomic,readonly) ECVIMachOBinary *binary;
@property(nonatomic,readonly) uint32_t type;
@property(nonatomic,readonly) uint64_t size;
@property(nonatomic,readonly) const struct load_command *baseCommand;

// for subclasses only
- (instancetype)initWithBinary:(ECVIMachOBinary *)binary type:(uint32_t)type size:(uint64_t)size cmd:(const struct load_command *)cmd error:(NSError **)error;

@end
