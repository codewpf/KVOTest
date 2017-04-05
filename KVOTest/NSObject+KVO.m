//
//  NSObject+KVO.m
//  KVO
//
//  Created by wpf on 2017/3/30.
//  Copyright © 2017年 wpf. All rights reserved.
//

#import "NSObject+KVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString * const WPF_KVOClassPre = @"WPF_KVOClassPre";
static char WPF_InfosKey;

@interface WPF_KVOInfo : NSObject

@property (nonatomic, strong) NSObject *observer;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, assign) NSUInteger options;

@end
@implementation WPF_KVOInfo

- (instancetype)initWithObserver:(NSObject *)observer keyPath:(NSString *)keyPath options:(NSUInteger)options
{
    if(self = [super init])
    {
        _observer = observer;
        _keyPath = keyPath;
        _options = options;
    }
    return self;
}

@end


@implementation NSObject (KVO)

- (void)wpf_addObserver:(NSObject *_Nonnull)observer forKeyPath:(NSString *_Nonnull)keyPath options:(NSKeyValueObservingOptions)options
{
    SEL setterSel = NSSelectorFromString([self setterNameFromGetter:keyPath]);
    Method setterMethod = class_getInstanceMethod([self class], setterSel);
    
    if (!setterMethod) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have a setter for keyPath %@", self, keyPath];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    
    Class clazz = object_getClass(self);
    NSString *clazzName = NSStringFromClass(clazz);
    
    // 没添加过KVO，则新建一个KVO类
    if(![clazzName hasPrefix:WPF_KVOClassPre]){
        clazz = [self makeKVOClassByOriginalName:clazzName];
        object_setClass(self, clazz);
    }
    
    //
    if(![self hasSelector:setterSel]){
        const char * type = method_getTypeEncoding(setterMethod);
        class_addMethod(clazz, setterSel, (IMP)kvo_setter, type);
    }
    
    WPF_KVOInfo *info = [[WPF_KVOInfo alloc] initWithObserver:observer keyPath:keyPath options:options];
    NSMutableArray *infos = objc_getAssociatedObject(self, &WPF_InfosKey);
    if(!infos)
    {
        infos = [[NSMutableArray alloc] init];
        objc_setAssociatedObject(self, &WPF_InfosKey, infos, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [infos addObject:info];
    
}

- (void)wpf_removeObserver:(NSObject *_Nonnull)observer forKeyPath:(NSString *_Nonnull)keyPath
{
    NSMutableArray *infos = objc_getAssociatedObject(self, &WPF_InfosKey);
    for (WPF_KVOInfo *info in infos) {
        if(info.observer == observer && info.keyPath == keyPath){
            [infos removeObject:info];
            return;
        }
    }
}
- (void)wpf_observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change{}


#pragma mark - Support Methods
// 生成一个当前类的子类 ***主要方法***
- (Class)makeKVOClassByOriginalName:(NSString *)name {

    NSString *kvoName = [WPF_KVOClassPre stringByAppendingString:name];
    Class clazz = NSClassFromString(kvoName);
    if(clazz) {
        return clazz;
    }
    Class originalClazz = object_getClass(self);
    Class kvoClazz = objc_allocateClassPair(originalClazz, kvoName.UTF8String, 0);
    
    Method clazzMethod = class_getInstanceMethod(originalClazz, @selector(class));
    const char *type = method_getTypeEncoding(clazzMethod);
    class_addMethod(kvoClazz, @selector(class), (IMP)kvo_class, type);

    objc_registerClassPair(kvoClazz);
    
    return kvoClazz;
}

// getter -> setter
- (NSString *)setterNameFromGetter:(nonnull NSString *)getter
{
    if(getter.length < 1) {
        return  nil;
    }
    
    NSString *head = [getter substringToIndex:1];
    NSString *tail = [getter substringFromIndex:1];
    return [NSString stringWithFormat:@"set%@%@:",[head uppercaseString],tail];
}

// setter -> getter
- (NSString *)getterNameFromSetter:(nonnull NSString *)setter
{
    if(setter.length <= 5 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]){
        return  nil;
    }
    
    NSString *head = [setter substringWithRange:NSMakeRange(3, 1)];
    NSString *tail = [setter substringWithRange:NSMakeRange(4, setter.length - 5)];
    return  [NSString stringWithFormat:@"%@%@",[head lowercaseString],tail];
}

// 当前类是否包含该方法
- (BOOL)hasSelector:(SEL)temp{
    Class clazz = object_getClass(self);
    unsigned int count = 0;
    Method *list = class_copyMethodList(clazz, &count);
    for(int i=0;i<count;i++)
    {
        SEL s = method_getName(list[i]);
        if(s == temp)
        {
            free(list);
            return YES;
        }
    }
    free(list);
    return NO;
}

#pragma mark - C Methods
static Class kvo_class(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}

// ***主要方法***
static void kvo_setter(id self, SEL _cmd, id newValue)
{
    NSString *setterName = NSStringFromSelector(_cmd);
    NSString *getterName = [self getterNameFromSetter:setterName];
    
    if (!getterName) {
        NSString *reason = [NSString stringWithFormat:@"Object %@ does not have setter %@", self, setterName];
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:reason
                                     userInfo:nil];
        return;
    }
    
    id oldValue = [self valueForKey:getterName];
    
    struct objc_super superclazz = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    
    // cast our pointer so the compiler won't complain
    void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
    
    // call super's setter, which is original class's setter method
    objc_msgSendSuperCasted(&superclazz, _cmd, newValue);
    
    NSMutableArray *infos = objc_getAssociatedObject(self, &WPF_InfosKey);
    for (WPF_KVOInfo *info in infos) {
        if([info.keyPath isEqualToString:getterName]){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                NSMutableDictionary *dict = [NSMutableDictionary new];
                if((info.options & 1) == 1)
                {
                    [dict setValue:newValue forKey:NSKeyValueChangeNewKey];
                }
                if((info.options & 2) >> 1 == 1)
                {
                    [dict setValue:oldValue forKey:NSKeyValueChangeOldKey];
                }
                
                if([info.observer respondsToSelector:@selector(wpf_observeValueForKeyPath:ofObject:change:)])
                {
                    [info.observer wpf_observeValueForKeyPath:info.keyPath ofObject:self change:dict];
                }
            });
        }
    }
    
}


@end
