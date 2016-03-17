//
//  QNPiliPlayVC.m
//  QNPilePlayDemo
//
//  Created by   何舒 on 15/11/3.
//  Copyright © 2015年   何舒. All rights reserved.
//

#import "QNPiliPlayVC.h"
#import <PLPlayerKitFramework/PLPlayerKitFramework.h>

static NSString *status[] = {
    @"PLPlayerStatusUnknow",
    @"PLPlayerStatusPreparing",
    @"PLPlayerStatusReady",
    @"PLPlayerStatusCaching",
    @"PLPlayerStatusPlaying",
    @"PLPlayerStatusPaused",
    @"PLPlayerStatusStopped",
    @"PLPlayerStatusError"
};

@interface QNPiliPlayVC ()<
PLPlayerDelegate
>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSDictionary * dic;
@property (nonatomic, strong) UIButton * backBtn;
@property (nonatomic, strong) PLPlayer  *player;
@property (nonatomic, weak) dispatch_queue_t  playerQueue;
@property (nonatomic, strong) UIView  *playerView;
@property (nonatomic, strong) UIButton * forceConnectBtn;

@end

@implementation QNPiliPlayVC


- (instancetype)initWithDic:(NSDictionary *)dic
{
    self = [super init];
    if (self) {
        self.url = [NSURL URLWithString:dic[@"playUrls"][@"ORIGIN"]];
        self.dic = dic;
    }
    
    return self;
}

- (void)dealloc {
    self.player = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"播放";
    
    self.player = [[PLPlayer alloc] initWithURL:self.url];
    self.player.delegate = self;
    self.player.timeoutIntervalForMediaPackets = 15;
    [self.view addSubview:self.player.playerView];
    self.playerView = self.player.playerView;
    self.playerView.frame = self.view.bounds;
    [self.player prepareToPlay];
    [self.player play];
    [self addBtn];
}

- (void)addBtn
{
    self.backBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 20, 50, 50)];
    self.backBtn.titleEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
    [self.backBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.backBtn.layer.cornerRadius = 20;
    [self.backBtn setBackgroundColor:[UIColor redColor]];
    [self.backBtn setTitle:@"返回" forState:UIControlStateNormal];
    [self.backBtn addTarget:self action:@selector(backAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.backBtn];
    
    self.forceConnectBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 100, 100, 50)];
    self.forceConnectBtn.titleEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
    [self.forceConnectBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.forceConnectBtn.layer.cornerRadius = 20;
    [self.forceConnectBtn setBackgroundColor:[UIColor redColor]];
    [self.forceConnectBtn setTitle:@"强制重连" forState:UIControlStateNormal];
    [self.forceConnectBtn addTarget:self action:@selector(button:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.forceConnectBtn];
    
}


- (BOOL)shouldAutorotate
{
    return NO;
}

-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    if ([[NSString stringWithFormat:@"%@",self.dic[@"orientation"]] isEqualToString:@"1"]) {
        return UIDeviceOrientationPortrait;

    }else{
        return UIInterfaceOrientationLandscapeRight;
    }


}

-(NSUInteger)supportedInterfaceOrientations

{
    if ([[NSString stringWithFormat:@"%@",self.dic[@"orientation"]] isEqualToString:@"1"]) {
        return UIInterfaceOrientationMaskPortrait;
    }else
    {
        return UIInterfaceOrientationMaskLandscapeRight;
    }
}

- (void)backAction:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:^{
    }];
}
- (void)viewWillDisappear:(BOOL)animated {
    NSLog(@"will %@", NSStringFromSelector(_cmd));
    dispatch_queue_t queue =  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_barrier_async(queue, ^{
        if (self.player.isPlaying) {
            [self.player stop];
        }
    });
    
    [super viewWillDisappear:animated];
}


- (void)button:(id)sender {
    [self reconnect];
}

- (void)resetPlayerView {
    if (self.playerView) {
        [self.playerView removeFromSuperview];
        self.playerView = nil;
    }
    
    self.playerView = self.player.playerView;
    self.playerView.frame = self.view.bounds;
    [self.view insertSubview:self.playerView atIndex:0];
}

- (void)reconnect {
    dispatch_queue_t queue =  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_barrier_async(queue, ^{
        NSURL *url = self.player.url;
        if (self.player) {
            self.player.delegate = nil;
            [self.player stop];
            self.player = nil;
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.player = [[PLPlayer alloc] initWithURL:url];
        });
        self.player.delegate = self;
        self.player.timeoutIntervalForMediaPackets = 15;
        self.player.scalingMode = PLPlayerViewScalingModeAspectFill;
        
        [self performSelectorOnMainThread:@selector(resetPlayerView) withObject:nil waitUntilDone:YES];
        
        [self.player prepareToPlay];
    });
}

#pragma mark - <PLPlayerDelegate>

- (void)player:(nonnull PLPlayer *)player statusDidChange:(PLPlayerStatus)state {
    NSLog(@"State: %@", status[state]);
    if (PLPlayerStatusReady == state) {
        dispatch_queue_t queue =  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_barrier_async(queue, ^{
            [self.player play];
        });
    }
}

- (void)player:(nonnull PLPlayer *)player stoppedWithError:(nullable NSError *)error {
    NSLog(@"State: Error %@", error);
    __weak typeof(self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wself) strongSelf = wself;
        [strongSelf reconnect];
    });
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
