import { ReactNode } from 'react';
import Alert from '@mui/material/Alert';
import Link from '@mui/material/Link';
import Paper from '@mui/material/Paper';
import Typography from '@mui/material/Typography';
import FuseSvgIcon from '@fuse/core/FuseSvgIcon';
import AnswerPipeline from './AnswerPipeline';
import TryQuestion from './TryQuestion';
import { QUESTION_TYPES } from './questionTypes';
import { Kbd, TextList } from './TutorialText';

export interface TutorialStep {
	id: string;
	title: string;
	summary: string;
	content: ReactNode;
}

export const TUTORIAL_STEPS: TutorialStep[] = [
	{
		id: 'meet',
		title: 'Meet HRAS',
		summary: 'What the assistant does, and what it does not.',
		content: (
			<div className="flex flex-col gap-4">
				<Typography variant="body1">
					HRAS (Human Rights Advisory System) helps you find and make sense of UN human rights
					recommendations. You ask a question in plain language. HRAS searches the{' '}
					<Link
						href="https://uhri.ohchr.org"
						target="_blank"
						rel="noopener noreferrer"
					>
						Universal Human Rights Index (UHRI)
					</Link>
					, picks the relevant recommendations and writes an answer with its sources attached.
				</Typography>
				<Typography variant="body1">It is good at:</Typography>
				<TextList
					items={[
						'Finding recommendations by country, mechanism (UPR, CAT, CERD, CEDAW and others) or theme',
						'Comparing what different countries were asked to do',
						'Summarising concerns before a review or a mission'
					]}
				/>
				<Alert
					severity="info"
					icon={<FuseSvgIcon>heroicons-outline:light-bulb</FuseSvgIcon>}
				>
					Think of HRAS as a well-read colleague who never tires of the UHRI, not as the final word. It can
					misread a record or miss one. Check the sources before you quote anything.
				</Alert>
				<Typography
					variant="body2"
					color="text.secondary"
				>
					The current deployment loads a sample of UHRI recommendations, not the full index. If a country has
					no records loaded, HRAS has little to say about it.
				</Typography>
			</div>
		)
	},
	{
		id: 'ask',
		title: 'Ask your first question',
		summary: 'Send a question and read the reply.',
		content: (
			<div className="flex flex-col gap-4">
				<TextList
					ordered
					items={[
						<>
							Open <strong>Chat</strong> from the menu on the left.
						</>,
						'Type your question in the box at the bottom of the page.',
						<>
							Press <Kbd>Enter</Kbd> to send. Press <Kbd>Shift</Kbd> + <Kbd>Enter</Kbd> for a new line.
						</>,
						<>
							Wait while HRAS shows <em>Thinking...</em>. A full answer makes up to three calls to the
							language model, so give it a moment.
						</>
					]}
				/>
				<Typography variant="body1">
					A good question names the country, the mechanism or the theme. Compare these two:
				</Typography>
				<div className="grid gap-3 sm:grid-cols-2">
					<Paper
						variant="outlined"
						className="p-4"
					>
						<Typography
							variant="subtitle2"
							color="error"
						>
							Vague
						</Typography>
						<Typography variant="body2">Tell me about human rights.</Typography>
					</Paper>
					<Paper
						variant="outlined"
						className="p-4"
					>
						<Typography
							variant="subtitle2"
							color="success"
						>
							Specific
						</Typography>
						<Typography variant="body2">
							What did CERD recommend to South Africa on racial discrimination?
						</Typography>
					</Paper>
				</div>
				<Typography variant="body1">Try one now. The button opens Chat with the question typed in.</Typography>
				<TryQuestion question="What did CERD recommend to South Africa on racial discrimination?" />
			</div>
		)
	},
	{
		id: 'types',
		title: 'Know the three question types',
		summary: 'Research, compare and advisory questions take different routes.',
		content: (
			<div className="flex flex-col gap-4">
				<Typography variant="body1">
					HRAS sorts every question into one of three types before it answers. You do not choose the type. The
					way you word the question does.
				</Typography>
				{QUESTION_TYPES.map((type) => (
					<div
						key={type.id}
						className="flex flex-col gap-2"
					>
						<div className="flex items-center gap-2">
							<FuseSvgIcon
								size={20}
								className="text-[#0072BC]"
							>
								{type.icon}
							</FuseSvgIcon>
							<Typography
								variant="subtitle1"
								className="font-semibold"
							>
								{type.title}
							</Typography>
						</div>
						<Typography variant="body2">{type.description}</Typography>
						<TryQuestion question={type.example} />
					</div>
				))}
			</div>
		)
	},
	{
		id: 'pipeline',
		title: 'See how an answer is built',
		summary: 'Follow a question through the agents, stage by stage.',
		content: (
			<div className="flex flex-col gap-4">
				<Typography variant="body1">
					Behind the chat box, a small team of AI agents passes your question along. A supervisor decides the
					route, a specialist gathers evidence and an advisor writes the reply. Explore it below.
				</Typography>
				<AnswerPipeline />
				<Typography variant="body1">The full picture, from your browser to the language model:</Typography>
				<Paper
					variant="outlined"
					className="overflow-x-auto p-2"
				>
					<img
						src="/docs/diagrams/01-system-architecture.svg"
						alt="HRAS system architecture: the browser sends questions to the API on Cloudflare, which runs the LangGraph agents. The agents search the vector store of UHRI records and call the chat language model."
						className="h-auto w-full min-w-[640px]"
					/>
				</Paper>
			</div>
		)
	},
	{
		id: 'sources',
		title: 'Read and check the sources',
		summary: 'Every research answer shows the records it used.',
		content: (
			<div className="flex flex-col gap-4">
				<Typography variant="body1">
					Under each answer you will see a link such as <strong>10 sources</strong>. Click it to open the UHRI
					records HRAS used. Each card shows:
				</Typography>
				<TextList
					items={[
						<>
							<strong>Country · Mechanism · Year</strong>: who received the recommendation, from which
							body and when
						</>,
						<>
							<strong>Theme · Status</strong>: the human rights theme, and whether the State accepted or
							noted it
						</>,
						<>
							<strong>Snippet</strong>: the start of the recommendation text
						</>
					]}
				/>
				<Typography variant="body1">Before you rely on an answer:</Typography>
				<TextList
					ordered
					items={[
						'Check that each claim in the answer matches a source card.',
						<>
							Look up the full recommendation on the{' '}
							<Link
								href="https://uhri.ohchr.org"
								target="_blank"
								rel="noopener noreferrer"
							>
								UHRI website
							</Link>{' '}
							before you quote it.
						</>,
						'Treat a claim with no matching source as the model talking, not the record.'
					]}
				/>
			</div>
		)
	},
	{
		id: 'tips',
		title: 'Tips and troubleshooting',
		summary: 'Follow-up questions, empty answers and errors.',
		content: (
			<div className="flex flex-col gap-4">
				<Typography
					variant="subtitle1"
					className="font-semibold"
				>
					Follow-up questions
				</Typography>
				<Typography variant="body1">
					Each question is answered on its own. HRAS does not read your earlier messages when it answers, so
					repeat the country and theme in a follow-up. Reloading the page starts a fresh conversation.
				</Typography>
				<Typography
					variant="subtitle1"
					className="font-semibold"
				>
					Common messages
				</Typography>
				<div className="flex flex-col gap-3">
					<Alert
						severity="warning"
						icon={<FuseSvgIcon>heroicons-outline:exclamation-triangle</FuseSvgIcon>}
					>
						<strong>The human rights database has not been initialized yet.</strong> The server has just
						started and is still loading records. Wait a moment and ask again. If the message stays, ask an
						administrator to run ingestion.
					</Alert>
					<Alert
						severity="warning"
						icon={<FuseSvgIcon>heroicons-outline:exclamation-triangle</FuseSvgIcon>}
					>
						<strong>Unable to connect to the API.</strong> The server may be waking up after a quiet spell.
						Wait a few seconds and send the question again.
					</Alert>
					<Alert
						severity="info"
						icon={<FuseSvgIcon>heroicons-outline:light-bulb</FuseSvgIcon>}
					>
						<strong>The answer has no sources.</strong> The question was probably treated as advisory. Ask
						it again as a research question: name a country, mechanism or theme.
					</Alert>
				</div>
				<Typography variant="body1">
					You are ready. Ask HRAS something you actually need for your work this week.
				</Typography>
			</div>
		)
	}
];
