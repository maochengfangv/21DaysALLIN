/**
 * @format
 */

import { AppRegistry } from 'react-native';
import App from './App';
import { name as appName } from './app.json';
import CardListScreen from './src/components/cards/CardListScreen';

AppRegistry.registerComponent(appName, () => App);
AppRegistry.registerComponent('BusinessCardList', () => CardListScreen);
