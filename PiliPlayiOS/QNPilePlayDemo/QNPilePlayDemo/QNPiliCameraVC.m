//
//  QNPiliCameraVC.m
//  QNPilePlayDemo
//
//  Created by   何舒 on 15/11/3.
//  Copyright © 2015年   何舒. All rights reserved.
//

#import "QNPiliCameraVC.h"
#import "Reachability.h"
#import <PLCameraStreamingKit/PLCameraStreamingKit.h>
#import <asl.h>

const char *stateNames[] = {
    "Unknow",
    "Connecting",
    "Connected",
    "Disconnecting",
    "Disconnected",
    "Error"
};

const char *networkStatus[] = {
    "Not Reachable",
    "Reachable via WiFi",
    "Reachable via CELL"
};

#define kReloadConfigurationEnable  0

// 假设在 videoFPS 低于预期 50% 的情况下就触发降低推流质量的操作，这里的 40% 是一个假定数值，你可以更改数值来尝试不同的策略
#define kMaxVideoFPSPercent 0.5

// 假设当 videoFPS 在 10s 内与设定的 fps 相差都小于 5% 时，就尝试调高编码质量
#define kMinVideoFPSPercent 0.05
#define kHigherQualityTimeInterval  10

static NSArray *ConsoleLogs() {
    NSMutableArray *consoleLog = [NSMutableArray array];
    
    aslclient client = asl_open(NULL, NULL, ASL_OPT_STDERR);
    
    aslmsg query = asl_new(ASL_TYPE_QUERY);
    asl_set_query(query, ASL_KEY_MSG, NULL, ASL_QUERY_OP_NOT_EQUAL);
    aslresponse response = asl_search(client, query);
    
    asl_free(query);
    
    aslmsg message;
    while((message = asl_next(response)))
    {
        const char *msg = asl_get(message, ASL_KEY_MSG);
        [consoleLog addObject:[NSString stringWithCString:msg encoding:NSUTF8StringEncoding]];
    }
    
    asl_release(response);
    asl_close(client);
    
    return consoleLog;
}

static NSString *LogString() {
    NSArray *logs = ConsoleLogs();
    NSString *log = [logs componentsJoinedByString:@"\n"];
    return log;
}

@interface QNPiliCameraVC ()<
PLCameraStreamingSessionDelegate,
PLStreamingSendingBufferDelegate
>
@property (nonatomic, assign) NSInteger orientationNum;
@property (nonatomic, strong) NSDictionary *streamDic;
@property (nonatomic, strong) NSDictionary * startStreamDic;
@property (nonatomic, strong) NSString * streamName;
@property (nonatomic, strong) NSString * quality;
@property (nonatomic, strong) PLCameraStreamingSession  *session;
@property (nonatomic, strong) Reachability *internetReachability;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) NSArray   *videoConfigurations;
@property (nonatomic, strong) NSDate    *keyTime;
@property (nonatomic, assign) BOOL isStart;


@end

@implementation QNPiliCameraVC

