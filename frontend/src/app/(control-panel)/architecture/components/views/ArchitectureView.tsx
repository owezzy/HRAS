'use client';

import { useState } from 'react';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Tab from '@mui/material/Tab';
import Tabs from '@mui/material/Tabs';
import FuseSvgIcon from '@fuse/core/FuseSvgIcon';
import ControlPanelPage from '@/components/ControlPanelPage';

/** Interactive Archify diagrams in public/docs/diagrams (see docs/architecture/DIAGRAMS.md). */
const DIAGRAMS = [
	{ file: '01-system-architecture.html', label: 'System architecture' },
	{ file: '02-chat-request-sequence.html', label: 'Chat request' },
	{ file: '03-conversation-erd.html', label: 'Conversation storage' },
	{ file: '04-multi-agent-workflow.html', label: 'Multi-agent workflow' },
	{ file: '05-data-ingestion-pipeline.html', label: 'Data ingestion' },
	{ file: '06-api-architecture.html', label: 'API layer' }
];

function ArchitectureView() {
	const [active, setActive] = useState(0);
	const diagram = DIAGRAMS[active];
	const src = `/docs/diagrams/${diagram.file}`;

	return (
		<ControlPanelPage
			icon="lucide:network"
			title="Architecture"
			subtitle="Interactive diagrams of how HRAS is built. Hover or click parts to explore them."
			content={
				<div className="mx-auto flex w-full max-w-7xl flex-1 flex-col gap-4 p-4 sm:p-6">
					<div className="flex flex-wrap items-center justify-between gap-2">
						<Tabs
							value={active}
							onChange={(_event, value: number) => setActive(value)}
							variant="scrollable"
							scrollButtons="auto"
							aria-label="Architecture diagrams"
							className="min-w-0 flex-1"
						>
							{DIAGRAMS.map((item) => (
								<Tab
									key={item.file}
									label={item.label}
								/>
							))}
						</Tabs>
						<Button
							href={src}
							target="_blank"
							rel="noopener"
							size="small"
							endIcon={<FuseSvgIcon size={16}>lucide:external-link</FuseSvgIcon>}
						>
							Open full screen
						</Button>
					</div>
					<Box
						component="iframe"
						src={src}
						title={diagram.label}
						className="min-h-[480px] w-full flex-1 rounded-lg border-0"
						sx={{ backgroundColor: 'background.paper' }}
					/>
				</div>
			}
		/>
	);
}

export default ArchitectureView;
