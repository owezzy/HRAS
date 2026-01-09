'use client';

import Avatar from '@mui/material/Avatar';
import Paper from '@mui/material/Paper';
import Typography from '@mui/material/Typography';
import FuseSvgIcon from '@fuse/core/FuseSvgIcon';
import ReactMarkdown from 'react-markdown';
import type { ChatSource, ChatMessage as ChatMessageType } from '../types';
import SourcesList from './SourcesList';

interface ChatMessageProps {
	message: ChatMessageType;
	sources?: ChatSource[];
}

function ChatMessage({ message, sources }: ChatMessageProps) {
	const isUser = message.role === 'user';

	return (
		<div className={`flex gap-3 ${isUser ? 'flex-row-reverse' : 'flex-row'}`}>
			<Avatar className={`h-8 w-8 ${isUser ? 'bg-[#0072BC]' : 'bg-gray-600'}`}>
				{isUser ? (
					<FuseSvgIcon
						size={18}
						className="text-white"
					>
						heroicons-outline:user
					</FuseSvgIcon>
				) : (
					<FuseSvgIcon
						size={18}
						className="text-white"
					>
						heroicons-outline:cpu-chip
					</FuseSvgIcon>
				)}
			</Avatar>
			<div className={`flex max-w-[75%] flex-col ${isUser ? 'items-end' : 'items-start'}`}>
				<Paper
					className={`rounded-lg p-3 ${
						isUser ? 'rounded-br-none bg-[#0072BC] text-white' : 'rounded-bl-none bg-gray-100 text-gray-900'
					}`}
					elevation={0}
				>
					{isUser ? (
						<Typography
							variant="body1"
							className="whitespace-pre-wrap"
						>
							{message.content}
						</Typography>
					) : (
						<div className="prose prose-sm prose-headings:mb-2 prose-headings:mt-3 prose-headings:font-semibold prose-p:my-1 prose-ul:my-1 prose-ol:my-1 prose-li:my-0 prose-pre:bg-gray-800 prose-pre:text-gray-100 prose-code:rounded prose-code:bg-gray-200 prose-code:px-1 prose-code:py-0.5 prose-code:text-gray-800 prose-code:before:content-none prose-code:after:content-none max-w-none">
							<ReactMarkdown>{message.content}</ReactMarkdown>
						</div>
					)}
				</Paper>
				{!isUser && sources && sources.length > 0 && <SourcesList sources={sources} />}
			</div>
		</div>
	);
}

export default ChatMessage;
