import { redirect } from 'next/navigation';

function MainPage() {
	redirect(`/example`);
	return null;
}

export default MainPage;
