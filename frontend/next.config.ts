import type { NextConfig } from 'next';

const isTurbopack = process.env.TURBOPACK === '1';

// Conditionally add webpack configuration only when NOT using turbopack
const nextConfig: NextConfig = {
	reactStrictMode: false,
	eslint: {
		// Only enable ESLint in development
		ignoreDuringBuilds: process.env.NODE_ENV === 'production'
	},
	typescript: {
		// Dangerously allow production builds to successfully complete even if
		// your project has type errors.
		// ignoreBuildErrors: true
	},
	turbopack: {
		rules: {}
	},
	...(!isTurbopack && {
		webpack: (config) => {
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
