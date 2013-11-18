//
//  ECVIMachOFatBinary.h
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/17/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ECVIMachOBinary;

@interface ECVIMachOFatBinary : NSObject

- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;

@property(nonatomic,readonly) NSURL *url;
@property(nonatomic,readonly) NSArray *architectures;

- (ECVIMachOBinary *)binaryForCPUType:(cpu_type_t)type;
- (ECVIMachOBinary *)binaryForCPUType:(cpu_type_t)type subtype:(cpu_subtype_t)subtype;

@end
