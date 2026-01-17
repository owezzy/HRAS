'use client';

import { useMemo } from 'react';
import { User } from '@auth/user';
import { demoUser } from './authJs';

type useUserReturn = {
	data: User | null;
	isGuest: boolean;
	updateUser: (updates: Partial<User>) => Promise<User | undefined>;
	updateUserSettings: (newSettings: User['settings']) => Promise<User['settings'] | undefined>;
	signOut: () => Promise<void>;
};

function useUser(): useUserReturn {
	const user = useMemo(() => demoUser as User, []);

	async function handleUpdateUser(_data: Partial<User>) {
		return { ...user, ..._data } as User;
	}

	async function handleUpdateUserSettings(newSettings: User['settings']) {
		return newSettings;
	}

	async function handleSignOut() {
		window.location.href = '/';
	}

	return {
		data: user,
		isGuest: false,
		signOut: handleSignOut,
		updateUser: handleUpdateUser,
		updateUserSettings: handleUpdateUserSettings
	};
}

export default useUser;
