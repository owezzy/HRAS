'use client';
import { useCallback, useSyncExternalStore } from 'react';
import { useTheme, Theme } from '@mui/material/styles';

/**
 * Returns whether the screen matches the media query built from the theme.
 * The server snapshot is always false, so hydration renders the same markup as SSR;
 * React then re-renders with the real value from window.matchMedia.
 */
function useThemeMediaQuery(themeCallbackFunc: (theme: Theme) => string) {
	const theme = useTheme();

	const query = themeCallbackFunc(theme).replace('@media ', '');

	const subscribe = useCallback(
		(onChange: () => void) => {
			const mediaQuery = window.matchMedia(query);
			mediaQuery.addEventListener('change', onChange);
			return () => mediaQuery.removeEventListener('change', onChange);
		},
		[query]
	);

	return useSyncExternalStore(
		subscribe,
		() => window.matchMedia(query).matches,
		() => false
	);
}

export default useThemeMediaQuery;
