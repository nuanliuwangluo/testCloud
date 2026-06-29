//
//  RecorderM.m
//  录音管理器实现 - 支持 WAV/M4A，转 AMR/MP3
//

#import "RecorderM.h"
#import <AVFoundation/AVFoundation.h>
#import "interf_enc.h"
#import "lame/lame.h"

// AMR-NB 常量
#define AMR_FRAME_SIZE 32               // AMR-NB 每帧 32 字节
static const NSUInteger kAMRNBSamplesPerFrame = 160;   // 8kHz 下 20ms = 160 采样点

@interface RecorderM () <AVAudioRecorderDelegate>

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) AVAudioSession *audioSession;
@property (nonatomic, strong) NSTimer *recordTimer;
@property (nonatomic, assign) NSTimeInterval currentDuration;
@property (nonatomic, assign, readwrite) RecorderState state;
@property (nonatomic, copy) NSString *currentAudioPath;      // 当前录音文件路径 (.wav 或 .m4a)
@property (nonatomic, copy) NSString *currentAmrPath;
@property (nonatomic, copy) NSString *currentMp3Path;

@property (nonatomic, copy) RecorderCompletionBlock currentCompletion;

@end

@implementation RecorderM

#pragma mark - 单例

+ (instancetype)recorderM {
    static RecorderM *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupDefaults];
        [self setupAudioSession];
    }
    return self;
}

- (void)setupDefaults {
    _maxDuration = 60.0;
    _state = RecorderStateIdle;
    _currentDuration = 0;
    _useFixedFileName = YES;
    _fixedFileName = @"temp_recording";
    _audioFormat = RecorderAudioFormatWAV;   // 默认 WAV 格式
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = paths.firstObject;
    _saveDirectory = [documentsPath stringByAppendingPathComponent:@"Recorder"];
    
    [self createSaveDirectoryIfNeeded];
}

- (void)setupAudioSession {
    _audioSession = [AVAudioSession sharedInstance];
    NSError *error = nil;
    [_audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                          mode:AVAudioSessionModeDefault
                       options:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth
                         error:&error];
    if (error) {
        NSLog(@"音频会话配置失败: %@", error);
    }
    
    [_audioSession setActive:YES error:&error];
    if (error) {
        NSLog(@"音频会话激活失败: %@", error);
    }
}

#pragma mark - 录音设置

- (NSDictionary *)audioSettingsForCurrentFormat {
    if (self.audioFormat == RecorderAudioFormatM4A) {
        // M4A (AAC) 设置 - 高质量
        return @{
            AVFormatIDKey: @(kAudioFormatMPEG4AAC),
            AVSampleRateKey: @(44100.0),
            AVNumberOfChannelsKey: @(1),
            AVEncoderBitRateKey: @(128000),
            AVEncoderAudioQualityKey: @(AVAudioQualityHigh)
        };
    } else {
        // WAV (Linear PCM) 设置 - 8kHz 单声道 16bit
        return @{
            AVFormatIDKey: @(kAudioFormatLinearPCM),
            AVSampleRateKey: @(8000.0),
            AVNumberOfChannelsKey: @(1),
            AVLinearPCMBitDepthKey: @(16),
            AVLinearPCMIsFloatKey: @(NO),
            AVLinearPCMIsBigEndianKey: @(NO),
            AVEncoderAudioQualityKey: @(AVAudioQualityHigh)
        };
    }
}

- (NSString *)fileExtensionForCurrentFormat {
    return (self.audioFormat == RecorderAudioFormatM4A) ? @"m4a" : @"wav";
}

- (NSString *)generateAudioFilePath {
    [self createSaveDirectoryIfNeeded];
    
    NSString *extension = [self fileExtensionForCurrentFormat];
    NSString *fileName;
    if (self.useFixedFileName) {
        fileName = [NSString stringWithFormat:@"%@.%@", self.fixedFileName, extension];
    } else if (self.customFileName.length > 0) {
        fileName = [NSString stringWithFormat:@"%@.%@", self.customFileName, extension];
    } else {
        NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
        fileName = [NSString stringWithFormat:@"recording_%.0f.%@", timestamp, extension];
    }
    
    return [self.saveDirectory stringByAppendingPathComponent:fileName];
}

