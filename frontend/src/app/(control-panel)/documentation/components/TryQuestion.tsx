import Button from '@mui/material/Button';
import Paper from '@mui/material/Paper';
import Typography from '@mui/material/Typography';
import FuseSvgIcon from '@fuse/core/FuseSvgIcon';
import Link from 'next/link';

interface TryQuestionProps {
	question: string;
	note?: string;
}

/**
 * An example question with a button that opens Chat with the question already typed in.
 */
function TryQuestion({ question, note }: TryQuestionProps) {
	return (
		<Paper
			variant="outlined"
			className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between"
		>
			<div className="flex items-start gap-2">
				<FuseSvgIcon
					size={18}
					className="mt-0.5 shrink-0 text-[#0072BC]"
				>
					heroicons-outline:chat-bubble-left
				</FuseSvgIcon>
				<div>
					<Typography variant="body2">{question}</Typography>
					{note && (
						<Typography
							variant="caption"
							color="text.secondary"
						>
							{note}
						</Typography>
					)}
				</div>
			</div>
			<Button
				component={Link}
				href={`/chat?q=${encodeURIComponent(question)}`}
				size="small"
				variant="outlined"
				className="shrink-0"
				endIcon={<FuseSvgIcon size={16}>heroicons-outline:arrow-right</FuseSvgIcon>}
			>
				Try in chat
			</Button>
		</Paper>
	);
}

export default TryQuestion;
