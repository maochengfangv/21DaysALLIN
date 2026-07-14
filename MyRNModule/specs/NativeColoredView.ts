import type { ViewProps } from 'react-native';
import { codegenNativeComponent } from 'react-native';
import type { HostComponent } from 'react-native';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';

export interface NativeProps extends ViewProps {
  /** 背景颜色 */
  color?: string;
  /** 圆角半径 */
  cornerRadius?: Double;
}

export default codegenNativeComponent<NativeProps>(
  'NativeColoredView',
) as HostComponent<NativeProps>;