- (NSString *)generateAMRFilePathFromAudioPath:(NSString *)audioPath {
    NSString *amrFileName;
    if (self.useFixedFileName) {
        amrFileName = [NSString stringWithFormat:@"%@.amr", self.fixedFileName];
    } else {
        NSString *sourceExtension = [self fileExtensionForCurrentFormat];
        amrFileName = [[audioPath lastPathComponent] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@", sourceExtension]
                                                                               withString:@".amr"];
    }
    return [self.saveDirectory stringByAppendingPathComponent:amrFileName];
}

- (void)createSaveDirectoryIfNeeded {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:self.saveDirectory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:self.saveDirectory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
        if (error) {
            NSLog(@"创建录音目录失败: %@", error);
        } else {
            NSLog(@"创建录音目录成功: %@", self.saveDirectory);
        }
    }
}

#pragma mark - 授权

- (RecorderAuthStatus)getAuth {
    AVAudioSessionRecordPermission permission = [_audioSession recordPermission];
    switch (permission) {
        case AVAudioSessionRecordPermissionUndetermined: return RecorderAuthStatusNotDetermined;
        case AVAudioSessionRecordPermissionGranted:      return RecorderAuthStatusAuthorized;
        case AVAudioSessionRecordPermissionDenied:       return RecorderAuthStatusDenied;
        default:                                         return RecorderAuthStatusDenied;
    }
}

- (NSString *)getAuthDes:(RecorderAuthStatus)status {
    switch (status) {
        case RecorderAuthStatusNotDetermined: return @"未决定";
        case RecorderAuthStatusAuthorized:    return @"已授权";
        case RecorderAuthStatusDenied:        return @"已拒绝";
        case RecorderAuthStatusRestricted:    return @"受限制";
        default:                              return @"未知";
    }
}

- (void)requestAuth:(RecorderCompletionBlock)completion {
    self.currentCompletion = completion;
    AVAudioSessionRecordPermission permission = [_audioSession recordPermission];
    
    if (permission == AVAudioSessionRecordPermissionGranted) {
        if (self.currentCompletion) {
            self.currentCompletion(@{@"status": @YES, @"msg": @"麦克风权限已授权"});
            self.currentCompletion = nil;
        }
        return;
    }
    
    if (permission == AVAudioSessionRecordPermissionDenied) {
        if (self.currentCompletion) {
            self.currentCompletion(@{@"code": @(1001), @"status": @NO, @"msg": @"麦克风权限已被拒绝，请在设置中开启"});
            self.currentCompletion = nil;
        }
        return;
    }
    
    [_audioSession requestRecordPermission:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                if (self.currentCompletion) {
                    self.currentCompletion(@{@"status": @YES, @"msg": @"麦克风权限已授权"});
                }
            } else {
                if (self.currentCompletion) {
                    self.currentCompletion(@{@"code": @(1002), @"status": @NO, @"msg": @"用户拒绝了麦克风权限"});
                }
            }
            self.currentCompletion = nil;
        });
    }];
}

#pragma mark - 开始录音

- (void)startRecording:(RecorderCompletionBlock)completion {
    self.currentCompletion = completion;
    
    if ([self getAuth] != RecorderAuthStatusAuthorized) {
        if (self.currentCompletion) {
            self.currentCompletion(@{@"code": @(1003), @"status": @NO, @"msg": @"麦克风权限未授权"});
            self.currentCompletion = nil;
        }
        return;
    }
    
    if (!_audioSession.isInputAvailable) {
        if (self.currentCompletion) {
            self.currentCompletion(@{@"code": @(1004), @"status": @NO, @"msg": @"录音设备不可用"});
            self.currentCompletion = nil;
        }
        return;
    }
    
    [self performStartRecording];
}

- (void)performStartRecording {
    self.currentAudioPath = [self generateAudioFilePath];
    self.currentAmrPath = nil;
    self.currentMp3Path = nil;
    self.currentDuration = 0;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:self.currentAudioPath]) {
        [fileManager removeItemAtPath:self.currentAudioPath error:nil];
    }
    
    NSURL *recordURL = [NSURL fileURLWithPath:self.currentAudioPath];
    NSDictionary *settings = [self audioSettingsForCurrentFormat];
    
    NSError *error = nil;
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:recordURL settings:settings error:&error];
    if (error) {
        if (self.currentCompletion) {
            self.currentCompletion(@{@"code": @(1005), @"status": @NO, @"msg": @"初始化录音器失败"});
            self.currentCompletion = nil;
        }
        return;
    }
    
    self.audioRecorder.delegate = self;
    [self.audioRecorder prepareToRecord];
    
    if ([self.audioRecorder record]) {
        self.state = RecorderStateRecording;
        [self startTimer];
        
        if (self.currentCompletion) {
            self.currentCompletion(@{
                @"status": @YES,
                @"msg": @"开始录音成功",
                @"audioPath": self.currentAudioPath ?: @"",
                @"saveDirectory": self.saveDirectory
            });
            self.currentCompletion = nil;
        }
        NSLog(@"开始录音，文件路径: %@", self.currentAudioPath);
    } else {
        if (self.currentCompletion) {
            self.currentCompletion(@{@"code": @(1006), @"status": @NO, @"msg": @"开始录音失败"});
            self.currentCompletion = nil;
        }
    }
}

