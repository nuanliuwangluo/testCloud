//
//  RecorderM.h
//  录音管理器 - 支持 WAV / M4A 格式，转 AMR / MP3
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 录音状态
typedef NS_ENUM(NSInteger, RecorderState) {
    RecorderStateIdle = 0,        // 空闲
    RecorderStateRecording,       // 录音中
    RecorderStateConverting,      // 转换中
    RecorderStateStopped          // 已停止
};

// 授权状态
typedef NS_ENUM(NSInteger, RecorderAuthStatus) {
    RecorderAuthStatusNotDetermined = 0,   // 未决定
    RecorderAuthStatusAuthorized,          // 已授权
    RecorderAuthStatusDenied,              // 已拒绝
    RecorderAuthStatusRestricted           // 受限制
};

// 录音格式
typedef NS_ENUM(NSInteger, RecorderAudioFormat) {
    RecorderAudioFormatWAV = 0,   // WAV (Linear PCM) - 传统格式
    RecorderAudioFormatM4A = 1    // M4A (AAC) - 推荐用于转 MP3，音质更好
};

// 完成回调 (result 包含 status, msg, code, path 等信息)
typedef void (^RecorderCompletionBlock)(NSDictionary *result);

@interface RecorderM : NSObject

+ (instancetype)recorderM;

// 录音配置
@property (nonatomic, assign) NSTimeInterval maxDuration;          // 最大录音时长（秒），默认 60.0
@property (nonatomic, assign) RecorderAudioFormat audioFormat;     // 录音格式，默认 WAV

// 文件名配置
@property (nonatomic, assign) BOOL useFixedFileName;               // 是否使用固定文件名，默认 YES
@property (nonatomic, copy) NSString *fixedFileName;               // 固定文件名（不含后缀），默认 "temp_recording"
@property (nonatomic, copy, nullable) NSString *customFileName;    // 自定义文件名（不含后缀），useFixedFileName=NO 时生效

// 保存目录（默认为 Documents/Recorder）
@property (nonatomic, copy) NSString *saveDirectory;

// 当前状态
@property (nonatomic, assign, readonly) RecorderState state;

// 1. 查询授权状态
- (RecorderAuthStatus)getAuth;
- (NSString *)getAuthDes:(RecorderAuthStatus)status;

// 2. 申请授权
- (void)requestAuth:(RecorderCompletionBlock)completion;

// 3. 开始录音
- (void)startRecording:(RecorderCompletionBlock)completion;

// 4. 停止录音并转换为 AMR / MP3
- (void)stopRecording:(RecorderCompletionBlock)completion;

// 取消录音（不转换）
- (void)cancelRecording;

// 5. 获取文件路径
- (NSString *)getRecordingSaveDirectory;
- (NSString * _Nullable)getCurrentAMRFilePath;
- (NSString * _Nullable)getCurrentMP3FilePath;
- (NSString * _Nullable)getCurrentAudioFilePath;

// 文件管理
- (BOOL)deleteRecordingFile:(NSString *)filePath;
- (BOOL)deleteCurrentRecording;
- (NSArray<NSString *> *)getAllRecordingFiles;

@end

NS_ASSUME_NONNULL_END
