//
//  ViewController.m
//  WGAVPlayer
//
//  Created by wanghongzhi on 2017/7/6.
//  Copyright © 2017年 Xiaomi. All rights reserved.
//

#import "ViewController.h"
#import "AVPlayerItem+WGCacheSupport.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIView *playView;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSArray *sources;

@property (nonatomic, strong) NSMutableDictionary *pendings;


@end

@implementation ViewController

- (NSArray *)sources
{
    return @[@"http://dl.w.xk.miui.com/63814dbaf7fec108a5f85689e78fe907.720p.mp4",
             @"http://dl.w.wg.miui.com/7d49864f26d93f744e394ffb395b0ce7",
             @"http://dl.w.xk.miui.com/e37e5070ec827366f3b109037fa58e11",
             @"http://dl.w.wg.miui.com/4146fedfb111361b9e9d51748ce112d5"];
}

- (NSMutableDictionary *)pendings
{
    if (!_pendings) {
        _pendings = [@{} mutableCopy];
    }
    return _pendings;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSURL *URL = [NSURL URLWithString:@"http://dl.w.wg.miui.com/4146fedfb111361b9e9d51748ce112d5"];
    AVPlayerItem *item = [AVPlayerItem wg_playerItemWithURL:URL];
    _player = [AVPlayer playerWithPlayerItem:item];
    
    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:_player];
    layer.frame = CGRectMake(0, 0, self.playView.bounds.size.width, self.playView.bounds.size.height);
    [self.playView.layer addSublayer:layer];
    [self.player play];
}
- (IBAction)action:(UIButton *)sender {
    [self.player seekToTime:CMTimeMake(0, 1)];
    [self.player play];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.sources.count;
}
- (nullable NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    AVPlayerItem *item = [self.pendings objectForKey:@(row)];
    NSURL *URL = [NSURL URLWithString:self.sources[row]];
    if (!item) {
        AVPlayerItem *item = [AVPlayerItem wg_playerItemWithURL:URL];
        [self.pendings setObject:item forKey:@(row)];
    }
    [item setSuspend:YES];
    return URL.absoluteString;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    for (AVPlayerItem *item in [self.pendings allValues]) {
        [item setSuspend:YES];
    }
    AVPlayerItem *item = self.pendings[@(row)];
    [item setSuspend:NO];

    [self.player replaceCurrentItemWithPlayerItem:item];
    [self.player play];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
