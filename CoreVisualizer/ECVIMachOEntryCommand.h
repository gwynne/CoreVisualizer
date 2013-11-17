//
//  ECVIMachOEntryCommand.h
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ECVIMachOLoadCommand.h"

@interface ECVIMachOEntryCommand : ECVIMachOLoadCommand

@property(nonatomic,readonly) uint64_t entryAddress;
@property(nonatomic,readonly) uint64_t initialStackSize;

@end
