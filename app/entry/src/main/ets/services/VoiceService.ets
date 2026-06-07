import { promptAction } from '@kit.ArkUI';

export class VoiceService {
  private isRecording: boolean = false;
  private onResultCallback: ((text: string) => void) | null = null;

  async startRecording(): Promise<void> {
    if (this.isRecording) {
      console.warn('[VoiceService] Already recording');
      return;
    }

    try {
      this.isRecording = true;
      promptAction.showToast({ message: '开始录音...' });
      console.log('[VoiceService] Recording started (stub)');
    } catch (error) {
      console.error('[VoiceService] Failed to start recording:', error);
      promptAction.showToast({ message: '无法启动录音，请检查麦克风权限' });
      throw new Error('[VoiceService] Failed to start recording');
    }
  }

  async stopRecording(): Promise<void> {
    if (!this.isRecording) {
      console.warn('[VoiceService] Not recording');
      return;
    }

    try {
      this.isRecording = false;
      console.log('[VoiceService] Recording stopped (stub)');

      setTimeout(() => {
        if (this.onResultCallback) {
          const mockResult = '这是语音输入的示例文本';
          this.onResultCallback(mockResult);
          promptAction.showToast({ message: '语音识别完成' });
        }
      }, 1000);
    } catch (error) {
      console.error('[VoiceService] Failed to stop recording:', error);
      promptAction.showToast({ message: '停止录音失败' });
      throw new Error('[VoiceService] Failed to stop recording');
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
    this.onResultCallback = null;
    console.log('[VoiceService] Cleanup done');
  }
}

export const voiceService = new VoiceService();