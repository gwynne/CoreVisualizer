//
//  ECVIInstance.h
//  CoreVisualizer
//
//  Created by Gwynne Raskind on 11/16/13.
//  Copyright (c) 2013 Elwea Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ECVIInstance : NSObject

- (void)reset;
- (bool)loadBinary:(NSURL *)binary error:(NSError **)error;
- (void)stepOne;

@end
