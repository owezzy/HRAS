import * as React from 'react';
import rtlPlugin from 'stylis-plugin-rtl';
import { useMainTheme } from '@fuse/core/FuseSettings/hooks/fuseThemeHooks';
import { Options, StylisPlugin } from '@emotion/cache';
import { CssBaseline } from '@mui/material';
import { AppRouterCacheProvider } from '@mui/material-nextjs/v15-appRouter';

type MainThemeProviderProps = {
	children: React.ReactNode;
};

const wrapInLayer: (layerName: string) => StylisPlugin = (layerName) => (node) => {
	if (node.root) {
		return;
	}

	// if we're at the root, replace node with `@layer layerName { node }`
	const child = { ...node, parent: node, root: node };
	Object.assign(node, {
		children: [child],
		length: 6,
		parent: null,
		props: [layerName],
		return: '',
		root: null,
		type: '@layer',
		value: `@layer ${layerName}`
	});
};

const emotionCacheOptions: Record<string, Options> = {
	rtl: {
		key: 'muirtl',
		stylisPlugins: [rtlPlugin, wrapInLayer('mui')],
		prepend: false
	},
	ltr: {
		key: 'muiltr',
		stylisPlugins: [wrapInLayer('mui')],
		prepend: false
	}
};

function RootThemeProvider({ children }: MainThemeProviderProps) {
	const mainTheme = useMainTheme();
	const langDirection = mainTheme?.direction;

	// AppRouterCacheProvider flushes Emotion styles into <head> during SSR, so the server and client markup match.
	return (
		<AppRouterCacheProvider
			key={langDirection}
			options={emotionCacheOptions[langDirection]}
		>
			<CssBaseline />

			{children}
		</AppRouterCacheProvider>
	);
}

export default RootThemeProvider;