#pragma mark - 停止录音

- (void)stopRecording:(RecorderCompletionBlock)completion {
    if (self.state != RecorderStateRecording) {
        if (completion) {
            completion(@{@"code": @(1007), @"status": @NO, @"msg": @"当前没有正在进行的录音"});
        }
        return;
    }
    
    self.currentCompletion = completion;
    self.state = RecorderStateConverting;
    
    [self.audioRecorder stop];
    [self stopTimer];
    
    NSLog(@"录音已停止，开始转换...");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self convertToAMR];
//        [self convertToMP3];
    });
}

- (void)cancelRecording {
    if (self.state == RecorderStateRecording) {
        [self.audioRecorder stop];
        [self stopTimer];
    }
    
    if (self.currentAudioPath && [[NSFileManager defaultManager] fileExistsAtPath:self.currentAudioPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.currentAudioPath error:nil];
    }
    
    self.state = RecorderStateIdle;
    self.currentAudioPath = nil;
    self.currentAmrPath = nil;
    self.currentDuration = 0;
    NSLog(@"录音已取消");
}

#pragma mark - PCM 提取（核心：使用 AVAssetReader 保证数据准确）

- (NSData *)extractPCMFromAudioFile:(NSString *)filePath {
    NSURL *url = [NSURL fileURLWithPath:filePath];
    AVAsset *asset = [AVAsset assetWithURL:url];
    
    NSError *error;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    if (error) {
        NSLog(@"AVAssetReader 初始化失败: %@", error);
        return nil;
    }
    
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!track) {
        NSLog(@"文件中没有音频轨道");
        return nil;
    }
    
    // 输出为标准 PCM 格式 (16-bit 小端，单声道)
    NSDictionary *outputSettings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVLinearPCMBitDepthKey: @(16),
        AVLinearPCMIsFloatKey: @(NO),
        AVLinearPCMIsBigEndianKey: @(NO),
        AVNumberOfChannelsKey: @(1)
    };
    
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:outputSettings];
    if (![reader canAddOutput:output]) {
        NSLog(@"无法添加输出");
        return nil;
    }
    [reader addOutput:output];
    
    if (![reader startReading]) {
        NSLog(@"开始读取失败: %@", reader.error);
        return nil;
    }
    
    NSMutableData *pcmData = [NSMutableData data];
    while (reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef buffer = [output copyNextSampleBuffer];
        if (!buffer) break;
        
        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(buffer);
        if (blockBuffer) {
            size_t length = CMBlockBufferGetDataLength(blockBuffer);
            NSMutableData *chunk = [NSMutableData dataWithLength:length];
            CMBlockBufferCopyDataBytes(blockBuffer, 0, length, chunk.mutableBytes);
            [pcmData appendData:chunk];
        }
        CFRelease(buffer);
    }
    
    if (reader.status == AVAssetReaderStatusFailed) {
        NSLog(@"读取 PCM 失败: %@", reader.error);
        return nil;
    }
    
    NSLog(@"成功提取 PCM 数据，大小: %lu 字节", (unsigned long)pcmData.length);
    return pcmData;
}

#pragma mark - 转 AMR

