import type { Metadata } from 'next';

async function generateMetadata(meta: {
	title: string;
	description: string;
	cardImage: string;
	robots: string;
	favicon: string;
	url: string;
}): Promise<Metadata> {
	return {
		title: meta.title,
		description: meta.description,
		referrer: 'origin-when-cross-origin',
		keywords: ['HRAS', 'Human Rights', 'UN', 'Advisory System', 'UHRI', 'AI', 'RAG'],
		authors: [{ name: 'HRAS Development Team' }],
		creator: 'HRAS',
		publisher: 'United Nations Human Rights',
		robots: meta.robots,
		icons: { icon: meta.favicon },
		metadataBase: new URL(meta.url),
		openGraph: {
			url: meta.url,
			title: meta.title,
			description: meta.description,
			images: [meta.cardImage],
			type: 'website',
			siteName: 'HRAS - Human Rights Advisory System'
		},
		twitter: {
			card: 'summary_large_image',
			site: '@UNHumanRights',
			creator: '@UNHumanRights',
			title: meta.title,
			description: meta.description,
			images: [meta.cardImage]
		}
	};
}

export default generateMetadata;
