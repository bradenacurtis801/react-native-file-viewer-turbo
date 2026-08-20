import FileViewerTurbo, { type Options } from './NativeFileViewerTurbo';
import type { EventSubscription } from 'react-native';

// Re-exported so callers can actually reference these enum types — TS
// string enums are nominal, not structural, so without this a caller
// couldn't pass `doneButtonPosition`/`modalPresentationStyle` in a
// type-safe way at all (a plain string literal isn't assignable to an enum
// type even when the values match).
export {
  DoneButtonPosition,
  ModalPresentationStyle,
} from './NativeFileViewerTurbo';
export type { Options } from './NativeFileViewerTurbo';

let dismissListener: EventSubscription | null = null;

export async function open(
  path: string,
  options: Partial<Options & { onDismiss: () => void }> = {}
) {
  const { onDismiss, ...nativeOptions } = options;

  dismissListener = FileViewerTurbo.onViewerDidDismiss(() => {
    onDismiss?.();
    dismissListener?.remove();
  });

  await FileViewerTurbo.open(normalize(path), nativeOptions as Options);
}

function normalize(path: string) {
  const filePrefix = 'file://';
  if (path.startsWith(filePrefix)) {
    path = path.substring(filePrefix.length);
    try {
      path = decodeURI(path);
    } catch {
      // ignore decode errors
    }
  }

  return path;
}
