import type { ViewProps } from 'react-native';
import { codegenNativeComponent } from 'react-native';
import type { HostComponent } from 'react-native';
import type { DirectEventHandler, Double } from 'react-native/Libraries/Types/CodegenTypes';

export interface NativeProps extends ViewProps {
  /** 背景颜色 */
  color?: string;
  /** 圆角半径 */
  cornerRadius?: Double;
  /**
   * 是否启动原生侧持续推送
   * true 时原生每秒推送一次 onValueChange 事件
   * false 时停止推送（默认）
   */
  isActive?: boolean;
  /**
   * 原生侧持续推送的动态值变化事件
   */
  onValueChange?: DirectEventHandler<{
    readonly value: Double;
    readonly timestamp: Double;
  }>;
}

export default codegenNativeComponent<NativeProps>(
  'NativeColoredView',
) as HostComponent<NativeProps>;
