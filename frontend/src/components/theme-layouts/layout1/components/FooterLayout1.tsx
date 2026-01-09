import AppBar from '@mui/material/AppBar';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import Link from '@mui/material/Link';
import Box from '@mui/material/Box';
import Stack from '@mui/material/Stack';
import { memo } from 'react';
import clsx from 'clsx';
import FooterTheme from '@/contexts/FooterTheme';

type FooterLayout1Props = { className?: string };

/**
 * The footer layout 1.
 */
function FooterLayout1(props: FooterLayout1Props) {
	const { className } = props;

	return (
		<FooterTheme>
			<AppBar
				id="fuse-footer"
				className={clsx('relative z-20 border-t', className)}
				color="default"
				sx={(theme) => ({
					backgroundColor: theme.vars.palette.background.default,
					color: theme.vars.palette.text.primary
				})}
				elevation={0}
			>
				<Toolbar className="flex min-h-12 items-center overflow-x-auto px-2 py-0 sm:px-3 md:min-h-16">
					<Box className="flex w-full flex-col items-center justify-between gap-3 sm:flex-row sm:gap-6">
						<Typography
							variant="body2"
							className="text-center text-sm text-gray-600 sm:text-left"
						>
							© 2026 HRAS - Human Rights Advisory System. All rights reserved.
						</Typography>
						<Stack
							direction="row"
							spacing={3}
							className="flex-shrink-0"
						>
							<Link
								href="#"
								className="text-sm text-gray-600 transition-colors hover:text-[#009EDB]"
								underline="none"
							>
								Privacy Policy
							</Link>
							<Link
								href="#"
								className="text-sm text-gray-600 transition-colors hover:text-[#009EDB]"
								underline="none"
							>
								Terms of Use
							</Link>
							<Link
								href="#"
								className="text-sm text-gray-600 transition-colors hover:text-[#009EDB]"
								underline="none"
							>
								Contact
							</Link>
						</Stack>
					</Box>
				</Toolbar>
			</AppBar>
		</FooterTheme>
	);
}

export default memo(FooterLayout1);
