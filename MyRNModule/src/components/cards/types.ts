export type CardActionType = 0 | 1 | 2 | 3;

export interface CardAction {
  id: string;
  title: string;
  actionType: CardActionType;
  payload?: Record<string, unknown>;
}

export interface BusinessCardData {
  cardId: string;
  cardType: 0 | 1 | 2 | 3;
  title: string;
  subtitle?: string;
  description?: string;
  coverUrl?: string;
  author?: string;
  tag?: string;
  timestamp?: number;
  extra?: Record<string, unknown>;
}

export interface BusinessCardPayload {
  data: BusinessCardData;
  actions?: CardAction[];
}

export interface CardListInitialProps {
  title?: string;
  subtitle?: string;
  cards?: BusinessCardPayload[];
  enablePullRefresh?: boolean;
  enableLoadMore?: boolean;
  theme?: 'light' | 'dark';
}

export type CardPressCallback = (cardId: string) => void;
export type ActionPressCallback = (
  cardId: string,
  actionId: string,
  actionType: CardActionType,
) => void;
export type ExposureCallback = (cardId: string, timestamp: number) => void;
