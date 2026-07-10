import React from 'react';
import type {ColorValue, StyleProp, ViewStyle} from 'react-native';
import NativeInterviewFabricCard from './specs/InterviewFabricCardNativeComponent';

export function InterviewFabricCard({
  label,
  cardBackgroundColor,
  cornerRadius = 16,
  width = 240,
  height = 140,
  style,
}: {
  label?: string;
  cardBackgroundColor?: ColorValue;
  cornerRadius?: number;
  width?: number;
  height?: number;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <NativeInterviewFabricCard
      label={label}
      cardBackgroundColor={cardBackgroundColor}
      cornerRadius={cornerRadius}
      style={[{width, height}, style]}
    />
  );
}
