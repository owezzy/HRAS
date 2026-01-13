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
		webpack: (config, { dev, isServer }) => {
			// Optimization for production builds
			if (!dev) {
				config.optimization = {
					...config.optimization,
					// Enable parallel processing
					minimize: true,
					// Split chunks for better caching
					splitChunks: {
						chunks: 'all',
						cacheGroups: {
							vendor: {
								test: /[\\/]node_modules[\\/]/,
								name: 'vendors',
								chunks: 'all',
							},
						},
					},
				};
			}

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
