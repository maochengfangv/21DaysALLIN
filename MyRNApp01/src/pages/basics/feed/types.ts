export type FeedAuthor = {
  id: string;
  name: string;
  badge: string;
  avatarColor: string;
};

export type FeedItemData = {
  id: string;
  author: FeedAuthor;
  content: string;
  images: string[];
  likeCount: number;
  commentCount: number;
  publishAt: string;
};

export type FeedItemDetail = {
  detail: string;
  commentPreview: string[];
  hasLiked: boolean;
  fetchedAt: string;
};

export type FeedPageResponse = {
  list: FeedItemData[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
};

export type FeedImageCacheSource =
  | 'memory'
  | 'disk'
  | 'disk/memory'
  | 'http'
  | 'prefetch'
  | 'error'
  | 'unknown';

export type FeedDetailStatus = 'idle' | 'loading' | 'success' | 'error';
