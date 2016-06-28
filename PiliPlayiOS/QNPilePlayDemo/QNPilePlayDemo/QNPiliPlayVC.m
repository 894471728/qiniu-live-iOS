//
//  QNPiliPlayVC.m
//  QNPilePlayDemo
//
//  Created by   何舒 on 15/11/3.
//  Copyright © 2015年   何舒. All rights reserved.
//

#import "QNPiliPlayVC.h"
#import <PLPlayerKit/PLPlayer.h>

#define enableBackgroundPlay    1

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
//        self.url = [NSURL URLWithString:@"rtmp://pili-live-rtmp.live.golanghome.com/jinxinxin/56eba5e8d409d2b03d001eae"];
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
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    PLPlayerOption *option = [PLPlayerOption defaultOption];
    [option setOptionValue:@10 forKey:PLPlayerOptionKeyTimeoutIntervalForMediaPackets];
    
    // 初始化 PLPlayer
    self.player = [PLPlayer playerWithURL:self.url option:option];
    
    // 设定代理 (optional)
    self.player.delegate = self;
    self.player.delegateQueue = dispatch_get_main_queue();
    self.player.backgroundPlayEnable = enableBackgroundPlay;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startPlayer) name:UIApplicationWillEnterForegroundNotification object:nil];
    [self.view addSubview:self.player.playerView];
    self.playerView = self.player.playerView;
//    self.playerView.frame = self.view.frame;
    if ([[NSString stringWithFormat:@"%@",self.dic[@"orientation"]] isEqualToString:@"1"]) {
        self.playerView.frame = CGRectMake(0, 0, kDeviceWidth, KDeviceHeight);
        
    }else{
        self.playerView.frame = CGRectMake(0, 0, KDeviceHeight, kDeviceWidth);
    }
    
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

- (void)startPlayer {
    [self.player play];
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
        NSURL *url = self.player.URL;
        if (self.player) {
            self.player.delegate = nil;
            [self.player stop];
            self.player = nil;
        }
        
        // 初始化 PLPlayerOption 对象
        PLPlayerOption *option = [PLPlayerOption defaultOption];
        
        // 更改需要修改的 option 属性键所对应的值
        [option setOptionValue:@15 forKey:PLPlayerOptionKeyTimeoutIntervalForMediaPackets];
        dispatch_sync(dispatch_get_main_queue(), ^{
            // 初始化 PLPlayer
            self.player = [PLPlayer playerWithURL:url option:option];
        });
        self.player.delegate = self;
        self.player.playerView.contentMode = UIViewContentModeScaleAspectFill;
        
        [self performSelectorOnMainThread:@selector(resetPlayerView) withObject:nil waitUntilDone:YES];
        
        [self.player play];
    });
}

#pragma mark - <PLPlayerDelegate>

- (void)player:(nonnull PLPlayer *)player statusDidChange:(PLPlayerStatus)state {
    NSLog(@"State: %@", status[state]);
    if (PLPlayerStatusReady == state) {
//        dispatch_queue_t queue =  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//        dispatch_barrier_async(queue, ^{
//            [self.player play];
//        });
    }
}

- (void)player:(nonnull PLPlayer *)player stoppedWithError:(nullable NSError *)error {
    NSLog(@"State: Error %@", error);
    __weak typeof(self) wself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(wself) strongSelf = wself;
        [strongSelf.player play];
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
