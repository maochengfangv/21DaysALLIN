import type {
  FeedAuthor,
  FeedItemData,
  FeedItemDetail,
  FeedPageResponse,
} from './types';

export const FEED_PAGE_SIZE = 12;
export const FEED_TOTAL_PAGES = 12;
export const FEED_TOTAL_COUNT = FEED_PAGE_SIZE * FEED_TOTAL_PAGES;

const AUTHORS = [
  '林深见鹿',
  '前端阿哲',
  'Mia Chen',
  '产品同学',
  'River',
  '小周同学',
  'Aiden',
  '苏打水',
];

const BADGES = ['RN', '性能', '工程化', '架构', '社区', '面试'];
const AVATAR_COLORS = [
  '#2563EB',
  '#7C3AED',
  '#EA580C',
  '#0F766E',
  '#E11D48',
  '#0891B2',
];
const CONTENT_SNIPPETS = [
  '把长列表拆成稳定的小颗粒后，首屏会稳很多。',
  '图片不是越早渲染越好，先保住滚动帧率更重要。',
  '分页接口不要只关注请求成功，还要看滚动过程里的重渲染。',
  '面试里讲性能，最好同时能展示结构设计和实际观测指标。',
  '动态高度列表不适合强行上 getItemLayout，错误估算会带来更多抖动。',
  '把重计算和重视图放到真正需要的时候再做，体验会更平滑。',
];
const DETAIL_SNIPPETS = [
  '进入视区后才拉详情，能把列表初始压力从“全量请求”降成“按需请求”。',
  '曝光埋点和 lazy request 最怕重复触发，所以需要用 ref + Set 做去重状态机。',
  '把图片挂载和详情请求拆成两层阈值，既保滚动体验，也保数据时效性。',
  '失败重试不要直接重刷整页，只针对单 item 补请求，列表会更稳。',
];
const COMMENT_SNIPPETS = [
  '这个点很适合面试时结合 render 次数一起讲。',
  '进入视区后再请求详情，确实能减掉很多无效流量。',
  '状态机如果只放 React state，长列表很容易抖动。',
  '把曝光、请求、图片挂载分层是比较实用的折中。',
];
const SHARED_IMAGE_POOL = Array.from({ length: 18 }, (_, index) => {
  return `https://picsum.photos/seed/feed-cache-${index}/480/480`;
});
const BROKEN_IMAGE_URI =
  'https://invalid.feed-cache-demo.local/image-error.jpg';

function sleep(ms: number) {
  return new Promise<void>(resolve => setTimeout(resolve, ms));
}

function seededNumber(seed: number, mod: number) {
  const next = (seed * 9301 + 49297) % 233280;
  return next % mod;
}

function buildAuthor(index: number): FeedAuthor {
  return {
    id: `author-${index % AUTHORS.length}`,
    name: AUTHORS[index % AUTHORS.length],
    badge: BADGES[index % BADGES.length],
    avatarColor: AVATAR_COLORS[index % AVATAR_COLORS.length],
  };
}

function buildContent(index: number) {
  const lines = 2 + seededNumber(index + 7, 5);
  return Array.from({ length: lines }, (_, lineIndex) => {
    return CONTENT_SNIPPETS[(index + lineIndex) % CONTENT_SNIPPETS.length];
  }).join(' ');
}

function buildImages(index: number) {
  const imageCount = seededNumber(index + 11, 8);
  return Array.from({ length: imageCount }, (_, imageIndex) => {
    if (index % 13 === 0 && imageIndex === 0) {
      return BROKEN_IMAGE_URI;
    }

    const poolIndex = seededNumber(
      index * 7 + imageIndex * 11,
      SHARED_IMAGE_POOL.length,
    );
    return SHARED_IMAGE_POOL[poolIndex];
  });
}

function buildFeedItem(index: number): FeedItemData {
  return {
    id: `feed-${index}`,
    author: buildAuthor(index),
    content: buildContent(index),
    images: buildImages(index),
    likeCount: 20 + seededNumber(index + 17, 600),
    commentCount: 3 + seededNumber(index + 29, 120),
    publishAt: `${1 + seededNumber(index + 3, 12)} 分钟前`,
  };
}

export async function fetchMockFeedPage(
  page: number,
): Promise<FeedPageResponse> {
  const safePage = Math.max(1, Math.min(page, FEED_TOTAL_PAGES));
  const start = (safePage - 1) * FEED_PAGE_SIZE;
  const end = Math.min(start + FEED_PAGE_SIZE, FEED_TOTAL_COUNT);

  await sleep(safePage === 1 ? 350 : 280);

  return {
    list: Array.from({ length: end - start }, (_, offset) =>
      buildFeedItem(start + offset),
    ),
    page: safePage,
    pageSize: FEED_PAGE_SIZE,
    total: FEED_TOTAL_COUNT,
    totalPages: FEED_TOTAL_PAGES,
    hasMore: safePage < FEED_TOTAL_PAGES,
  };
}

export async function fetchMockFeedDetail(id: string): Promise<FeedItemDetail> {
  const index = Number(id.replace('feed-', '')) || 0;

  await sleep(260 + seededNumber(index + 41, 160));

  if (index % 7 === 0) {
    throw new Error('模拟详情接口异常：该 item 需要手动重试');
  }

  return {
    detail: DETAIL_SNIPPETS[index % DETAIL_SNIPPETS.length],
    commentPreview: Array.from(
      { length: 1 + seededNumber(index + 53, 3) },
      (_, commentIndex) =>
        COMMENT_SNIPPETS[(index + commentIndex) % COMMENT_SNIPPETS.length],
    ),
    hasLiked: index % 2 === 0,
    fetchedAt: `${Date.now()}`,
  };
}