- (instancetype)initWithOrientation:(NSInteger)orientationNum
                    withStreamDic:(NSDictionary *)streamDic
                        withTitle:(NSString *)streamName
{
    self = [super init];
    
    
    if (self) {
        self.streamDic = streamDic;
        self.streamName = streamName;
        self.orientationNum = orientationNum;
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    self.title = @"视频录播";
    
    
    if (!self.orientationNum) {

        self.backButton1.transform=CGAffineTransformMakeRotation(M_PI/2);
        self.toggleCameraButton1.transform=CGAffineTransformMakeRotation(M_PI/2);
        self.torchButton1.transform=CGAffineTransformMakeRotation(M_PI/2);
        self.muteButton1.transform=CGAffineTransformMakeRotation(M_PI/2);
        self.actionButton1.transform=CGAffineTransformMakeRotation(M_PI/2);
        self.textView1.transform = CGAffineTransformMakeRotation(M_PI/2);
        self.segementedControl1.transform = CGAffineTransformMakeRotation(M_PI/2);
        self.view = self.rightView;
    }
  
    
    // 预先设定几组编码质量，之后可以切换
    CGSize videoSize;
    if(self.orientationNum)
    {
        videoSize = CGSizeMake(320, 480);
    }else
    {
        videoSize = CGSizeMake(480, 320);
    }
    self.videoConfigurations = @[
                                 [[PLVideoStreamingConfiguration alloc] initWithVideoSize:videoSize videoFrameRate:15 videoMaxKeyframeInterval:45 videoBitrate:800 * 1000 videoProfileLevel:AVVideoProfileLevelH264Baseline31],
                                 [[PLVideoStreamingConfiguration alloc] initWithVideoSize:videoSize videoFrameRate:24 videoMaxKeyframeInterval:72 videoBitrate:800 * 1000 videoProfileLevel:AVVideoProfileLevelH264Baseline31],
                                 [[PLVideoStreamingConfiguration alloc] initWithVideoSize:videoSize videoFrameRate:30 videoMaxKeyframeInterval:90 videoBitrate:800 * 1000 videoProfileLevel:AVVideoProfileLevelH264Baseline31],
                                 ];
    self.sessionQueue = dispatch_queue_create("pili.queue.streaming", DISPATCH_QUEUE_SERIAL);
    
    // 网络状态监控
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    // PLCameraStreamingKit 使用开始
    //
    // streamJSON 是从服务端拿回的
    //
    // 从服务端拿回的 streamJSON 结构如下：
    //    @{@"id": @"stream_id",
    //      @"title": @"stream_title",
    //      @"hub": @"hub_name",
    //      @"publishKey": @"publish_key",
    //      @"publishSecurity": @"dynamic", // or static
    //      @"disabled": @(NO),
    //      @"profiles": @[@"480p", @"720p"],    // or empty Array []
    //      @"hosts": @{
    //              ...
    //      }
#warning 如果要运行 demo 这里应该填写服务端返回的某个流的 json 信息
    PLStream *stream = [PLStream streamWithJSON:[Help dictionaryWithJsonString:self.streamDic[@"stream"]]];
    
    void (^permissionBlock)(void) = ^{
        dispatch_async(self.sessionQueue, ^{
            // 视频编码配置
            PLVideoStreamingConfiguration *videoConfiguration = [self.videoConfigurations lastObject];
            // 音频编码配置
            PLAudioStreamingConfiguration *audioConfiguration = [PLAudioStreamingConfiguration defaultConfiguration];
            
            // 推流 session
            self.session = [[PLCameraStreamingSession alloc] initWithVideoConfiguration:videoConfiguration
                                                                     audioConfiguration:audioConfiguration
                                                                                 stream:stream
                                                                       videoOrientation:AVCaptureVideoOrientationPortrait];
            self.session.delegate = self;
            self.session.bufferDelegate = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                UIView * uiview = [[UIView alloc] init];
                if (!self.orientationNum) {
                    uiview.transform = CGAffineTransformMakeRotation(M_PI/2);
                    self.session.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                }
                uiview.frame =self.view.frame;
                self.session.previewView = uiview;
                
                self.view.backgroundColor = [UIColor clearColor];
                [self.view addSubview:self.session.previewView];
                if (self.orientationNum) {
                    [self.view bringSubviewToFront:self.textView];
                    [self.view bringSubviewToFront:self.zoomSlider];
                    [self.view bringSubviewToFront:self.backButton];
                    [self.view bringSubviewToFront:self.toggleCameraButton];
                    [self.view bringSubviewToFront:self.torchButton];
                    [self.view bringSubviewToFront:self.muteButton];
                    [self.view bringSubviewToFront:self.actionButton];
                    [self.view bringSubviewToFront:self.segementedControl];
                    
                    self.zoomSlider.minimumValue = 1;
                    self.zoomSlider.maximumValue = self.session.videoActiveFormat.videoMaxZoomFactor;
                    
                    NSString *log = [NSString stringWithFormat:@"Zoom Range: [1..%.0f]", self.session.videoActiveFormat.videoMaxZoomFactor];
                    NSLog(@"%@", log);
                    self.textView.text = [NSString stringWithFormat:@"%@\%@", self.textView.text, log];
                }else{
                    [self.view bringSubviewToFront:self.textView1];
                    [self.view bringSubviewToFront:self.zoomSlider1];
                    [self.view bringSubviewToFront:self.backButton1];
                    [self.view bringSubviewToFront:self.toggleCameraButton1];
                    [self.view bringSubviewToFront:self.torchButton1];
                    [self.view bringSubviewToFront:self.muteButton1];
                    [self.view bringSubviewToFront:self.actionButton1];
                    [self.view bringSubviewToFront:self.segementedControl1];
                    
                    self.zoomSlider1.minimumValue = 1;
                    self.zoomSlider1.maximumValue = self.session.videoActiveFormat.videoMaxZoomFactor;
                    
                    NSString *log = [NSString stringWithFormat:@"Zoom Range: [1..%.0f]", self.session.videoActiveFormat.videoMaxZoomFactor];
                    NSLog(@"%@", log);
                    self.textView1.text = [NSString stringWithFormat:@"%@\%@", self.textView1.text, log];
                }

                
                
                
            });
        });
    };
    
    void (^noAccessBlock)(void) = ^{
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"No Access", nil)
                                                            message:NSLocalizedString(@"!", nil)
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                  otherButtonTitles:nil];
        [alertView show];
    };
    
    switch ([PLCameraStreamingSession cameraAuthorizationStatus]) {
        case PLAuthorizationStatusAuthorized:
            permissionBlock();
            break;
        case PLAuthorizationStatusNotDetermined: {
            [PLCameraStreamingSession requestCameraAccessWithCompletionHandler:^(BOOL granted) {
                granted ? permissionBlock() : noAccessBlock();
            }];
        }
            break;
        default:
            noAccessBlock();
            break;
    }
}

