/**
 * HRAS Icon Generator
 * Generates favicon and PWA icons from SVG source
 *
 * Usage: npx tsx scripts/generate-icons.ts
 */

// @ts-ignore
import sharp from 'sharp';
import { mkdir, writeFile } from 'fs/promises';
import { join } from 'path';

const ICON_SIZES = [16, 24, 32, 48, 64, 70, 96, 128, 150, 152, 192, 256, 310, 384, 512];
const OUTPUT_DIR = join(process.cwd(), 'frontend/public/assets/icons');
const PUBLIC_DIR = join(process.cwd(), 'frontend/public');

// HRAS Logo SVG - Shield with H
const HRAS_LOGO_SVG = `
<svg width="512" height="512" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <!-- Shield background -->
  <path d="M16 2L4 7V15C4 22.18 9.12 28.84 16 30C22.88 28.84 28 22.18 28 15V7L16 2Z" fill="#009EDB"/>

  <!-- Inner shield -->
  <path d="M16 4L6 8.5V15C6 21.08 10.44 26.72 16 27.92C21.56 26.72 26 21.08 26 15V8.5L16 4Z" fill="#0072BC"/>

  <!-- Stylized H -->
  <path d="M11 10V22M21 10V22M11 16H21" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
`;

async function generateIcons() {
	console.log('🎨 Generating HRAS icons...\n');

	// Ensure output directories exist
	await mkdir(OUTPUT_DIR, { recursive: true });

	// Generate PNG icons in all sizes
	for (const size of ICON_SIZES) {
		const outputPath = join(OUTPUT_DIR, `${size}x${size}.png`);

		await sharp(Buffer.from(HRAS_LOGO_SVG))
			.resize(size, size)
			.png()
			.toFile(outputPath);

		console.log(`  ✅ Generated ${size}x${size}.png`);
	}

	// Generate favicon.ico (multi-size ICO file)
	// ICO files typically include 16, 32, and 48 pixel versions
	const faviconSizes = [16, 32, 48];
	const faviconBuffers = await Promise.all(
		faviconSizes.map(size =>
			sharp(Buffer.from(HRAS_LOGO_SVG))
				.resize(size, size)
				.png()
				.toBuffer()
		)
	);

	// For simplicity, use the 32x32 version as favicon.ico
	// A proper ICO would need additional processing
	const favicon32 = await sharp(Buffer.from(HRAS_LOGO_SVG))
		.resize(32, 32)
		.png()
		.toBuffer();

	// Write as PNG first (browsers support PNG favicons)
	await writeFile(join(PUBLIC_DIR, 'favicon.png'), favicon32);
	console.log('  ✅ Generated favicon.png');

	// Also generate a simple 32x32 ico-compatible file
	await sharp(Buffer.from(HRAS_LOGO_SVG))
		.resize(32, 32)
		.png()
		.toFile(join(PUBLIC_DIR, 'favicon-32.png'));
	console.log('  ✅ Generated favicon-32.png');

	// Generate apple-touch-icon
	await sharp(Buffer.from(HRAS_LOGO_SVG))
		.resize(180, 180)
		.png()
		.toFile(join(PUBLIC_DIR, 'apple-touch-icon.png'));
	console.log('  ✅ Generated apple-touch-icon.png');

	console.log('\n✨ Icon generation complete!');
	console.log('\n📝 Note: For favicon.ico, convert favicon-32.png using an online tool or:');
	console.log('   brew install imagemagick && convert favicon-32.png favicon.ico');
}

generateIcons().catch(console.error);
