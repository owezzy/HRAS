'use client';

import { ReactNode } from 'react';
import Box from '@mui/material/Box';
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

type ControlPanelPageProps = {
	icon: string;
	title: ReactNode;
	subtitle: ReactNode;
	content: ReactNode;
	className?: string;
};

/**
 * Page shell for the control panel: an icon, title and subtitle header above content
 * that scrolls on its own, so the toolbar, header and footer stay in place.
 */
function ControlPanelPage({ icon, title, subtitle, content, className }: ControlPanelPageProps) {
	return (
		<Root
			className={className}
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
							{icon}
						</FuseSvgIcon>
					</Box>
					<div>
						<Typography
							variant="h6"
							className="font-semibold"
						>
							{title}
						</Typography>
						<Typography
							variant="body2"
							color="text.secondary"
						>
							{subtitle}
						</Typography>
					</div>
				</div>
			}
			content={content}
		/>
	);
}

export default ControlPanelPage;
