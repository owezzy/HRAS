import clsx from 'clsx';
import 'src/styles/splash-screen.css';
import 'src/styles/index.css';
import '../../public/assets/fonts/material-design-icons/MaterialIconsOutlined.css';
import '../../public/assets/fonts/Geist/geist.css';
import '../../public/assets/fonts/meteocons/style.css';
import '../../public/assets/styles/prism.css';
import { SessionProvider } from 'next-auth/react';
import { demoSession } from '@auth/authJs';
import generateMetadata from '../utils/generateMetadata';
import App from './App';

// eslint-disable-next-line react-refresh/only-export-components
export const metadata = await generateMetadata({
	title: 'HRAS - Human Rights Advisory System',
	description:
		'AI-powered advisory system for UN human rights officers. RAG pipeline over UHRI documents with intelligent multi-agent orchestration.',
	cardImage: '/assets/icons/512x512.png',
	robots: 'follow, index',
	favicon: '/favicon.ico',
	url: 'https://hras.un.org'
});

export default async function RootLayout({
	children
}: Readonly<{
	children: React.ReactNode;
}>) {
	return (
		<html lang="en">
			<head>
				<meta charSet="utf-8" />
				<meta
					name="viewport"
					content="width=device-width, initial-scale=1, shrink-to-fit=no"
				/>
				<meta
					name="theme-color"
					content="#009EDB"
				/>
				<base href="/" />
				{/*
					manifest.json provides metadata used when your web app is added to the
					homescreen on Android. See https://developers.google.com/web/fundamentals/engage-and-retain/web-app-manifest/
				*/}
				<link
					rel="manifest"
					href="/manifest.json"
				/>
				<link
					rel="shortcut icon"
					href="/favicon.ico"
				/>
				<noscript id="emotion-insertion-point" />
			</head>
			<body
				id="root"
				className={clsx('loading')}
			>
				<SessionProvider
					basePath="/auth"
					session={demoSession}
				>
					<App>{children}</App>
				</SessionProvider>
			</body>
		</html>
	);
}
