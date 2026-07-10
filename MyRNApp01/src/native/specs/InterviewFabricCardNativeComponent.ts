import type {ColorValue, HostComponent, ViewProps} from 'react-native';
import type {Float} from 'react-native/Libraries/Types/CodegenTypes';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

export interface NativeProps extends ViewProps {
  label?: string;
  cardBackgroundColor?: ColorValue;
  cornerRadius?: Float;
}

export default codegenNativeComponent<NativeProps>(
  'InterviewFabricCard',
) as HostComponent<NativeProps>;
