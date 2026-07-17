/**
 * 原生 UI 容器 -> RN 的业务事件共享常量
 *
 * 设计约束：
 * - 固定 event name，只通过 callbackId 区分场景
 * - 新增业务只需扩展 CALLBACK_IDS / ScenePayloadMap
 * - RN 侧禁止硬编码 callbackId / event name
 */

export const BUSINESS_EVENT_NAME = 'BusinessData';

export const CALLBACK_IDS = {
  SCENE_A: 'scene_a',
  SCENE_B: 'scene_b',
  SCENE_C: 'scene_c',
} as const;

export type CallbackId = (typeof CALLBACK_IDS)[keyof typeof CALLBACK_IDS];

export interface ScenePayloadMap {
  [CALLBACK_IDS.SCENE_A]: {
    title: string;
    count: number;
  };
  [CALLBACK_IDS.SCENE_B]: {
    url: string;
    metadata: Record<string, unknown>;
  };
  [CALLBACK_IDS.SCENE_C]: {
    status: 'success' | 'fail';
    message: string;
  };
}

export type BusinessEventEnvelope = {
  callbackId?: string;
  payload?: unknown;
};