- (void)startStream
{
    NSDictionary * dic = @{@"sessionId":[UserInfoClass sheardUserInfo].sessionID,
                           @"accessToken":[Help transformAccessToken:[UserInfoClass sheardUserInfo].sessionID],
                           @"streamId":self.streamDic[@"streamId"],
                           @"streamQuality":@"4",
                           @"streamTitle":self.streamName,
                           @"streamOrientation":[NSString stringWithFormat:@"%ld",(long)self.orientationNum]};
    [HTTPRequestPost hTTPRequest_PostpostBody:dic andUrl:@"start/publish" andSucceed:^(NSURLSessionDataTask *task, id responseObject) {
        self.startStreamDic = responseObject;
    } andFailure:^(NSURLSessionDataTask *task, NSError *error) {
    } andISstatus:NO];
}

- (IBAction)backAction:(id)sender
{
    if(self.isStart){
        NSDictionary * dic = @{@"sessionId":[UserInfoClass sheardUserInfo].sessionID,@"accessToken":[Help transformAccessToken:[UserInfoClass sheardUserInfo].sessionID],@"publishId":self.startStreamDic[@"publishId"]};
        [HTTPRequestPost hTTPRequest_PostpostBody:dic andUrl:@"stop/publish" andSucceed:^(NSURLSessionDataTask *task, id responseObject) {
            [SVProgressHUD showAlterMessage:responseObject[@"desc"]];
            [self.session stop];
        } andFailure:^(NSURLSessionDataTask *task, NSError *error) {
        } andISstatus:NO];
    }
    [self dismissViewControllerAnimated:YES completion:^{
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    
    dispatch_sync(self.sessionQueue, ^{
        [self.session destroy];
    });
    self.session = nil;
    self.sessionQueue = nil;
}

#pragma mark - Notification Handler

- (void)reachabilityChanged:(NSNotification *)notif{
    Reachability *curReach = [notif object];
    NSParameterAssert([curReach isKindOfClass:[Reachability class]]);
    NetworkStatus status = [curReach currentReachabilityStatus];
    
    if (NotReachable == status) {
        // 对断网情况做处理
        [self stopSession];
    }
    
    NSString *log = [NSString stringWithFormat:@"Networkt Status: %s", networkStatus[status]];
    NSLog(@"%@", log);
    if (self.orientationNum) {
        self.textView.text = [NSString stringWithFormat:@"%@\%@", self.textView.text, log];
    }else
    {
    self.textView1.text = [NSString stringWithFormat:@"%@\%@", self.textView1.text, log];
    }
}

#pragma mark - <PLStreamingSendingBufferDelegate>

- (void)streamingSessionSendingBufferDidFull:(id)session {
    NSString *log = @"Buffer is full";
    NSLog(@"%@", log);
    if (self.orientationNum) {
        self.textView.text = [NSString stringWithFormat:@"%@\%@", self.textView.text, log];
    }else
    {
        self.textView1.text = [NSString stringWithFormat:@"%@\%@", self.textView1.text, log];
    }
}

- (void)streamingSession:(id)session sendingBufferDidDropItems:(NSArray *)items {
    NSString *log = @"Frame dropped";
    NSLog(@"%@", log);
    if (self.orientationNum) {
        self.textView.text = [NSString stringWithFormat:@"%@\%@", self.textView.text, log];
    }else
    {
        self.textView1.text = [NSString stringWithFormat:@"%@\%@", self.textView1.text, log];
    }
}

#pragma mark - <PLCameraStreamingSessionDelegate>

- (void)cameraStreamingSession:(PLCameraStreamingSession *)session streamStateDidChange:(PLStreamState)state {
    NSString *log = [NSString stringWithFormat:@"Stream State: %s", stateNames[state]];
    NSLog(@"%@", log);
    if (self.orientationNum) {
        self.textView.text = [NSString stringWithFormat:@"%@\%@", self.textView.text, log];
        // 除 PLStreamStateError 外的其余状态会回调在这个方法
        // 这个回调会确保在主线程，所以可以直接对 UI 做操作
        if (PLStreamStateConnected == state) {
            [self.actionButton setTitle:NSLocalizedString(@"Stop", nil) forState:UIControlStateNormal];
        } else if (PLStreamStateDisconnected == state) {
            [self.actionButton setTitle:NSLocalizedString(@"Start", nil) forState:UIControlStateNormal];
        }
    }else
    {
        self.textView1.text = [NSString stringWithFormat:@"%@\%@", self.textView1.text, log];
        // 除 PLStreamStateError 外的其余状态会回调在这个方法
        // 这个回调会确保在主线程，所以可以直接对 UI 做操作
        if (PLStreamStateConnected == state) {
            [self.actionButton1 setTitle:NSLocalizedString(@"Stop", nil) forState:UIControlStateNormal];
        } else if (PLStreamStateDisconnected == state) {
            [self.actionButton1 setTitle:NSLocalizedString(@"Start", nil) forState:UIControlStateNormal];
        }
    }
    
    
}

- (void)cameraStreamingSession:(PLCameraStreamingSession *)session didDisconnectWithError:(NSError *)error {
    NSString *log = [NSString stringWithFormat:@"Stream State: Error. %@", error];
    NSLog(@"%@", log);
    if (self.orientationNum) {
        self.textView.text = [NSString stringWithFormat:@"%@\%@", self.textView.text, log];
        [self.actionButton setTitle:NSLocalizedString(@"Reconnecting", nil) forState:UIControlStateNormal];
    }else
    {
        self.textView1.text = [NSString stringWithFormat:@"%@\%@", self.textView1.text, log];
        [self.actionButton1 setTitle:NSLocalizedString(@"Reconnecting", nil) forState:UIControlStateNormal];
    }
    // PLStreamStateError 都会回调在这个方法
    // 尝试重连，注意这里需要你自己来处理重连尝试的次数以及重连的时间间隔
    [self.actionButton setTitle:NSLocalizedString(@"Reconnecting", nil) forState:UIControlStateNormal];
    [self startSession];
}

- (void)cameraStreamingSession:(PLCameraStreamingSession *)session streamStatusDidUpdate:(PLStreamStatus *)status {
    NSString *log = [NSString stringWithFormat:@"%@", status];
    NSLog(@"%@", log);
    if (self.orientationNum) {
        self.textView.text = [NSString stringWithFormat:@"%@\%@", self.textView.text, log];
    }else
    {
        self.textView1.text = [NSString stringWithFormat:@"%@\%@", self.textView1.text, log];
    }
    
#if kReloadConfigurationEnable
    NSDate *now = [NSDate date];
    if (!self.keyTime) {
        self.keyTime = now;
    }
    
    double expectedVideoFPS = (double)self.session.videoConfiguration.videoFrameRate;
    double realtimeVideoFPS = status.videoFPS;
    if (realtimeVideoFPS < expectedVideoFPS * (1 - kMaxVideoFPSPercent)) {
        // 当得到的 status 中 video fps 比设定的 fps 的 50% 还小时，触发降低推流质量的操作
        self.keyTime = now;
        
        [self lowerQuality];
    } else if (realtimeVideoFPS >= expectedVideoFPS * (1 - kMinVideoFPSPercent)) {
        if (-[self.keyTime timeIntervalSinceNow] > kHigherQualityTimeInterval) {
            self.keyTime = now;
            
            [self higherQuality];
        }
    }
#endif  // #if kReloadConfigurationEnable
}

#pragma mark -

- (void)higherQuality {
    NSUInteger idx = [self.videoConfigurations indexOfObject:self.session.videoConfiguration];
    NSAssert(idx != NSNotFound, @"Oops");
    
    if (idx >= self.videoConfigurations.count - 1) {
        return;
    }
    PLVideoStreamingConfiguration *newConfiguration = self.videoConfigurations[idx + 1];
    [self.session reloadVideoConfiguration:newConfiguration];
}

- (void)lowerQuality {
    NSUInteger idx = [self.videoConfigurations indexOfObject:self.session.videoConfiguration];
    NSAssert(idx != NSNotFound, @"Oops");
    
    if (0 == idx) {
        return;
    }
    PLVideoStreamingConfiguration *newConfiguration = self.videoConfigurations[idx - 1];
    [self.session reloadVideoConfiguration:newConfiguration];
}

#pragma mark - Operation

- (void)stopSession {
    dispatch_async(self.sessionQueue, ^{
        self.keyTime = nil;
        [self.session stop];
    });
}

- (void)startSession {
    self.keyTime = nil;
    self.actionButton.enabled = NO;
    dispatch_async(self.sessionQueue, ^{
        [self.session startWithCompleted:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.actionButton.enabled = YES;
            });
        }];
    });
}

