import { ReactNode } from 'react';
import Typography from '@mui/material/Typography';

export function Bullets({ items }: { items: ReactNode[] }) {
	return (
		<ul className="flex list-disc flex-col gap-1 ps-5">
			{items.map((item, index) => (
				<li key={index}>
					<Typography variant="body1">{item}</Typography>
				</li>
			))}
		</ul>
	);
}

export function Numbered({ items }: { items: ReactNode[] }) {
	return (
		<ol className="flex list-decimal flex-col gap-1 ps-5">
			{items.map((item, index) => (
				<li key={index}>
					<Typography variant="body1">{item}</Typography>
				</li>
			))}
		</ol>
	);
}

export function Kbd({ children }: { children: ReactNode }) {
	return <kbd className="rounded border border-current/30 px-1.5 py-0.5 font-mono text-sm">{children}</kbd>;
}
