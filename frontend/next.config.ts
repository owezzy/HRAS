import type { NextConfig } from 'next';

const isTurbopack = process.env.TURBOPACK === '1';

const nextConfig: NextConfig = {
	output: 'standalone',
	reactStrictMode: false,

	// Enable experimental features for faster builds
	experimental: {
		// Disable CSS optimization temporarily to fix build
		// optimizeCss: true,
	},

	// Turbopack configuration (stable)
	turbopack: {
		rules: {}
	},

	eslint: {
		ignoreDuringBuilds: process.env.NODE_ENV === 'production'
	},

	typescript: {
		// Dangerously allow production builds to successfully complete even if
		// your project has type errors.
		// ignoreBuildErrors: true
	},

	// Webpack optimizations for non-Turbopack builds
	...(!isTurbopack && {
		webpack: (config) => {
			// Next's default chunk splitting is kept: a single forced "vendors" chunk breaks
			// chunk loading in the OpenNext Cloudflare Worker ("Unknown chunk").

			// Add custom rules
			if (config.module && config.module.rules) {
				config.module.rules.push({
					test: /\.(json|js|ts|tsx|jsx)$/,
					resourceQuery: /raw/,
					use: 'raw-loader'
				});
			}

			return config;
		}
	})
};

export default nextConfig;

// Lets `next dev` read Cloudflare bindings and vars from wrangler.jsonc.
if (process.env.NODE_ENV === 'development') {
	void import('@opennextjs/cloudflare').then(({ initOpenNextCloudflareForDev }) => initOpenNextCloudflareForDev());
}

