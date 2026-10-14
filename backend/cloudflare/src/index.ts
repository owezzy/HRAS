import { Container, getContainer } from '@cloudflare/containers';

export class Backend extends Container<Env> {
	defaultPort = 8000;
	sleepAfter = '30m';

	constructor(ctx: DurableObjectState<{}>, env: Env) {
		super(ctx, env);
		// Every Worker var and secret is a string; bindings (like BACKEND) are objects and stay behind.
		this.envVars = Object.fromEntries(
			Object.entries(env).filter((entry): entry is [string, string] => typeof entry[1] === 'string')
		);
	}
}

export default {
	// One named instance: the vector store lives on that container's disk, so every request must reach it.
	async fetch(request: Request, env: Env): Promise<Response> {
		return getContainer(env.BACKEND).fetch(request);
	}
};
