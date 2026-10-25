export type QueryType = 'research' | 'compare' | 'advisory';

export interface QuestionType {
	id: QueryType;
	title: string;
	icon: string;
	description: string;
	example: string;
	/** Stage ids from AnswerPipeline, in the order the question passes through them. */
	path: string[];
}

/**
 * The three routes the supervisor agent can choose (backend/src/app/ai/agents/graph.py).
 */
export const QUESTION_TYPES: QuestionType[] = [
	{
		id: 'research',
		title: 'Research',
		icon: 'heroicons-outline:magnifying-glass',
		description: 'Facts about recommendations, documents or situations. HRAS searches the records and cites them.',
		example: 'What UPR recommendations has Kenya received on freedom of expression?',
		path: ['question', 'check', 'supervisor', 'research', 'advisory', 'answer']
	},
	{
		id: 'compare',
		title: 'Compare',
		icon: 'heroicons-outline:scale',
		description:
			'Two or more countries side by side, or patterns across them. Name every country you want in the comparison.',
		example: 'Compare recommendations on torture for Brazil and Mexico.',
		path: ['question', 'check', 'supervisor', 'compare', 'advisory', 'answer']
	},
	{
		id: 'advisory',
		title: 'Advisory',
		icon: 'heroicons-outline:pencil-square',
		description:
			'Guidance, priorities or a synthesis. HRAS answers from the language model without a fresh search, so expect few or no sources.',
		example: 'What should we prioritise when preparing for a treaty body review?',
		path: ['question', 'check', 'supervisor', 'advisory', 'answer']
	}
];