- (void)convertToAMR {
    NSString *audioPath = self.currentAudioPath;
    if (!audioPath) return;
    
    NSData *pcmData = [self extractPCMFromAudioFile:audioPath];
    if (!pcmData) {
        [self handleConversionError:@"提取 PCM 数据失败" code:2002];
        return;
    }
    
    void *encoder = Encoder_Interface_init(0);
    if (!encoder) {
        [self handleConversionError:@"AMR 编码器初始化失败" code:2003];
        return;
    }
    
    NSMutableData *amrData = [NSMutableData data];
    const char *header = "#!AMR\n";
    [amrData appendBytes:header length:6];
    
    const int16_t *samples = (const int16_t *)pcmData.bytes;
    NSUInteger totalSamples = pcmData.length / sizeof(int16_t);
    NSUInteger frameCount = totalSamples / kAMRNBSamplesPerFrame;
    
    for (NSUInteger i = 0; i < frameCount; i++) {
        unsigned char amrFrame[AMR_FRAME_SIZE];
        const int16_t *frameSamples = samples + (i * kAMRNBSamplesPerFrame);
        
        int encodedSize = Encoder_Interface_Encode(encoder, MR122, frameSamples, amrFrame, 0);
        if (encodedSize > 0) {
            [amrData appendBytes:amrFrame length:encodedSize];
        }
    }
    
    Encoder_Interface_exit(encoder);
    
    self.currentAmrPath = [self generateAMRFilePathFromAudioPath:audioPath];
    BOOL success = [amrData writeToFile:self.currentAmrPath atomically:YES];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (success && self.currentCompletion) {
            NSDictionary *result = @{
                @"status": @YES,
                @"msg": @"录音完成并转换为 AMR",
                @"amrPath": self.currentAmrPath ?: @"",
                @"wavPath": self.currentAudioPath ?: @"",
                @"duration": @(self.currentDuration)
            };
            self.state = RecorderStateStopped;
            self.currentCompletion(result);
        } else {
            [self handleConversionError:@"写入 AMR 文件失败" code:2004];
        }
        self.currentCompletion = nil;
        // 不在这里触发 completion，等待 MP3 也完成后一起回调（或单独回调）
    });
}

#pragma mark - 转 MP3

- (void)convertToMP3 {
    NSString *audioPath = self.currentAudioPath;
    if (!audioPath) return;
    
    NSData *pcmData = [self extractPCMFromAudioFile:audioPath];
    if (!pcmData || pcmData.length == 0) {
        NSLog(@"提取 PCM 数据失败，无法转换 MP3");
        [self finishConversionWithErrorIfNeeded];
        return;
    }
    
    NSString *mp3Path = [self.saveDirectory stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"%@.mp3", self.fixedFileName]];
    self.currentMp3Path = mp3Path;
    
    FILE *mp3File = fopen([mp3Path UTF8String], "wb");
    if (!mp3File) {
        [self finishConversionWithErrorIfNeeded];
        return;
    }
    
    lame_t lame = lame_init();
    if (!lame) {
        fclose(mp3File);
        [self finishConversionWithErrorIfNeeded];
        return;
    }
    
    // 根据录音格式确定采样率
    int sampleRate = (self.audioFormat == RecorderAudioFormatM4A) ? 44100 : 8000;
    
    lame_set_num_channels(lame, 1);
    lame_set_in_samplerate(lame, sampleRate);
    lame_set_out_samplerate(lame, sampleRate);
    lame_set_brate(lame, 128);          // 提升至 128 kbps
    lame_set_mode(lame, MONO);
    lame_set_quality(lame, 5);
    lame_set_VBR(lame, vbr_off);
    
    if (lame_init_params(lame) < 0) {
        lame_close(lame);
        fclose(mp3File);
        [self finishConversionWithErrorIfNeeded];
        return;
    }
    
    const int PCM_SIZE = 8192;
    short *pcmBuffer = malloc(PCM_SIZE * sizeof(short));
    unsigned char *mp3Buffer = malloc(PCM_SIZE * 1.25 + 7200);
    if (!pcmBuffer || !mp3Buffer) {
        free(pcmBuffer);
        free(mp3Buffer);
        lame_close(lame);
        fclose(mp3File);
        [self finishConversionWithErrorIfNeeded];
        return;
    }
    
    const short *inputSamples = (const short *)pcmData.bytes;
    int totalSamples = (int)(pcmData.length / sizeof(short));
    int samplesRead = 0;
    
    while (samplesRead < totalSamples) {
        int samplesLeft = totalSamples - samplesRead;
        int samplesToEncode = samplesLeft > PCM_SIZE ? PCM_SIZE : samplesLeft;
        
        memcpy(pcmBuffer, inputSamples + samplesRead, samplesToEncode * sizeof(short));
        int write = lame_encode_buffer_interleaved(lame, pcmBuffer, samplesToEncode,
                                                   mp3Buffer, PCM_SIZE * 1.25 + 7200);
        if (write > 0) {
            fwrite(mp3Buffer, 1, write, mp3File);
        } else if (write < 0) {
            break;
        }
        samplesRead += samplesToEncode;
    }
    
    int flush = lame_encode_flush(lame, mp3Buffer, PCM_SIZE * 1.25 + 7200);
    if (flush > 0) {
        fwrite(mp3Buffer, 1, flush, mp3File);
    }
    
    free(pcmBuffer);
    free(mp3Buffer);
    lame_close(lame);
    fclose(mp3File);
    
    NSLog(@"MP3 转换成功: %@", mp3Path);
    
    NSDictionary *result = @{
        @"status": @YES,
        @"msg": @"录音完成并转换为 MP3",
        @"amrPath": self.currentMp3Path ?: @"",
        @"wavPath": self.currentAudioPath ?: @"",
        @"duration": @(self.currentDuration)
    };
    self.state = RecorderStateStopped;
    self.currentCompletion(result);
}

