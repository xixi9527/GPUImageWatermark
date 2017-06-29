//
//  ViewController.m
//  GPUImageWatermark
//
//  Created by Hellen Yang on 2017/6/29.
//  Copyright © 2017年 yjl. All rights reserved.
//

#import "ViewController.h"
#import <GPUImage.h>
#import <Masonry.h>

@interface ViewController ()<GPUImageVideoCameraDelegate>
@property (nonatomic , strong) GPUImageUIElement* uiElementInput;
@property (strong, nonatomic) IBOutlet GPUImageView *mGPUImageView;
@property (nonatomic , strong) GPUImageVideoCamera *mGPUVideoCamera;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.mGPUVideoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    self.mGPUImageView.fillMode = kGPUImageFillModeStretch;//kGPUImageFillModePreserveAspectRatioAndFill;
    
    GPUImageSepiaFilter *filter = [[GPUImageSepiaFilter alloc] init];
    
    
    GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
    blendFilter.mix = 1.0;
    
    
    
    NSDate *startTime = [NSDate date];
    
    UIView *temp = [[UIView alloc] initWithFrame:self.view.frame];
    UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 240.0f, 40.0f)];
    timeLabel.font = [UIFont systemFontOfSize:17.0f];
    timeLabel.text = @"Time: 0.0 s";
    timeLabel.backgroundColor = [UIColor clearColor];
    timeLabel.textColor = [UIColor whiteColor];
    [temp addSubview:timeLabel];
    
    self.uiElementInput = [[GPUImageUIElement alloc] initWithView:temp];
    
    
    
    __unsafe_unretained GPUImageUIElement *weakUIElementInput = _uiElementInput;
    
    [filter setFrameProcessingCompletionBlock:^(GPUImageOutput * filter, CMTime frameTime){
        timeLabel.text = [NSString stringWithFormat:@"Time: %02f s", -[startTime timeIntervalSinceNow]];
        [weakUIElementInput update];
    }];
    
    
    //响应链
    [self.mGPUVideoCamera addTarget:filter];
    [filter addTarget:blendFilter];
    [_uiElementInput addTarget:blendFilter];
    [blendFilter addTarget:self.mGPUImageView];
    [self.mGPUVideoCamera startCameraCapture];
    
    
    //添加通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    
    UIImageView* imgView = [[UIImageView alloc] init];
    [self.view addSubview:imgView];
    __weak UIViewController *weakSelf = self;
    [imgView mas_makeConstraints:^(MASConstraintMaker *make) {
        __strong UIViewController *strongSelf = weakSelf;
        make.width.height.mas_equalTo(strongSelf.view).multipliedBy(1.0/4);
        make.right.bottom.mas_offset(0);
    }];
    
    
    
    GPUImageRawDataOutput *output = [[GPUImageRawDataOutput alloc] initWithImageSize:self.mGPUImageView.sizeInPixels resultsInBGRAFormat:YES];
    [blendFilter addTarget:output];
    
    
    
    __weak GPUImageRawDataOutput *weakOutput = output;
    [output setNewFrameAvailableBlock:^{
        __strong GPUImageRawDataOutput *strongOutput = weakOutput;
        
        [strongOutput lockFramebufferForReading];
        GLubyte *outputBytes = [strongOutput rawBytesForImage];
        NSInteger bytesPerRow = [strongOutput bytesPerRowInOutput];
        CVPixelBufferRef pixelBuffer = NULL;
        CVPixelBufferCreateWithBytes(kCFAllocatorDefault, 640, 480, kCVPixelFormatType_32BGRA, outputBytes, bytesPerRow, nil, nil, nil, &pixelBuffer);
        CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
        CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, strongOutput.rawBytesForImage, bytesPerRow * 480, NULL);
        CGImageRef cgImage = CGImageCreate(640, 480, 8, 32, bytesPerRow, rgbColorSpace, kCGImageAlphaPremultipliedFirst|kCGBitmapByteOrder32Little, provider, NULL, true, kCGRenderingIntentDefault);
        //
        UIImage *image = [UIImage imageWithCGImage:cgImage];
        dispatch_async(dispatch_get_main_queue(), ^{
            imgView.image = image;
        });
        CGImageRelease(cgImage);
        CVPixelBufferRelease(pixelBuffer);
        [strongOutput unlockFramebufferAfterReading];
    }];
    
    
    
    //摄像头切换按钮
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor greenColor];
    [button setTitle:@"切换摄像头" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(btnClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(30);
        make.width.mas_equalTo(100);
        make.top.mas_offset(30);
        make.right.mas_offset(-30);
    }];
    
    
    //开关摄像头
    UIButton *controlBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    controlBtn.backgroundColor = [UIColor greenColor];
    [controlBtn addTarget:self action:@selector(controlClick:) forControlEvents:UIControlEventTouchUpInside];
    [controlBtn setTitle:@"开关" forState:UIControlStateNormal];
    [self.view addSubview:controlBtn];
    [controlBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(30);
        make.width.mas_equalTo(80);
        make.bottom.mas_offset(-30);
        make.left.mas_offset(30);
    }];
    
    
}

- (void)btnClick
{
    [self.mGPUVideoCamera rotateCamera];
}

- (void)controlClick:(UIButton *)btn
{
    btn.selected = !btn.selected;
    if (btn.selected) {
        [self.mGPUVideoCamera stopCameraCapture];
    } else {
        [self.mGPUVideoCamera startCameraCapture];
    }
}

- (void)deviceOrientationDidChange:(NSNotification *)notification {
    UIInterfaceOrientation orientation = (UIInterfaceOrientation)[UIDevice currentDevice].orientation;
    self.mGPUVideoCamera.outputImageOrientation = orientation;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
