'use client';

import { useState } from 'react';
import IconButton from '@mui/material/IconButton';
import Paper from '@mui/material/Paper';
import TextField from '@mui/material/TextField';
import FuseSvgIcon from '@fuse/core/FuseSvgIcon';
import { useTranslation } from 'react-i18next';

interface ChatInputProps {
	onSend: (message: string) => void;
	disabled?: boolean;
}

function ChatInput({ onSend, disabled = false }: ChatInputProps) {
	const { t } = useTranslation('chatPage');
	const [message, setMessage] = useState('');

	const handleSubmit = (e: React.FormEvent) => {
		e.preventDefault();

		if (message.trim() && !disabled) {
			onSend(message.trim());
			setMessage('');
		}
	};

	const handleKeyDown = (e: React.KeyboardEvent) => {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			handleSubmit(e);
		}
	};

	return (
		<Paper
			className="border-t border-gray-200 p-3"
			elevation={0}
		>
			<form
				onSubmit={handleSubmit}
				className="flex items-end gap-2"
			>
				<TextField
					value={message}
					onChange={(e) => setMessage(e.target.value)}
					onKeyDown={handleKeyDown}
					placeholder={t('INPUT_PLACEHOLDER')}
					multiline
					maxRows={4}
					fullWidth
					disabled={disabled}
					variant="outlined"
					size="small"
					sx={{
						'& .MuiOutlinedInput-root': {
							borderRadius: '12px'
						}
					}}
				/>
				<IconButton
					type="submit"
					disabled={!message.trim() || disabled}
					className="bg-[#0072BC] text-white hover:bg-[#005a94] disabled:bg-gray-300"
					size="medium"
				>
					<FuseSvgIcon size={20}>heroicons-outline:paper-airplane</FuseSvgIcon>
				</IconButton>
			</form>
		</Paper>
	);
}

export default ChatInput;
