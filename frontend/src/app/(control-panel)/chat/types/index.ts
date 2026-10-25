export interface ChatMessage {
	id: string;
	role: 'user' | 'assistant';
	content: string;
	created_at: string;
}

export interface ChatSource {
	country: string;
	mechanism: string;
	year: string;
	theme: string;
	status: string;
	snippet: string;
	relevance_score?: number;
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
