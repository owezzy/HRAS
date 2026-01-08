import { useMutation } from '@tanstack/react-query';
import type { ChatRequest, ChatResponse } from '../types';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

export class ChatError extends Error {
	code: string;

	constructor(message: string, code = 'UNKNOWN_ERROR') {
		super(message);
		this.name = 'ChatError';
		this.code = code;
	}
}

async function sendChatMessage(request: ChatRequest): Promise<ChatResponse> {
	let response: Response;

	try {
		response = await fetch(`${API_URL}/api/v1/chat`, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json'
			},
			body: JSON.stringify(request)
		});
	} catch (error) {
		// Network errors (connection refused, timeout, etc.)
		if (error instanceof TypeError && error.message.includes('fetch')) {
			throw new ChatError(
				'Unable to connect to the server. Please ensure the backend is running on port 8000.',
				'CONNECTION_ERROR'
			);
		}

		throw new ChatError('Network error. Please check your internet connection.', 'NETWORK_ERROR');
	}

	if (!response.ok) {
		// Try to parse error details from response
		let errorMessage = `Request failed with status ${response.status}`;
		let errorCode = 'API_ERROR';

		try {
			const errorData = await response.json();

			if (errorData.detail) {
				errorMessage = errorData.detail;

				// Detect specific error types
				if (errorMessage.includes('quota') || errorMessage.includes('rate limit')) {
					errorCode = 'QUOTA_EXCEEDED';
					errorMessage = 'OpenAI API quota exceeded. Please check your billing details.';
				} else if (errorMessage.includes('API key')) {
					errorCode = 'INVALID_API_KEY';
					errorMessage = 'Invalid API key. Please check your OpenAI API configuration.';
				} else if (errorMessage.includes('not been initialized')) {
					errorCode = 'NO_DATA';
					errorMessage = 'The knowledge base is empty. Please run data ingestion first.';
				}
			}
		} catch {
			// Response wasn't JSON, use default message
		}

		throw new ChatError(errorMessage, errorCode);
	}

	return response.json();
}

export function useChatMutation() {
	return useMutation({
		mutationFn: sendChatMessage
	});
}
