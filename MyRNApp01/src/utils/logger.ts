export const logger = {
  info(...args: unknown[]) {
    console.log('[InterviewDemo]', ...args);
  },
  warn(...args: unknown[]) {
    console.warn('[InterviewDemo]', ...args);
  },
  error(...args: unknown[]) {
    console.error('[InterviewDemo]', ...args);
  },
};

export function stringify(value: unknown) {
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
}
