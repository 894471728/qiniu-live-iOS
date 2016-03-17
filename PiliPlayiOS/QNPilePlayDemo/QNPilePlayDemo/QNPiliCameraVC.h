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

@property (nonatomic, weak) IBOutlet UIView * rightView;
@property (weak, nonatomic) IBOutlet UIButton *backButton1;
@property (weak, nonatomic) IBOutlet UIButton *actionButton1;
@property (weak, nonatomic) IBOutlet UIButton *toggleCameraButton1;
@property (weak, nonatomic) IBOutlet UIButton *torchButton1;
@property (weak, nonatomic) IBOutlet UIButton *muteButton1;
@property (weak, nonatomic) IBOutlet UITextView *textView1;
@property (weak, nonatomic) IBOutlet UISlider *zoomSlider1;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segementedControl1;


- (instancetype)initWithOrientation:(NSInteger)orientationNum
                      withStreamDic:(NSDictionary *)streamDic
                          withTitle:(NSString *)streamName;

- (IBAction)segmentedControlValueDidChange:(id)sender;
- (IBAction)zoomSliderValueDidChange:(id)sender;

@end
