import { redirect } from 'next/navigation';

function MainPage() {
	redirect(`/chat`);
	return null;
}

export default MainPage;
