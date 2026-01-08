'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import Box from '@mui/material/Box';
import CircularProgress from '@mui/material/CircularProgress';
import Paper from '@mui/material/Paper';
import Typography from '@mui/material/Typography';
import FusePageSimple from '@fuse/core/FusePageSimple';
import FuseSvgIcon from '@fuse/core/FuseSvgIcon';
import { styled } from '@mui/material/styles';
import { useTranslation } from 'react-i18next';
import '../../i18n';
import ChatInput from '../ChatInput';
import ChatMessage from '../ChatMessage';
import { useChatMutation } from '../../hooks/useChatMutation';
import type { MessageWithSources } from '../../types';

const Root = styled(FusePageSimple)(({ theme }) => ({
	'& .FusePageSimple-header': {
		backgroundColor: theme.vars.palette.background.paper,
		borderBottomWidth: 1,
		borderStyle: 'solid',
		borderColor: theme.vars.palette.divider
	},
	'& .FusePageSimple-content': {
		display: 'flex',
		flexDirection: 'column',
		height: '100%'
	}
}));

function ChatView() {
	const { t } = useTranslation('chatPage');
	const [messages, setMessages] = useState<MessageWithSources[]>([]);
	const [conversationId, setConversationId] = useState<string | undefined>();
	const messagesEndRef = useRef<HTMLDivElement>(null);
	const chatMutation = useChatMutation();

	const scrollToBottom = useCallback(() => {
		messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
	}, []);

	useEffect(() => {
		scrollToBottom();
	}, [messages, scrollToBottom]);

	const handleSend = useCallback(
		(content: string) => {
			const userMessage: MessageWithSources = {
				message: {
					id: `user-${Date.now()}`,
					role: 'user',
					content,
					created_at: new Date().toISOString()
				}
			};

			setMessages((prev) => [...prev, userMessage]);

			chatMutation.mutate(
				{
					message: content,
					conversation_id: conversationId
				},
				{
					onSuccess: (response) => {
						setConversationId(response.conversation_id);
						setMessages((prev) => [
							...prev,
							{
								message: response.message,
								sources: response.sources
							}
						]);
					},
					onError: (error: Error) => {
						const errorMessage = error.message || t('ERROR_MESSAGE');
						setMessages((prev) => [
							...prev,
							{
								message: {
									id: `error-${Date.now()}`,
									role: 'assistant',
									content: `⚠️ ${errorMessage}`,
									created_at: new Date().toISOString()
								}
							}
						]);
					}
				}
			);
		},
		[conversationId, chatMutation, t]
	);

	const handleExampleClick = useCallback(
		(question: string) => {
			handleSend(question);
		},
		[handleSend]
	);

	const exampleQuestions = [t('EXAMPLE_1'), t('EXAMPLE_2'), t('EXAMPLE_3')];

	return (
		<Root
			header={
				<div className="flex items-center gap-3 p-6">
					<Box
						className="flex h-10 w-10 items-center justify-center rounded-lg"
						sx={{ backgroundColor: '#0072BC' }}
					>
						<FuseSvgIcon
							className="text-white"
							size={24}
						>
							heroicons-outline:chat-bubble-left-right
						</FuseSvgIcon>
					</Box>
					<div>
						<Typography
							variant="h6"
							className="font-semibold"
						>
							{t('TITLE')}
						</Typography>
						<Typography
							variant="body2"
							color="text.secondary"
						>
							{t('SUBTITLE')}
						</Typography>
					</div>
				</div>
			}
			content={
				<div className="flex h-full flex-col">
					<div className="flex-1 overflow-y-auto p-6">
						{messages.length === 0 ? (
							<div className="flex h-full flex-col items-center justify-center text-center">
								<Box
									className="mb-4 flex h-16 w-16 items-center justify-center rounded-full"
									sx={{ backgroundColor: 'rgba(0, 114, 188, 0.1)' }}
								>
									<FuseSvgIcon
										className="text-[#0072BC]"
										size={32}
									>
										heroicons-outline:chat-bubble-left-right
									</FuseSvgIcon>
								</Box>
								<Typography
									variant="h5"
									className="mb-2 font-semibold"
								>
									{t('WELCOME_MESSAGE')}
								</Typography>
								<Typography
									variant="body1"
									color="text.secondary"
									className="mb-6 max-w-md"
								>
									{t('WELCOME_DESCRIPTION')}
								</Typography>
								<div className="w-full max-w-lg">
									<Typography
										variant="subtitle2"
										color="text.secondary"
										className="mb-3"
									>
										{t('EXAMPLE_QUESTIONS')}
									</Typography>
									<div className="flex flex-col gap-2">
										{exampleQuestions.map((question, index) => (
											<Paper
												key={`example-${index}`}
												className="cursor-pointer border border-gray-200 p-3 text-left transition-colors hover:bg-gray-50"
												elevation={0}
												onClick={() => handleExampleClick(question)}
											>
												<div className="flex items-center gap-2">
													<FuseSvgIcon
														size={16}
														className="text-[#0072BC]"
													>
														heroicons-outline:chat-bubble-left
													</FuseSvgIcon>
													<Typography variant="body2">{question}</Typography>
												</div>
											</Paper>
										))}
									</div>
								</div>
							</div>
						) : (
							<div className="flex flex-col gap-4">
								{messages.map((item) => (
									<ChatMessage
										key={item.message.id}
										message={item.message}
										sources={item.sources}
									/>
								))}
								{chatMutation.isPending && (
									<div className="flex items-center gap-2 text-gray-500">
										<CircularProgress
											size={16}
											color="inherit"
										/>
										<Typography variant="body2">{t('LOADING')}</Typography>
									</div>
								)}
								<div ref={messagesEndRef} />
							</div>
						)}
					</div>
					<ChatInput
						onSend={handleSend}
						disabled={chatMutation.isPending}
					/>
				</div>
			}
		/>
	);
}

export default ChatView;
