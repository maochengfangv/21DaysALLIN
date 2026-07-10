import type { RouteKey } from '../types/demo';

export type ScreenProps = {
  navigate: (route: RouteKey) => void;
  goBack: () => void;
  lastGlobalError: string | null;
  clearGlobalError: () => void;
};
