import React, { memo, useCallback, useEffect, useState } from 'react';
import {
  Pressable,
  StyleSheet,
  Text,
  type TextLayoutEvent,
} from 'react-native';

const COLLAPSED_LINES = 3;

function ExpandableTextInner({ content }: { content: string }) {
  const [expanded, setExpanded] = useState(false);
  const [isTruncated, setIsTruncated] = useState(false);
  const [measured, setMeasured] = useState(false);

  useEffect(() => {
    setExpanded(false);
    setIsTruncated(false);
    setMeasured(false);
  }, [content]);

  const onMeasureTextLayout = useCallback((event: TextLayoutEvent) => {
    if (measured) {
      return;
    }

    setIsTruncated(event.nativeEvent.lines.length > COLLAPSED_LINES);
    setMeasured(true);
  }, [measured]);

  const toggleExpanded = useCallback(() => {
    setExpanded(prev => !prev);
  }, []);

  return (
    <>
      <Text style={styles.content} numberOfLines={expanded ? undefined : COLLAPSED_LINES}>
        {content}
      </Text>

      {!expanded && !measured ? (
        <Text style={[styles.content, styles.measureText]} onTextLayout={onMeasureTextLayout}>
          {content}
        </Text>
      ) : null}

      {isTruncated ? (
        <Pressable onPress={toggleExpanded} style={styles.toggleButton}>
          <Text style={styles.toggleText}>{expanded ? '收起' : '展开'}</Text>
        </Pressable>
      ) : null}
    </>
  );
}

export const ExpandableText = memo(
  ExpandableTextInner,
  (prevProps, nextProps) => prevProps.content === nextProps.content,
);

const styles = StyleSheet.create({
  content: {
    fontSize: 14,
    lineHeight: 21,
    color: '#1E293B',
  },
  measureText: {
    position: 'absolute',
    opacity: 0,
    zIndex: -1,
    left: 0,
    right: 0,
    pointerEvents: 'none',
  },
  toggleButton: {
    alignSelf: 'flex-start',
    marginTop: -2,
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: '#EFF6FF',
  },
  toggleText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#2563EB',
  },
});
