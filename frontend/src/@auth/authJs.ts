import NextAuth from 'next-auth';
import type { NextAuthConfig } from 'next-auth';
import type { Provider } from 'next-auth/providers';
import Credentials from 'next-auth/providers/credentials';

const demoUser = {
	id: '0',
	email: 'demo@hras.org',
	name: 'Demo User',
	image: '/assets/images/avatars/brian-hughes.jpg',
	role: ['admin'],
	displayName: 'Demo User',
	photoURL: '/assets/images/avatars/brian-hughes.jpg',
	settings: { layout: {}, theme: {} },
	shortcuts: ['apps.calendar', 'apps.mailbox', 'apps.contacts']
};

export const providers: Provider[] = [
	Credentials({
		credentials: {
			email: { label: 'Email', type: 'email' },
			password: { label: 'Password', type: 'password' }
		},
		authorize() {
			return { id: demoUser.id, email: demoUser.email, name: demoUser.name, image: demoUser.image };
		}
	})
];

const config = {
	theme: { logo: '/assets/images/logo/logo.svg' },
	pages: {
		signIn: '/sign-in'
	},
	providers,
	basePath: '/auth',
	trustHost: true,
	callbacks: {
		authorized() {
			return true;
		},
		jwt({ token }) {
			return token;
		},
		async session({ session }) {
			if (session) {
				session.db = demoUser;
				return session;
			}
			return null;
		}
	},
	session: {
		strategy: 'jwt',
		maxAge: 30 * 24 * 60 * 60
	},
	debug: process.env.NODE_ENV !== 'production'
} satisfies NextAuthConfig;

export type AuthJsProvider = {
	id: string;
	name: string;
	style?: {
		text?: string;
		bg?: string;
	};
};

export const authJsProviderMap: AuthJsProvider[] = [];

export const { handlers, auth, signIn, signOut } = NextAuth(config);
