import { speechRecognizer } from '@kit.CoreSpeechKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';

export class VoiceService {
  private isRecording: boolean = false;
  private onResultCallback: ((text: string) => void) | null = null;
  private asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private audioCapturer: audio.AudioCapturer | null = null;
  private sessionId: string = '';
  private recognizedText: string = '';
  private isFinalReceived: boolean = false;

  async startRecording(): Promise<void> {
    if (this.isRecording) {
      console.warn('[VoiceService] Already recording');
      return;
    }

    try {
      this.sessionId = `asr_${Date.now()}`;
      this.recognizedText = '';
      this.isFinalReceived = false;

      this.asrEngine = await this.createAsrEngine();
      if (!this.asrEngine) {
        throw new Error('ASR engine creation failed');
      }

      this.setupListener();

      const audioInfo: speechRecognizer.AudioInfo = {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      };
      const extraParam: Record<string, Object> = {
        'recognitionMode': 0,
        'vadBegin': 2000,
        'vadEnd': 3000,
        'maxAudioDuration': 60000
      };
      const startParams: speechRecognizer.StartParams = {
        sessionId: this.sessionId,
        audioInfo: audioInfo,
        extraParams: extraParam
      };

      this.asrEngine.startListening(startParams);
      console.log('[VoiceService] ASR listening started');

      this.audioCapturer = await this.createAudioCapturer();

      this.audioCapturer.on('readData', (arrayBuffer: ArrayBuffer) => {
        if (this.asrEngine && this.isRecording) {
          const chunk: Uint8Array = new Uint8Array(arrayBuffer);
          this.asrEngine.writeAudio(this.sessionId, chunk);
        }
      });

      await this.audioCapturer.start();
      console.log('[VoiceService] Audio capturer started');

      this.isRecording = true;
      promptAction.showToast({ message: '开始录音...' });
    } catch (error) {
      console.error('[VoiceService] Start recording failed:', error);
      this.cleanup();
      promptAction.showToast({ message: '无法启动录音，请检查麦克风权限' });
      throw new Error('[VoiceService] Failed to start recording');
    }
  }

  private createAsrEngine(): Promise<speechRecognizer.SpeechRecognitionEngine | null> {
    return new Promise((resolve) => {
      const extraParam: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'short' };
      const initParams: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 1,
        extraParams: extraParam
      };

      try {
        speechRecognizer.createEngine(initParams, (err: BusinessError, engine: speechRecognizer.SpeechRecognitionEngine) => {
          if (err) {
            console.error('[VoiceService] createEngine error:', err.code, err.message);
            resolve(null);
          } else {
            console.log('[VoiceService] ASR engine created');
            resolve(engine);
          }
        });
      } catch (e) {
        console.error('[VoiceService] createEngine exception:', e);
        resolve(null);
      }
    });
  }

  private setupListener(): void {
    if (!this.asrEngine) return;

    const listener: speechRecognizer.RecognitionListener = {
      onStart: (sessionId: string, eventMessage: string) => {
        console.log('[VoiceService] ASR onStart:', eventMessage);
      },
      onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
        console.log('[VoiceService] ASR onEvent:', eventCode, eventMessage);
      },
      onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
        if (result.isFinal) {
          this.recognizedText = result.result;
          this.isFinalReceived = true;
          console.log('[VoiceService] Final result:', result.result);
        } else {
          console.log('[VoiceService] Partial result:', result.result);
        }
      },
      onComplete: (sessionId: string, eventMessage: string) => {
        console.log('[VoiceService] ASR onComplete:', eventMessage);
        if (this.onResultCallback && this.recognizedText) {
          this.onResultCallback(this.recognizedText);
          promptAction.showToast({ message: '语音识别完成' });
        } else if (this.onResultCallback && !this.recognizedText) {
          promptAction.showToast({ message: '未识别到语音内容' });
        }
        this.cleanup();
      },
      onError: (sessionId: string, errorCode: number, errorMessage: string) => {
        console.error('[VoiceService] ASR error:', errorCode, errorMessage);
        promptAction.showToast({ message: `语音识别失败: ${errorMessage}` });
        this.cleanup();
      }
    };

    this.asrEngine.setListener(listener);
  }

  private async createAudioCapturer(): Promise<audio.AudioCapturer> {
    const audioStreamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };

    const audioCapturerInfo: audio.AudioCapturerInfo = {
      source: audio.SourceType.SOURCE_TYPE_MIC,
      capturerFlags: 0
    };

    const capturerOptions: audio.AudioCapturerOptions = {
      streamInfo: audioStreamInfo,
      capturerInfo: audioCapturerInfo
    };

    return await audio.createAudioCapturer(capturerOptions);
  }

  async stopRecording(): Promise<void> {
    if (!this.isRecording) {
      console.warn('[VoiceService] Not recording');
      return;
    }

    this.isRecording = false;

    if (this.audioCapturer) {
      try {
        await this.audioCapturer.stop();
        console.log('[VoiceService] Audio capturer stopped');
      } catch (e) {
        console.error('[VoiceService] Stop capturer error:', e);
      }
    }

    if (this.asrEngine) {
      try {
        this.asrEngine.finish(this.sessionId);
        console.log('[VoiceService] ASR finish called');
      } catch (e) {
        console.error('[VoiceService] ASR finish error:', e);
        if (this.onResultCallback && this.recognizedText) {
          this.onResultCallback(this.recognizedText);
        }
        this.cleanup();
      }
    }
  }

  onResult(callback: (text: string) => void): void {
    this.onResultCallback = callback;
  }

  getIsRecording(): boolean {
    return this.isRecording;
  }

  async cleanup(): Promise<void> {
    this.isRecording = false;

    if (this.audioCapturer) {
      try {
        await this.audioCapturer.release();
      } catch (e) {
        console.error('[VoiceService] Release capturer error:', e);
      }
      this.audioCapturer = null;
    }

    if (this.asrEngine) {
      try {
        this.asrEngine.shutdown();
      } catch (e) {
        console.error('[VoiceService] Shutdown ASR error:', e);
      }
      this.asrEngine = null;
    }

    this.onResultCallback = null;
    this.recognizedText = '';
    console.log('[VoiceService] Cleanup done');
  }
}

export const voiceService = new VoiceService();
