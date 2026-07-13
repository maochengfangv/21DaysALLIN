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

export type FeedPageResponse = {
  list: FeedItemData[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
};
