'use client';

import React from 'react';

type AuthGuardProps = {
	auth: unknown;
	children: React.ReactNode;
	loginRedirectUrl?: string;
};

function AuthGuardRedirect({ children }: AuthGuardProps) {
	return children;
}

export default AuthGuardRedirect;
