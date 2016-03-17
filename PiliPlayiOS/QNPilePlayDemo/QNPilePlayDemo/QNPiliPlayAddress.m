//
//  QNPiliPlayAddress.m
//  QNPilePlayDemo
//
//  Created by   何舒 on 15/12/3.
//  Copyright © 2015年   何舒. All rights reserved.
//

#import "QNPiliPlayAddress.h"

@interface QNPiliPlayAddress ()

@property (nonatomic, strong) NSDictionary * addressDic;

@end

@implementation QNPiliPlayAddress

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.title =@"播放地址";
    [self getAddress];
    self.addressTitle.selectedSegmentIndex = 0;
    
}

- (void)getAddress
{
    NSDictionary * dic = @{@"sessionId":[UserInfoClass sheardUserInfo].sessionID,@"accessToken":[Help transformAccessToken:[UserInfoClass sheardUserInfo].sessionID]};
    [HTTPRequestPost hTTPRequest_GetpostBody:dic andUrl:@"my/live/play/urls" andSucceed:^(NSURLSessionDataTask *task, id responseObject) {
        self.addressDic = responseObject[@"livePlayUrls"];
        self.addressData.text = self.addressDic[@"RTMP"];
    } andFailure:^(NSURLSessionDataTask *task, NSError *error) {
        
    } andISstatus:NO];
}

- (IBAction)choseAction:(id)sender {
    UISegmentedControl * choseAddress = (UISegmentedControl *)sender;
    switch (choseAddress.selectedSegmentIndex) {
        case 0:
            self.addressData.text = self.addressDic[@"RTMP"];
            break;
        case 1:
            self.addressData.text = self.addressDic[@"HLS"];
            break;
        case 2:
            self.addressData.text = self.addressDic[@"FLV"];
            break;
        default:
            break;
    }
    
}
- (IBAction)copyAction:(id)sender {
    
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    switch (self.addressTitle.selectedSegmentIndex) {
        case 0:
            pasteboard.string = self.addressDic[@"RTMP"];
            break;
        case 1:
            pasteboard.string = self.addressDic[@"HLS"];
            break;
        case 2:
            pasteboard.string = self.addressDic[@"FLV"];
            break;
        default:
            break;
    }
    [SVProgressHUD showAlterMessage:@"复制成功"];
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
