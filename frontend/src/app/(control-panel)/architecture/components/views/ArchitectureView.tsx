'use client';

import { useState } from 'react';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Tab from '@mui/material/Tab';
import Tabs from '@mui/material/Tabs';
import Typography from '@mui/material/Typography';
import FusePageSimple from '@fuse/core/FusePageSimple';
import FuseSvgIcon from '@fuse/core/FuseSvgIcon';
import { styled } from '@mui/material/styles';

const Root = styled(FusePageSimple)(({ theme }) => ({
	'& .FusePageSimple-header': {
		backgroundColor: theme.vars.palette.background.paper,
		borderBottomWidth: 1,
		borderStyle: 'solid',
		borderColor: theme.vars.palette.divider
	}
}));

/** Interactive Archify diagrams, served from public/docs/diagrams (copies of docs/architecture/diagrams). */
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
		<Root
			scroll="content"
			header={
				<div className="flex items-center gap-3 p-6">
					<Box
						className="flex h-10 w-10 items-center justify-center rounded-lg"
						sx={{ backgroundColor: '#0072BC' }}
					>
						<FuseSvgIcon
							className="text-white"
							size={24}
						>
							lucide:network
						</FuseSvgIcon>
					</Box>
					<div>
						<Typography
							variant="h6"
							className="font-semibold"
						>
							Architecture
						</Typography>
						<Typography
							variant="body2"
							color="text.secondary"
						>
							Interactive diagrams of how HRAS is built. Hover or click parts to explore them.
						</Typography>
					</div>
				</div>
			}
			content={
				<div className="mx-auto flex w-full max-w-7xl flex-col gap-4 p-4 sm:p-6">
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
						key={diagram.file}
						src={src}
						title={diagram.label}
						className="w-full rounded-lg border-0"
						sx={{ height: 'calc(100vh - 280px)', minHeight: 480, backgroundColor: 'background.paper' }}
					/>
				</div>
			}
		/>
	);
}

export default ArchitectureView;