#pragma mark - Action

- (IBAction)segmentedControlValueDidChange:(id)sender {
    PLVideoStreamingConfiguration *config;
    if (self.orientationNum) {
        config = self.videoConfigurations[self.segementedControl.selectedSegmentIndex];
    }else
    {
        config = self.videoConfigurations[self.segementedControl1.selectedSegmentIndex];
    }
    
    [self.session reloadVideoConfiguration:config];
}

- (IBAction)zoomSliderValueDidChange:(id)sender {
    if (self.orientationNum) {
        self.session.videoZoomFactor = self.zoomSlider.value;
    }else
    {
    self.session.videoZoomFactor = self.zoomSlider1.value;
    }
}

- (IBAction)actionButtonPressed:(id)sender {
    if (!self.isStart) {
        [self startStream];
        self.isStart = YES;
    }
    if (PLStreamStateConnected == self.session.streamState) {
        [self stopSession];
    } else {
        [self startSession];
    }
}

- (IBAction)toggleCameraButtonPressed:(id)sender {
    dispatch_async(self.sessionQueue, ^{
        [self.session toggleCamera];
    });
}

- (IBAction)torchButtonPressed:(id)sender {
    dispatch_async(self.sessionQueue, ^{
        self.session.torchOn = !self.session.isTorchOn;
    });
}

- (IBAction)muteButtonPressed:(id)sender {
    dispatch_async(self.sessionQueue, ^{
        self.session.muted = !self.session.isMuted;
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
