import type { NextConfig } from 'next';

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

	typescript: {
		// Dangerously allow production builds to successfully complete even if
		// your project has type errors.
		// ignoreBuildErrors: true
	}
};

export default nextConfig;

// Lets `next dev` read Cloudflare bindings and vars from wrangler.jsonc.
if (process.env.NODE_ENV === 'development') {
	void import('@opennextjs/cloudflare').then(({ initOpenNextCloudflareForDev }) => initOpenNextCloudflareForDev());
}

