import { Suspense } from 'react';
import ChatView from '../components/views/ChatView';

function ChatPage() {
	return (
		<Suspense>
			<ChatView />
		</Suspense>
	);
}

export default ChatPage;
