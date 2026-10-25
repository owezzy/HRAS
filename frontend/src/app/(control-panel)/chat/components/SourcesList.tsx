'use client';

import { useState } from 'react';
import Collapse from '@mui/material/Collapse';
import Paper from '@mui/material/Paper';
import Typography from '@mui/material/Typography';
import FuseSvgIcon from '@fuse/core/FuseSvgIcon';
import type { ChatSource } from '../types';

interface SourcesListProps {
	sources: ChatSource[];
}

function SourcesList({ sources }: SourcesListProps) {
	const [expanded, setExpanded] = useState(false);

	if (!sources || sources.length === 0) {
		return null;
	}

	return (
		<div className="mt-2">
			<button
				type="button"
				onClick={() => setExpanded(!expanded)}
				className="flex items-center gap-1 text-sm text-gray-600 transition-colors hover:text-gray-800"
			>
				<FuseSvgIcon
					size={16}
					className={`transition-transform ${expanded ? 'rotate-90' : ''}`}
				>
					heroicons-outline:chevron-right
				</FuseSvgIcon>
				<span>
					{sources.length} source{sources.length > 1 ? 's' : ''}
				</span>
			</button>
			<Collapse in={expanded}>
				<div className="mt-2 flex flex-col gap-2">
					{sources.map((source, index) => (
						<Paper
							key={`source-${index}`}
							className="border border-gray-200 p-3"
							elevation={0}
						>
							<Typography
								variant="subtitle2"
								className="font-semibold text-[#0072BC]"
							>
								{[source.country, source.mechanism, source.year].filter(Boolean).join(' · ')}
							</Typography>
							{(source.theme || source.status) && (
								<Typography
									variant="caption"
									color="text.secondary"
								>
									{[source.theme, source.status].filter(Boolean).join(' · ')}
								</Typography>
							)}
							<Typography
								variant="body2"
								className="mt-1 line-clamp-3 text-gray-600"
							>
								{source.snippet}
							</Typography>
						</Paper>
					))}
				</div>
			</Collapse>
		</div>
	);
}

export default SourcesList;
