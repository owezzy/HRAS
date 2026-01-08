export interface ChatMessage {
	id: string;
	role: 'user' | 'assistant';
	content: string;
	created_at: string;
}

export interface ChatSource {
	title: string;
	url?: string;
	snippet: string;
	metadata: Record<string, unknown>;
}

export interface ChatRequest {
	message: string;
	conversation_id?: string;
}

export interface ChatResponse {
	conversation_id: string;
	message: ChatMessage;
	sources: ChatSource[];
}

export interface MessageWithSources {
	message: ChatMessage;
	sources?: ChatSource[];
}
