import React, {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
} from 'react';
import {ImagePreviewModal} from '../components/common/ImagePreviewModal';

type ImagePreviewPayload = {
  images: string[];
  initialIndex?: number;
};

type ImagePreviewContextValue = {
  openImagePreview: (payload: ImagePreviewPayload) => void;
  closeImagePreview: () => void;
};

const ImagePreviewContext = createContext<ImagePreviewContextValue | null>(null);
const EMPTY_IMAGES: string[] = [];

export function ImagePreviewProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  const [payload, setPayload] = useState<ImagePreviewPayload | null>(null);

  const closeImagePreview = useCallback(() => {
    setPayload(null);
  }, []);

  const openImagePreview = useCallback((nextPayload: ImagePreviewPayload) => {
    if (!nextPayload.images.length) {
      return;
    }

    const safeInitialIndex = Math.min(
      Math.max(nextPayload.initialIndex ?? 0, 0),
      nextPayload.images.length - 1,
    );

    setPayload({
      images: nextPayload.images,
      initialIndex: safeInitialIndex,
    });
  }, []);

  const contextValue = useMemo(
    () => ({
      openImagePreview,
      closeImagePreview,
    }),
    [closeImagePreview, openImagePreview],
  );

  return (
    <ImagePreviewContext.Provider value={contextValue}>
      {children}
      <ImagePreviewModal
        visible={payload != null}
        images={payload?.images ?? EMPTY_IMAGES}
        initialIndex={payload?.initialIndex ?? 0}
        onClose={closeImagePreview}
      />
    </ImagePreviewContext.Provider>
  );
}

export function useImagePreview() {
  const context = useContext(ImagePreviewContext);

  if (!context) {
    throw new Error('useImagePreview must be used within ImagePreviewProvider');
  }

  return context;
}