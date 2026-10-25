import { ReactNode } from 'react';
import Typography from '@mui/material/Typography';
import clsx from 'clsx';

export function TextList({ items, ordered = false }: { items: ReactNode[]; ordered?: boolean }) {
	const List = ordered ? 'ol' : 'ul';

	return (
		<List className={clsx('flex flex-col gap-1 ps-5', ordered ? 'list-decimal' : 'list-disc')}>
			{items.map((item, index) => (
				<li key={index}>
					<Typography variant="body1">{item}</Typography>
				</li>
			))}
		</List>
	);
}

export function Kbd({ children }: { children: ReactNode }) {
	return <kbd className="rounded border border-current/30 px-1.5 py-0.5 font-mono text-sm">{children}</kbd>;
}
