// Web build of `index.tsx`, selected through the `browser` condition in
// package.json `exports` (Metro picks export conditions per platform, and
// never applies `.web` file extensions to an `exports` target).
//
// It never imports `NativeFileViewerTurbo.ts`: that file's default export is
// `TurboModuleRegistry.getEnforcing(...)`, which throws as soon as the file
// loads on web, and it has to keep exactly that shape for codegen. So the
// two enums are re-declared here as plain objects, with a compile-time check
// that keeps them identical to the spec's.

import type * as Spec from './NativeFileViewerTurbo';

export type { Options } from './NativeFileViewerTurbo';

// Same keys, same string values (enum members are nominal, so compare their
// string forms).
type SameAs<E> = { readonly [K in keyof E]: `${E[K] & string}` };

export const DoneButtonPosition = {
  left: 'left',
  right: 'right',
} as const satisfies SameAs<typeof Spec.DoneButtonPosition>;

export const ModalPresentationStyle = {
  automatic: 'automatic',
  pageSheet: 'pageSheet',
  fullScreen: 'fullScreen',
  formSheet: 'formSheet',
} as const satisfies SameAs<typeof Spec.ModalPresentationStyle>;

/** A browser has no native file preview (and paths here are device-local),
 * so this always rejects — callers already handle `open` failing. */
export async function open(
  _path: string,
  _options: Partial<Spec.Options & { onDismiss: () => void }> = {}
): Promise<void> {
  throw new Error(
    'react-native-file-viewer-turbo: file preview needs the iOS or Android app; it is not available on web.'
  );
}
