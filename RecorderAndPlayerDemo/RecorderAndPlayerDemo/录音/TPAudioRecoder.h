//
//  TPAudioRecoder.h
//  RecorderAndPlayerDemo
//
//  Created by MrPlus on 2021/4/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPAudioRecoder : NSObject

/** .caf 录音文件路径 */
@property (nonatomic, copy, readonly) NSString *cafRecordPath;

/** .mp3 录音文件路径 */
@property (nonatomic, copy) NSString *mp3RecordPath;

+ (TPAudioRecoder*)shared;

/// 开始录音
- (void)beginRecordWithRecordName:(NSString *)recordName conventToMp3:(BOOL)isConventToMp3;

/// 结束录音
- (void)endRecord;
/// 暂停录音
- (void)pauseRecord;
/// 重新录音
- (void)reRecord;

/**
 caf 转 mp3
 如果录音时间比较长的话,会要等待几秒...
 @param sourcePath 转 mp3 的caf 路径
 @param isDelete 是否删除原来的 caf 文件，YES：删除、NO：不删除
 @param success 成功的回调
 @param fail 失败的回调
 */
+ (void)audioToMP3:(NSString *)sourcePath isDeleteSourchFile: (BOOL)isDelete withSuccessBack:(void(^)(NSString *resultPath))success withFailBack:(void(^)(NSString *error))fail;

@end

NS_ASSUME_NONNULL_END
