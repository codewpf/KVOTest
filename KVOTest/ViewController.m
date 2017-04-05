//
//  ViewController.m
//  KVOTest
//
//  Created by wpf on 2017/3/30.
//  Copyright © 2017年 wpf. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+KVO.h"

@interface Change : NSObject
@property (nonatomic, copy) NSString *name;
@end
@implementation Change
@end


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *show;
@property (weak, nonatomic) IBOutlet UITextField *change;
@property (assign, nonatomic) NSInteger num;
@property (strong, nonatomic) Change *ccc;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.ccc = [Change new];
    
    [self.change addTarget:self action:@selector(testChange:) forControlEvents:UIControlEventEditingChanged];
    
    [self.ccc wpf_addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew];
}

- (void)testChange:(UITextField *)field {
    NSLog(@"%@",field.text);
}


- (void)wpf_observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change
{
    NSLog(@"%@,%@",keyPath,change);
}



- (IBAction)click:(UIButton *)sender {
    
    //self.num = self.num + 1;
    self.show.text = [NSString stringWithFormat:@"%@", [NSDate date]];
    
    self.ccc.name = [NSString stringWithFormat:@"%@", [NSDate date]];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
