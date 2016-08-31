//
//  QNPiliPlayVC.h
//  QNPilePlayDemo
//
//  Created by   何舒 on 15/11/3.
//  Copyright © 2015年   何舒. All rights reserved.
//

#import "BaseVC.h"

@interface QNPiliPlayVC : BaseVC
@property (weak, nonatomic) IBOutlet UIButton *backBtn;

- (instancetype)initWithDic:(NSDictionary *)dic;
@property (weak, nonatomic) IBOutlet UIButton *screenCaptureBtn;
@property (weak, nonatomic) IBOutlet UIButton *refreshBtn;

@end
