import { Container, getContainer } from '@cloudflare/containers';

// Every Worker var and secret is a string; bindings (like BACKEND) are objects and stay behind.
function containerEnv(env: Env): Record<string, string> {
	const vars = Object.fromEntries(
		Object.entries(env).filter((entry): entry is [string, string] => typeof entry[1] === 'string' && entry[1] !== '')
	);

	// Embeddings come from Workers AI's OpenAI-compatible endpoint unless overridden.
	if (!vars.EMBEDDING_BASE_URL && vars.CLOUDFLARE_ACCOUNT_ID) {
		vars.EMBEDDING_BASE_URL = `https://api.cloudflare.com/client/v4/accounts/${vars.CLOUDFLARE_ACCOUNT_ID}/ai/v1`;
	}

	if (!vars.EMBEDDING_API_KEY && vars.CLOUDFLARE_API_TOKEN) {
		vars.EMBEDDING_API_KEY = vars.CLOUDFLARE_API_TOKEN;
	}

	return vars;
}

export class Backend extends Container<Env> {
	defaultPort = 8000;
	sleepAfter = '30m';

	constructor(ctx: DurableObjectState<{}>, env: Env) {
		super(ctx, env);
		this.envVars = containerEnv(env);
	}
}

export default {
	// One named instance: the vector store lives on that container's disk, so every request must reach it.
	async fetch(request: Request, env: Env): Promise<Response> {
		return getContainer(env.BACKEND).fetch(request);
	}
};
