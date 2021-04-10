//
//  ViewController.m
//  RecorderAndPlayerDemo
//
//  Created by MrPlusZhao on 2021/4/9.
//

#import "ViewController.h"
#import "TPAudioRecoder.h"
#import "AudioPlayerService.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    
    
}

- (IBAction)start:(id)sender {
    NSLog(@"开始录制");
    [[TPAudioRecoder shared] beginRecordWithRecordName:@"audioFile" conventToMp3:YES];
}

- (IBAction)stop:(id)sender {
    NSLog(@"结束录制");
    [[TPAudioRecoder shared] endRecord];
}
- (IBAction)play:(id)sender {
    if ([AudioPlayerService sharedInstance].bufferState == PPXAudioBufferStateBuffering) {
        [[AudioPlayerService sharedInstance] stop];
    }
    
    if ([[TPAudioRecoder shared].mp3RecordPath length]) {
        [AudioPlayerService sharedInstance].playUrlStr = [TPAudioRecoder shared].mp3RecordPath;
        [[AudioPlayerService sharedInstance] play];
    }
    else{
        NSLog(@"暂无mp3录音");
    }
}
@end
