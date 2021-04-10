//
//  TPAudioRecoder.m
//  RecorderAndPlayerDemo
//
//  Created by MrPlus on 2021/4/9.
//

#import "TPAudioRecoder.h"
#import <AVFoundation/AVFoundation.h>
#import "lame.h"

// 录音存放的文件夹 /Library/Caches/TPRecorder
#define RecorderPath [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Caches/TPRecorder"]

@interface TPAudioRecoder ()<AVAudioRecorderDelegate>

/// 录音对象
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
/// 录音文件的名字
@property (nonatomic, strong) NSString *audioFileName;
/// 是否要转mp3
@property (nonatomic, assign) BOOL isConventMp3;



@end
@implementation TPAudioRecoder

+ (TPAudioRecoder*)shared{
    static TPAudioRecoder *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}
- (AVAudioRecorder *)audioRecorder {
    __weak typeof(self) weakSelf = self;
    if (!_audioRecorder) {
        
        // 0. 设置录音会话
        /**
         AVAudioSessionCategoryPlayAndRecord: 可以边播放边录音(也就是平时看到的背景音乐)
         */
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        // 启动会话
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        
        // 1. 确定录音存放的位置
        NSURL *url = [NSURL URLWithString:weakSelf.cafRecordPath];
        
        // 2. 设置录音参数
        NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
        // 设置编码格式
        /**
         kAudioFormatLinearPCM: 无损压缩，内容非常大
         kAudioFormatMPEG4AAC
         */
        [recordSettings setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey: AVFormatIDKey];
        // 采样率：必须保证和转码设置的相同
        [recordSettings setValue :[NSNumber numberWithFloat:11025.0] forKey: AVSampleRateKey];
        // 通道数（必须设置为双声道, 不然转码生成的 MP3 会声音尖锐变声.）
        [recordSettings setValue :[NSNumber numberWithInt:2] forKey: AVNumberOfChannelsKey];
        
        //音频质量,采样质量(音频质量越高，文件的大小也就越大)
        [recordSettings setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];
        
        // 3. 创建录音对象
        NSError *error ;
        _audioRecorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSettings error:&error];
        //开启音量监测
        _audioRecorder.meteringEnabled = YES;
        
        _audioRecorder.delegate = weakSelf;
        
        if(error){
            NSLog(@"创建录音对象时发生错误，错误信息：%@",error.localizedDescription);
        }
    }
    return _audioRecorder;
}
- (void)beginRecordWithRecordName:(NSString *)recordName conventToMp3:(BOOL)isConventToMp3{
    _isConventMp3 = isConventToMp3;
    if ([recordName containsString:[NSString stringWithFormat:@".%@",@"caf"]]) {
        
        _audioFileName = recordName;
    }else{
        
        _audioFileName = [NSString stringWithFormat:@"%@.%@", recordName, @"caf"];
    }
    
    if (![TPAudioRecoder judgeFileOrFolderExists: RecorderPath]) {
        // 创建 /Library/Caches/TPRecorder 文件夹
        [TPAudioRecoder createFolder: RecorderPath];
    }
    
    // 创建录音文件存放路径
    _cafRecordPath = [RecorderPath stringByAppendingPathComponent: _audioFileName];
    if (_audioRecorder) {
        _audioRecorder = nil;
    }
    // 准备录音
    if ([self.audioRecorder prepareToRecord]) {
        // 开始录音
        [self.audioRecorder record];
    }
}

/// 结束录音
- (void)endRecord {
    [self.audioRecorder stop];
}

/// 暂停录音
- (void)pauseRecord {
    [self.audioRecorder pause];
}

/// 删除录音
- (void)deleteRecord {
    [self.audioRecorder stop];
    // 删除录音之前必须先停止录音
    [self.audioRecorder deleteRecording];
}

/// 重新录音
- (void)reRecord {
    
    self.audioRecorder = nil;
    [self beginRecordWithRecordName:self.audioFileName conventToMp3:self.isConventMp3];
}
/* audioRecorderDidFinishRecording:successfully: is called when a recording has been finished or stopped. This method is NOT called if the recorder is stopped due to an interruption. */
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (flag) {
        NSLog(@"----- 录音  完毕");
        if (self.isConventMp3) {
            [TPAudioRecoder audioToMP3:_cafRecordPath isDeleteSourchFile:YES withSuccessBack:^(NSString * _Nonnull resultPath) {
                if ([resultPath length]) {
                    TPAudioRecoder.shared.mp3RecordPath = resultPath;
                }
            } withFailBack:^(NSString * _Nonnull error) {
                
            }];
        }
    }
}
/**
 caf 转 mp3
 如果录音时间比较长的话,会要等待几秒...
 @param sourcePath 转 mp3 的caf 路径
 @param isDelete 是否删除原来的 caf 文件，YES：删除、NO：不删除
 @param success 成功的回调
 @param fail 失败的回调
 */
