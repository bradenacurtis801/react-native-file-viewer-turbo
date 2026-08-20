import { TurboModuleRegistry, type TurboModule } from 'react-native';
import type { EventEmitter } from 'react-native/Libraries/Types/CodegenTypes';

export enum DoneButtonPosition {
  left = 'left',
  right = 'right',
}

export enum ModalPresentationStyle {
  automatic = 'automatic',
  pageSheet = 'pageSheet',
  fullScreen = 'fullScreen',
  formSheet = 'formSheet',
}

export type Options = {
  displayName?: string;
  doneButtonTitle?: string;
  showOpenWithDialog?: boolean;
  showAppsSuggestions?: boolean;
  doneButtonPosition?: DoneButtonPosition;
  /**
   * iOS only. How the preview is presented — `pageSheet` (the default) is
   * the swipeable "card" look (rounded top corners, dims the app behind
   * it, matches system share sheets/Mail compose); `fullScreen` covers the
   * whole screen with no gesture dismissal of its own; `formSheet` is a
   * smaller centered card (mostly an iPad look); `automatic` defers to
   * whatever the OS resolves `.automatic` to in the presenting context,
   * which is NOT guaranteed to be `pageSheet` (this option exists because
   * relying on that resolution is what motivated adding it at all).
   * @default 'pageSheet'
   */
  modalPresentationStyle?: ModalPresentationStyle;
  /**
   * iOS only. Set `true` to require an explicit Done tap to close the
   * preview — swipe-down and tap-outside-to-dismiss are both disabled.
   * Leave unset/`false` to allow either, in addition to Done.
   * @default false
   */
  disableInteractiveDismissal?: boolean;
};

export interface Spec extends TurboModule {
  open(path: string, options: Options): Promise<void>;
  readonly onViewerDidDismiss: EventEmitter<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('FileViewerTurbo');
