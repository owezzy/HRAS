import { Container, getContainer } from '@cloudflare/containers';

// Worker vars and secrets forwarded into the FastAPI container's environment.
const FORWARDED_ENV = [
	'APP_ENV',
	'AUTO_INGEST_ON_EMPTY',
	'CORS_ORIGINS',
	'DOCS_ENABLED',
	'EMBEDDING_API_KEY',
	'EMBEDDING_BASE_URL',
	'EMBEDDING_MODEL',
	'LANGSMITH_API_KEY',
	'LANGSMITH_ENDPOINT',
	'LANGSMITH_PROJECT',
	'LLM_API_KEY',
	'LLM_MODEL',
	'LLM_PROVIDER',
	'TRUSTED_HOSTS',
	'USE_ASYNC_TOOLS',
	'USE_LANGSMITH_TRACING'
] as const;

export class Backend extends Container<Env> {
	defaultPort = 8000;
	sleepAfter = '30m';

	constructor(ctx: DurableObjectState<{}>, env: Env) {
		super(ctx, env);
		// Secrets are not in the generated Env type, so read every forwarded key untyped.
		const source = env as unknown as Record<string, string | undefined>;
		this.envVars = Object.fromEntries(
			FORWARDED_ENV.flatMap((key) => (source[key] === undefined ? [] : [[key, source[key]]]))
		);
	}
}

export default {
	// One named instance: the vector store lives on that container's disk, so every request must reach it.
	async fetch(request: Request, env: Env): Promise<Response> {
		return getContainer(env.BACKEND).fetch(request);
	}
};
