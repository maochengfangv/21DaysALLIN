import { logger } from '../utils/logger';

type ExposureEvent = {
  itemId: string;
  index: number;
  timestamp: number;
  visibleThreshold: number;
  stayMs: number;
};

type LazyRequestEvent = {
  itemId: string;
  index: number;
  timestamp: number;
  status: 'start' | 'success' | 'error' | 'retry';
  durationMs?: number;
  errorMessage?: string;
};

export function trackExposure(event: ExposureEvent) {
  logger.info('ExposureEvent', event);
}

export function trackLazyRequest(event: LazyRequestEvent) {
  logger.info('LazyRequestEvent', event);
}
