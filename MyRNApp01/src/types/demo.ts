export type RouteKey =
  | 'home'
  | 'hooks'
  | 'flatlist'
  | 'form'
  | 'network'
  | 'customHook'
  | 'errorBoundary'
  | 'renderOptimization'
  | 'interaction'
  | 'performanceNotes'
  | 'turboModule'
  | 'fabricView'
  | 'jsiNote'
  | 'envConfig';

export type DemoItem = {
  route: RouteKey;
  title: string;
  subtitle: string;
};

export type DemoSection = {
  section: string;
  items: DemoItem[];
};
