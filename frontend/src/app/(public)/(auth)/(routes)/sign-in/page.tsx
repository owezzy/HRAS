'use client';

import authRoles from '@auth/authRoles';
import AuthGuardRedirect from '@auth/AuthGuardRedirect';
import SignInPageView from '../../components/views/SignInPageView';

function Page() {
	return (
		<AuthGuardRedirect auth={authRoles.onlyGuest}>
			<SignInPageView />
		</AuthGuardRedirect>
	);
}

export default Page;