#pragma mark - 完成处理

- (void)finishConversionWithErrorIfNeeded {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL amrSuccess = self.currentAmrPath && [[NSFileManager defaultManager] fileExistsAtPath:self.currentAmrPath];
        BOOL mp3Success = self.currentMp3Path && [[NSFileManager defaultManager] fileExistsAtPath:self.currentMp3Path];
        
        if (amrSuccess || mp3Success) {
            NSMutableDictionary *result = [NSMutableDictionary dictionary];
            result[@"status"] = @YES;
            result[@"msg"] = @"录音转换完成";
            result[@"duration"] = @(self.currentDuration);
            result[@"audioPath"] = self.currentAudioPath ?: @"";
            if (amrSuccess) result[@"amrPath"] = self.currentAmrPath;
            if (mp3Success) result[@"mp3Path"] = self.currentMp3Path;
            
            self.state = RecorderStateStopped;
            if (self.currentCompletion) {
                self.currentCompletion(result);
            }
        } else {
            [self handleConversionError:@"转换失败，未生成有效文件" code:2005];
        }
        self.currentCompletion = nil;
    });
}

- (void)handleConversionError:(NSString *)message code:(NSInteger)code {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.state = RecorderStateIdle;
        if (self.currentCompletion) {
            self.currentCompletion(@{@"code": @(code), @"status": @NO, @"msg": message});
            self.currentCompletion = nil;
        }
        NSLog(@"转换错误: %@", message);
    });
}

#pragma mark - 定时器

- (void)startTimer {
    self.currentDuration = 0;
    self.recordTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                        target:self
                                                      selector:@selector(updateProgress)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopTimer {
    [self.recordTimer invalidate];
    self.recordTimer = nil;
}

- (void)updateProgress {
    self.currentDuration += 0.1;
    if (self.currentDuration >= self.maxDuration && self.state == RecorderStateRecording) {
        NSLog(@"达到最大录音时长，自动停止");
        [self stopRecording:nil];
    }
}

#pragma mark - 文件路径获取

- (NSString *)getRecordingSaveDirectory {
    return self.saveDirectory;
}

- (NSString *)getCurrentAMRFilePath {
    return self.currentAmrPath;
}

- (NSString *)getCurrentMP3FilePath {
    return self.currentMp3Path;
}

- (NSString *)getCurrentAudioFilePath {
    return self.currentAudioPath;
}

#pragma mark - 文件管理

- (BOOL)deleteRecordingFile:(NSString *)filePath {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:filePath]) {
        NSError *error;
        BOOL success = [fm removeItemAtPath:filePath error:&error];
        if (!success) NSLog(@"删除失败: %@", error);
        return success;
    }
    return NO;
}

- (BOOL)deleteCurrentRecording {
    BOOL success = YES;
    if (self.currentAudioPath) success &= [self deleteRecordingFile:self.currentAudioPath];
    if (self.currentAmrPath)   success &= [self deleteRecordingFile:self.currentAmrPath];
    if (self.currentMp3Path)   success &= [self deleteRecordingFile:self.currentMp3Path];
    return success;
}

- (NSArray<NSString *> *)getAllRecordingFiles {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSArray *files = [fm contentsOfDirectoryAtPath:self.saveDirectory error:&error];
    if (error) return @[];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self ENDSWITH '.wav' OR self ENDSWITH '.m4a' OR self ENDSWITH '.amr' OR self ENDSWITH '.mp3'"];
    return [files filteredArrayUsingPredicate:predicate];
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (!flag && self.state != RecorderStateConverting) {
        self.state = RecorderStateIdle;
    }
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    NSLog(@"录音编码错误: %@", error);
    self.state = RecorderStateIdle;
}

@end
