//
//  NSObject+KVO.h
//  KVO
//
//  Created by wpf on 2017/3/30.
//  Copyright © 2017年 wpf. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (KVO)

- (void)wpf_addObserver:(NSObject *_Nonnull)observer forKeyPath:(NSString *_Nonnull)keyPath options:(NSKeyValueObservingOptions)options;
- (void)wpf_removeObserver:(NSObject *_Nonnull)observer forKeyPath:(NSString *_Nonnull)keyPath;
- (void)wpf_observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change;

@end


