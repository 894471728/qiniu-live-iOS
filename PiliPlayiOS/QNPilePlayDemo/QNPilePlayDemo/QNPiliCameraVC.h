//
//  QNPiliCameraVC.h
//  QNPilePlayDemo
//
//  Created by   何舒 on 15/11/3.
//  Copyright © 2015年   何舒. All rights reserved.
//

#import "BaseVC.h"

@interface QNPiliCameraVC : BaseVC

@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;
@property (weak, nonatomic) IBOutlet UIButton *toggleCameraButton;
@property (weak, nonatomic) IBOutlet UIButton *torchButton;
@property (weak, nonatomic) IBOutlet UIButton *muteButton;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UISlider *zoomSlider;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segementedControl;
@property (weak, nonatomic) IBOutlet UISwitch *isBeauty;
@property (weak, nonatomic) IBOutlet UIStepper *redden;
@property (weak, nonatomic) IBOutlet UIStepper *whiten;
@property (weak, nonatomic) IBOutlet UIStepper *beauty;
@property (weak, nonatomic) IBOutlet UIView *beautyView;
@property (weak, nonatomic) IBOutlet UIButton *playBack;
@property (weak, nonatomic) IBOutlet UIButton *mixAudioBtn;





- (instancetype)initWithOrientation:(NSInteger)orientationNum
                      withStreamDic:(NSDictionary *)streamDic
                          withTitle:(NSString *)streamName;

- (IBAction)segmentedControlValueDidChange:(id)sender;
- (IBAction)zoomSliderValueDidChange:(id)sender;

@end
