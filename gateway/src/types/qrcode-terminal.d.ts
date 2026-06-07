declare module 'qrcode-terminal' {
  interface Options {
    small?: boolean;
    large?: boolean;
  }
  export function generate(text: string, options?: Options, callback?: (qrcode: string) => void): string;
  export function generate(text: string, callback?: (qrcode: string) => void): string;
}
