import type { ViewProps } from 'react-native';
import { codegenNativeComponent } from 'react-native';
import type { HostComponent } from 'react-native';
import type { DirectEventHandler, Double, Int32 } from 'react-native/Libraries/Types/CodegenTypes';

export interface NativeProps extends ViewProps {
  cardData?: string;
  actions?: string;
  cardType?: Int32;
  cornerRadius?: Double;
  enableShadow?: boolean;
  onCardPress?: DirectEventHandler<{
    readonly cardId: string;
  }>;
  onActionPress?: DirectEventHandler<{
    readonly cardId: string;
    readonly actionId: string;
    readonly actionType: Int32;
  }>;
  onExposure?: DirectEventHandler<{
    readonly cardId: string;
    readonly timestamp: Double;
  }>;
}

export default codegenNativeComponent<NativeProps>(
  'BusinessCardFabricView',
) as HostComponent<NativeProps>;