+ (void)audioToMP3:(NSString *)sourcePath isDeleteSourchFile: (BOOL)isDelete withSuccessBack:(void(^)(NSString *resultPath))success withFailBack:(void(^)(NSString *error))fail{
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
       
        // 输入路径
        NSString *inPath = sourcePath;
        
        // 判断输入路径是否存在
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:sourcePath])
        {
            if (fail) {
                fail(@"文件不存在");
            }
            return;
        }
        
        // 输出路径
        NSString *outPath = [[sourcePath stringByDeletingPathExtension] stringByAppendingString:@".mp3"];
        
        @try {
            int read, write;
            
            FILE *pcm = fopen([inPath cStringUsingEncoding:1], "rb");  //source 被转换的音频文件位置
            fseek(pcm, 4*1024, SEEK_CUR);                                   //skip file header
            FILE *mp3 = fopen([outPath cStringUsingEncoding:1], "wb");  //output 输出生成的Mp3文件位置
            
            const int PCM_SIZE = 8192;
            const int MP3_SIZE = 8192;
            short int pcm_buffer[PCM_SIZE*2];
            unsigned char mp3_buffer[MP3_SIZE];
            
            lame_t lame = lame_init();
            lame_set_in_samplerate(lame, 11025.0);
            lame_set_VBR(lame, vbr_default);
            lame_init_params(lame);
            
            do {
                size_t size = (size_t)(2 * sizeof(short int));
                read = (int)fread(pcm_buffer, size, PCM_SIZE, pcm);
                if (read == 0)
                    write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
                else
                    write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
                
                fwrite(mp3_buffer, write, 1, mp3);
                
            } while (read != 0);
            
            lame_close(lame);
            fclose(mp3);
            fclose(pcm);
        }
        
        @catch (NSException *exception) {
            NSLog(@"%@",[exception description]);
        }
        
        @finally {
            
            if (isDelete) {
                
                NSError *error;
                [fm removeItemAtPath:sourcePath error:&error];
                if (error == nil)
                {
                    // NSLog(@"删除源文件成功");
                }
            }
            
            if (success) {
                success(outPath);
            }
        }
        
    });

}

#pragma mark 1、判断文件或文件夹是否存在
+ (BOOL)judgeFileOrFolderExists:(NSString *)filePathName {
    
    // 长度等于0，直接返回不存在
    if (filePathName.length == 0) {
        return NO;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *filePath = [NSString stringWithFormat:@"%@",filePathName];
    BOOL isDir = NO;
    // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
    BOOL existed = [fileManager fileExistsAtPath:filePath isDirectory:&isDir];
    
    if ( !(isDir == YES && existed == YES) ) {
        
        // 不存在的路径才会创建
        return NO;
    }else{
        
        return YES;
    }
    return nil;
}

+ (BOOL)judgeFileExists:(NSString *)filePath {
    
    // 长度等于0，直接返回不存在
    if (filePath.length == 0) {
        return NO;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSString stringWithFormat:@"%@",filePath];
    BOOL isDir = NO;
    // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
    BOOL existed = [fileManager fileExistsAtPath:path isDirectory:&isDir];
    
    if (existed == YES) {
        
        return YES;
    }else{
        // 不存在
        return NO;
    }
    return nil;
}

/**类方法创建文件夹目录 folderNmae:文件夹的名字*/
+ (NSString *)createFolder:(NSString *)folderName {
    
    // NSHomeDirectory()：应用程序目录， Caches、Library、Documents目录文件夹下创建文件夹(蓝色的)
    NSString *filePath = [NSString stringWithFormat:@"%@",folderName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    // fileExistsAtPath 判断一个文件或目录是否有效，isDirectory判断是否一个目录
    BOOL existed = [fileManager fileExistsAtPath:filePath isDirectory:&isDir];
    
    if ( !(isDir == YES && existed == YES) ) {
        
        // 不存在的路径才会创建
        [fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return filePath;
}

@end
