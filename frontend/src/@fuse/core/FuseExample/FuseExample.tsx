import FuseHighlight from '@fuse/core/FuseHighlight';
import Card from '@mui/material/Card';
import clsx from 'clsx';
import { ElementType, ReactNode, useState } from 'react';
import DemoFrame from './DemoFrame';
import FuseSvgIcon from '../FuseSvgIcon';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import { darken } from '@mui/material/styles';
import Tooltip from '@mui/material/Tooltip';
import Alert from '@mui/material/Alert';

type FuseExampleProps = {
	name?: string;
	raw?: unknown;
	showCode?: boolean;
	component: ElementType;
	iframe?: ReactNode;
	className: string;
};

/**
 * FuseExample component gives a visual display as well as code for a component example.
 * It consists of two tabs, a visual tab and code tab.
 */
function FuseExample(props: FuseExampleProps) {
	const { component: Component, raw, iframe, className, name = '', showCode: defaultShowCode = false } = props;
	const [open, setOpen] = useState(false);
	const [showCode, setShowCode] = useState(defaultShowCode);

	// Detect if we're running in Turbopack environment
	const isTurbopackEnvironment = process.env.TURBOPACK === '1' || process.env.NODE_ENV === 'development';

	// Detect if raw-loader is working properly
	const isRawString = typeof raw === 'string';
	const hasValidRaw = isRawString && raw.trim().length > 0;

	// Show warning when Turbopack is running AND raw-loader failed
	const showTurbopackWarning = isTurbopackEnvironment && !hasValidRaw && raw !== undefined;

	function toggleShowCode() {
		setShowCode(!showCode);
	}

	function handleCopy() {
		if (!hasValidRaw) {
			return;
		}

		navigator.clipboard.writeText(raw as string);
		setOpen(true);
		setTimeout(() => {
			setOpen(false);
		}, 800);
	}

	return (
		<Card className={clsx(className, 'not-prose border-divider rounded-md border shadow-xs')}>
			{Component && (
				<Box className="relative flex max-w-full justify-center p-4">
					{iframe ? (
						<DemoFrame name={name}>
							<Component />
						</DemoFrame>
					) : (
						<Component />
					)}
				</Box>
			)}
			<Box
				className="flex items-center justify-end gap-3 border-t p-2"
				sx={{
					backgroundColor: (theme) =>
						darken(theme.palette.background.paper, theme.palette.mode === 'light' ? 0.02 : 0.2)
				}}
			>
				<Tooltip
					title="Copied!"
					open={open}
					slotProps={{ popper: { placement: 'top' } }}
					arrow
				>
					<Button
						variant="text"
						onClick={handleCopy}
						size="small"
						className=""
						disabled={!hasValidRaw}
						startIcon={<FuseSvgIcon>lucide:copy</FuseSvgIcon>}
					>
						Copy
					</Button>
				</Tooltip>
				<Button
					className="min-w-30"
					onClick={toggleShowCode}
					variant="outlined"
					size="small"
					disabled={!hasValidRaw && !showTurbopackWarning}
					startIcon={<FuseSvgIcon>lucide:code-xml</FuseSvgIcon>}
				>
					{showCode ? 'Hide Code' : 'Show Code'}
				</Button>
			</Box>
			{showCode && (
				<div className="flex flex-1 flex-col">
					{showTurbopackWarning && (
						<Alert
							severity="warning"
							className="m-4"
							variant="outlined"
						>
							<div>
								<strong>Development Mode Limitation:</strong> Source code cannot be displayed because
								raw-loader doesn't work with Turbopack in development mode.
							</div>
							<div className="mt-1 text-sm">
								• This only affects development mode when using <code>npm run dev</code>
								<br />• Production builds (<code>npm run build</code>) work normally
								<br />• Alternative: Run dev without Turbopack using{' '}
								<code>npm run dev -- --turbo=false</code>
							</div>
						</Alert>
					)}
					{hasValidRaw && (
						<FuseHighlight
							component="pre"
							className="language-javascript w-full"
							copy={false}
						>
							{raw}
						</FuseHighlight>
					)}
				</div>
			)}
		</Card>
	);
}

export default FuseExample;
