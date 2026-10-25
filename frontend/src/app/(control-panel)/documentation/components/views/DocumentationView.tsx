'use client';

import { useState } from 'react';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import LinearProgress from '@mui/material/LinearProgress';
import Paper from '@mui/material/Paper';
import Step from '@mui/material/Step';
import StepButton from '@mui/material/StepButton';
import StepContent from '@mui/material/StepContent';
import Stepper from '@mui/material/Stepper';
import Typography from '@mui/material/Typography';
import FusePageSimple from '@fuse/core/FusePageSimple';
import FuseSvgIcon from '@fuse/core/FuseSvgIcon';
import { styled } from '@mui/material/styles';
import Link from 'next/link';
import { TUTORIAL_STEPS } from '../tutorialSteps';

const Root = styled(FusePageSimple)(({ theme }) => ({
	'& .FusePageSimple-header': {
		backgroundColor: theme.vars.palette.background.paper,
		borderBottomWidth: 1,
		borderStyle: 'solid',
		borderColor: theme.vars.palette.divider
	}
}));

function DocumentationView() {
	const [activeStep, setActiveStep] = useState(0);
	const [completed, setCompleted] = useState<Set<number>>(new Set());

	const step = TUTORIAL_STEPS[activeStep];
	const isLast = activeStep === TUTORIAL_STEPS.length - 1;

	const goTo = (index: number) => {
		setActiveStep(index);
		window.scrollTo({ top: 0, behavior: 'smooth' });
	};

	const handleNext = () => {
		setCompleted((prev) => new Set(prev).add(activeStep));

		if (!isLast) {
			goTo(activeStep + 1);
		}
	};

	return (
		<Root
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
							heroicons-outline:book-open
						</FuseSvgIcon>
					</Box>
					<div>
						<Typography
							variant="h6"
							className="font-semibold"
						>
							Documentation
						</Typography>
						<Typography
							variant="body2"
							color="text.secondary"
						>
							A six-step tour of HRAS. Takes about ten minutes.
						</Typography>
					</div>
				</div>
			}
			content={
				<div className="mx-auto flex w-full max-w-6xl flex-col gap-6 p-4 sm:p-6 md:flex-row">
					<nav
						aria-label="Tutorial steps"
						className="hidden shrink-0 md:block md:w-64"
					>
						<Stepper
							nonLinear
							activeStep={activeStep}
							orientation="vertical"
						>
							{TUTORIAL_STEPS.map((item, index) => (
								<Step
									key={item.id}
									completed={completed.has(index)}
								>
									<StepButton onClick={() => goTo(index)}>{item.title}</StepButton>
									<StepContent>
										<Typography
											variant="caption"
											color="text.secondary"
										>
											{item.summary}
										</Typography>
									</StepContent>
								</Step>
							))}
						</Stepper>
					</nav>

					<div className="flex min-w-0 flex-1 flex-col gap-4">
						<div className="md:hidden">
							<Typography
								variant="caption"
								color="text.secondary"
							>
								Step {activeStep + 1} of {TUTORIAL_STEPS.length}
							</Typography>
							<LinearProgress
								variant="determinate"
								value={((activeStep + 1) / TUTORIAL_STEPS.length) * 100}
								className="mt-1 rounded"
							/>
						</div>

						<Paper
							variant="outlined"
							className="flex flex-col gap-4 p-4 sm:p-6"
						>
							<div>
								<Typography
									variant="overline"
									color="text.secondary"
								>
									Step {activeStep + 1}
								</Typography>
								<Typography
									variant="h5"
									component="h2"
									className="font-semibold"
								>
									{step.title}
								</Typography>
							</div>
							{step.content}
						</Paper>

						<div className="flex items-center justify-between gap-2">
							<Button
								disabled={activeStep === 0}
								onClick={() => goTo(activeStep - 1)}
								startIcon={<FuseSvgIcon size={16}>heroicons-outline:arrow-left</FuseSvgIcon>}
							>
								Back
							</Button>
							{isLast ? (
								<Button
									component={Link}
									href="/chat"
									variant="contained"
									onClick={handleNext}
									endIcon={<FuseSvgIcon size={16}>heroicons-outline:arrow-right</FuseSvgIcon>}
								>
									Start chatting
								</Button>
							) : (
								<Button
									variant="contained"
									onClick={handleNext}
									endIcon={<FuseSvgIcon size={16}>heroicons-outline:arrow-right</FuseSvgIcon>}
								>
									Next: {TUTORIAL_STEPS[activeStep + 1].title}
								</Button>
							)}
						</div>
					</div>
				</div>
			}
		/>
	);
}

export default DocumentationView;
