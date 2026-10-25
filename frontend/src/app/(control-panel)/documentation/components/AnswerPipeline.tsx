'use client';

import { useState } from 'react';
import Paper from '@mui/material/Paper';
import ToggleButton from '@mui/material/ToggleButton';
import ToggleButtonGroup from '@mui/material/ToggleButtonGroup';
import Typography from '@mui/material/Typography';
import FuseSvgIcon from '@fuse/core/FuseSvgIcon';
import clsx from 'clsx';

type QueryType = 'research' | 'compare' | 'advisory';

interface Stage {
	id: string;
	title: string;
	icon: string;
	detail: string;
}

const STAGES: Stage[] = [
	{
		id: 'question',
		title: 'Your question',
		icon: 'heroicons-outline:chat-bubble-left',
		detail: 'Chat sends your question to the HRAS API. Nothing else from your screen goes with it.'
	},
	{
		id: 'check',
		title: 'Knowledge base check',
		icon: 'heroicons-outline:circle-stack',
		detail: 'HRAS counts the UHRI records it has loaded. If there are none, it stops here and tells you to run ingestion.'
	},
	{
		id: 'supervisor',
		title: 'Supervisor',
		icon: 'heroicons-outline:arrows-right-left',
		detail: 'The language model reads your question and labels it research, compare or advisory. It also picks out any countries and themes you named. If the label is unclear, HRAS treats the question as research.'
	},
	{
		id: 'research',
		title: 'Research agent',
		icon: 'heroicons-outline:magnifying-glass',
		detail: 'Searches the UHRI records for your question (8 matches), then runs a search for each country you named (5 each). It keeps the top 10 as sources and writes a short summary of what it found.'
	},
	{
		id: 'compare',
		title: 'Compare agent',
		icon: 'heroicons-outline:scale',
		detail: 'Pulls 5 records for each country you named and asks the language model to compare them. If it found no countries, it runs one general search (10 matches) instead.'
	},
	{
		id: 'advisory',
		title: 'Advisory agent',
		icon: 'heroicons-outline:pencil-square',
		detail: 'Writes the final answer in a professional UN style, using the summary or comparison from the step before and the top sources.'
	},
	{
		id: 'answer',
		title: 'Answer + sources',
		icon: 'heroicons-outline:document-check',
		detail: 'You see the answer in Chat. Under it, a "sources" link opens the UHRI records the answer drew on.'
	}
];

const PATHS: Record<QueryType, string[]> = {
	research: ['question', 'check', 'supervisor', 'research', 'advisory', 'answer'],
	compare: ['question', 'check', 'supervisor', 'compare', 'advisory', 'answer'],
	advisory: ['question', 'check', 'supervisor', 'advisory', 'answer']
};

const EXAMPLES: Record<QueryType, string> = {
	research: 'What UPR recommendations has Kenya received on freedom of expression?',
	compare: 'Compare recommendations on torture for Brazil and Mexico.',
	advisory: 'Summarise the key concerns we should raise at the next review.'
};

/**
 * Interactive walk-through of the agent workflow: pick a question type, then click a stage to read what it does.
 */
function AnswerPipeline() {
	const [queryType, setQueryType] = useState<QueryType>('research');
	const [selectedId, setSelectedId] = useState('supervisor');

	const path = PATHS[queryType];
	const stages = STAGES.filter((stage) => path.includes(stage.id));
	const selected = STAGES.find((stage) => stage.id === selectedId && path.includes(stage.id)) ?? stages[0];

	return (
		<div className="flex flex-col gap-4">
			<div className="flex flex-col gap-2">
				<Typography
					variant="subtitle2"
					color="text.secondary"
				>
					1. Pick a question type
				</Typography>
				<ToggleButtonGroup
					value={queryType}
					exclusive
					size="small"
					onChange={(_event, value: QueryType | null) => value && setQueryType(value)}
					aria-label="Question type"
				>
					<ToggleButton value="research">Research</ToggleButton>
					<ToggleButton value="compare">Compare</ToggleButton>
					<ToggleButton value="advisory">Advisory</ToggleButton>
				</ToggleButtonGroup>
				<Typography
					variant="body2"
					color="text.secondary"
				>
					For example: <em>{EXAMPLES[queryType]}</em>
				</Typography>
			</div>

			<div className="flex flex-col gap-2">
				<Typography
					variant="subtitle2"
					color="text.secondary"
				>
					2. Click a stage to see what happens there
				</Typography>
				<ol className="flex flex-wrap items-center gap-2">
					{stages.map((stage, index) => (
						<li
							key={stage.id}
							className="flex items-center gap-2"
						>
							<button
								type="button"
								onClick={() => setSelectedId(stage.id)}
								aria-pressed={selected.id === stage.id}
								className={clsx(
									'flex items-center gap-1.5 rounded-lg border px-3 py-2 text-sm transition-colors',
									selected.id === stage.id
										? 'border-[#0072BC] bg-[#0072BC] text-white'
										: 'border-current/20 hover:border-[#0072BC] hover:text-[#0072BC]'
								)}
							>
								<FuseSvgIcon size={16}>{stage.icon}</FuseSvgIcon>
								{stage.title}
							</button>
							{index < stages.length - 1 && (
								<FuseSvgIcon
									size={16}
									className="opacity-50"
								>
									heroicons-outline:arrow-right
								</FuseSvgIcon>
							)}
						</li>
					))}
				</ol>
			</div>

			<Paper
				variant="outlined"
				className="flex gap-3 p-4"
				aria-live="polite"
			>
				<FuseSvgIcon
					size={24}
					className="shrink-0 text-[#0072BC]"
				>
					{selected.icon}
				</FuseSvgIcon>
				<div>
					<Typography
						variant="subtitle1"
						className="font-semibold"
					>
						{selected.title}
					</Typography>
					<Typography variant="body2">{selected.detail}</Typography>
				</div>
			</Paper>

			{queryType === 'advisory' && (
				<Typography
					variant="body2"
					color="text.secondary"
				>
					Notice the gap: advisory questions skip the search. The answer comes from the language model alone
					and usually has no sources. Use a research question when you need citations.
				</Typography>
			)}
		</div>
	);
}

export default AnswerPipeline;
