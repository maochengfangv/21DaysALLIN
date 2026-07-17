import {
  NativeEventEmitter,
  NativeModules,
  type EmitterSubscription,
} from 'react-native';
import {
  BUSINESS_EVENT_NAME,
  CALLBACK_IDS,
  type BusinessEventEnvelope,
  type CallbackId,
  type ScenePayloadMap,
} from '../../shared/businessConstants';

type GenericSceneHandler = (payload: ScenePayloadMap[CallbackId]) => void;

const getBusinessEmitter = (): NativeEventEmitter | null => {
  const nativeModule = NativeModules.RNBusinessEventEmitter;

  if (!nativeModule) {
    if (__DEV__) {
      console.warn(
        '[BusinessDataHandler] NativeModules.RNBusinessEventEmitter 未注册，跳过监听。',
      );
    }
    return null;
  }

  return new NativeEventEmitter(nativeModule);
};

class BusinessDataHandler {
  private emitter: NativeEventEmitter | null = null;

  private subscription: EmitterSubscription | null = null;

  private handlers: Partial<Record<CallbackId, GenericSceneHandler>> = {};

  register<K extends CallbackId>(
    callbackId: K,
    handler: (payload: ScenePayloadMap[K]) => void,
  ): () => void {
    this.handlers[callbackId] = handler as GenericSceneHandler;

    return () => {
      delete this.handlers[callbackId];
    };
  }

  startListening(): void {
    if (this.subscription) {
      return;
    }

    this.emitter = getBusinessEmitter();
    if (!this.emitter) {
      return;
    }

    this.subscription = this.emitter.addListener(
      BUSINESS_EVENT_NAME,
      this.handleNativeEvent,
    );
  }

  stopListening(): void {
    this.subscription?.remove();
    this.subscription = null;
    this.emitter = null;
  }

  clear(): void {
    this.handlers = {};
  }

  private handleNativeEvent = (event: BusinessEventEnvelope): void => {
    const callbackId = event?.callbackId as CallbackId | undefined;
    const rawPayload = (event?.payload ?? {}) as Record<string, unknown>;

    if (!callbackId) {
      console.warn('[BusinessDataHandler] 收到缺少 callbackId 的事件，已忽略。');
      return;
    }

    switch (callbackId) {
      case CALLBACK_IDS.SCENE_A: {
        const payload: ScenePayloadMap[typeof CALLBACK_IDS.SCENE_A] = {
          title: String(rawPayload?.title ?? ''),
          count: Number(rawPayload?.count ?? 0),
        };
        (this.handlers[callbackId] as
          | ((value: typeof payload) => void)
          | undefined)?.(payload);
        return;
      }

      case CALLBACK_IDS.SCENE_B: {
        const metadata =
          rawPayload?.metadata && typeof rawPayload.metadata === 'object'
            ? (rawPayload.metadata as Record<string, unknown>)
            : {};
        const payload: ScenePayloadMap[typeof CALLBACK_IDS.SCENE_B] = {
          url: String(rawPayload?.url ?? ''),
          metadata,
        };
        (this.handlers[callbackId] as
          | ((value: typeof payload) => void)
          | undefined)?.(payload);
        return;
      }

      case CALLBACK_IDS.SCENE_C: {
        const status = rawPayload?.status === 'success' ? 'success' : 'fail';
        const payload: ScenePayloadMap[typeof CALLBACK_IDS.SCENE_C] = {
          status,
          message: String(rawPayload?.message ?? ''),
        };
        (this.handlers[callbackId] as
          | ((value: typeof payload) => void)
          | undefined)?.(payload);
        return;
      }

      default:
        console.warn(
          `[BusinessDataHandler] 未匹配的 callbackId: ${String(callbackId)}`,
          rawPayload,
        );
    }
  };
}

export const businessDataHandler = new BusinessDataHandler();
