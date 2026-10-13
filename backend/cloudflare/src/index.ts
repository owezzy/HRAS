import { Container, getContainer } from '@cloudflare/containers';

interface Env {
	HRAS_BACKEND: DurableObjectNamespace<HrasBackend>;
	[key: string]: unknown;
}

// Settings the FastAPI app reads from its environment (see backend/src/app/core/config.py).
const PASSTHROUGH = [
	'APP_ENV',
	'DOCS_ENABLED',
	'LLM_PROVIDER',
	'LLM_MODEL',
	'LLM_BASE_URL',
	'LLM_API_KEY',
	'EMBEDDING_MODEL',
	'EMBEDDING_BASE_URL',
	'EMBEDDING_API_KEY',
	'VECTOR_STORE_BACKEND',
	'VECTORIZE_INDEX_NAME',
	'CLOUDFLARE_ACCOUNT_ID',
	'CLOUDFLARE_API_TOKEN',
	'CORS_ORIGINS',
	'TRUSTED_HOSTS',
	'LANGSMITH_API_KEY',
	'USE_LANGSMITH_TRACING'
];

function containerEnv(env: Env): Record<string, string> {
	const vars: Record<string, string> = { PORT: '8000' };

	for (const key of PASSTHROUGH) {
		const value = env[key];

		if (typeof value === 'string' && value !== '') {
			vars[key] = value;
		}
	}

	// Embeddings come from Workers AI's OpenAI-compatible endpoint unless overridden.
	if (!vars.EMBEDDING_BASE_URL && vars.CLOUDFLARE_ACCOUNT_ID) {
		vars.EMBEDDING_BASE_URL = `https://api.cloudflare.com/client/v4/accounts/${vars.CLOUDFLARE_ACCOUNT_ID}/ai/v1`;
	}

	if (!vars.EMBEDDING_API_KEY && vars.CLOUDFLARE_API_TOKEN) {
		vars.EMBEDDING_API_KEY = vars.CLOUDFLARE_API_TOKEN;
	}

	return vars;
}

export class HrasBackend extends Container<Env> {
	defaultPort = 8000;
	// Sleep after 10 idle minutes so an unused demo costs almost nothing.
	sleepAfter = '10m';

	constructor(ctx: DurableObjectState<Env>, env: Env) {
		super(ctx, env);
		this.envVars = containerEnv(env);
	}
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		// One instance: the app keeps in-memory chat state, so requests must not be spread.
		return getContainer(env.HRAS_BACKEND).fetch(request);
	}
} satisfies ExportedHandler<Env>;
