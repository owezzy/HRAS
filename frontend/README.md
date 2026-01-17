# HRAS Frontend

Next.js 15 frontend for the Human Rights Advisory System, built with Fuse React template.

## Overview

The HRAS frontend provides a conversational interface for UN human rights officers to query UHRI documents and receive AI-generated responses with source citations.

**Key Features:**
- Chat interface with message history
- Real-time streaming responses (planned)
- Source document display with citations
- Responsive design with Material-UI
- Dark/light mode support

## Tech Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| **Next.js** | 15 | React framework with App Router |
| **React** | 19 | UI library |
| **MUI** | 7 | Component library |
| **TailwindCSS** | 4 | Utility-first CSS |
| **TypeScript** | 5 | Type safety |
| **React Query** | Latest | Server state management |
| **react-hook-form** | Latest | Form handling |
| **Zod** | Latest | Schema validation |

## Quick Start

```bash
# Install dependencies
npm install

# Run development server with Turbopack
npm run dev

# Access at http://localhost:3000
```

## Available Scripts

```bash
npm run dev          # Start dev server (Turbopack)
npm run build        # Production build
npm run start        # Start production server
npm run lint         # Run ESLint
npm run lint:fix     # Fix ESLint issues
```

## Project Structure

```
frontend/
├── src/
│   ├── app/                    # Next.js App Router pages
│   │   ├── (main)/             # Main layout group
│   │   │   └── chat/           # Chat interface
│   │   ├── layout.tsx          # Root layout
│   │   └── page.tsx            # Home page
│   ├── @fuse/                  # Fuse React UI framework
│   │   ├── core/               # Core components (layouts, navigation)
│   │   ├── hooks/              # Shared hooks
│   │   └── utils/              # Utilities
│   ├── @auth/                  # Authentication (future)
│   ├── @i18n/                  # Internationalization (future)
│   ├── components/             # HRAS components
│   │   ├── chat/               # Chat interface components
│   │   ├── sources/            # Source citation display
│   │   └── shared/             # Reusable components
│   ├── lib/                    # Utilities and helpers
│   ├── hooks/                  # Custom React hooks
│   └── types/                  # TypeScript type definitions
├── public/                     # Static assets
├── .env.local                  # Local environment variables
├── .env.production             # Production env vars
├── next.config.js              # Next.js configuration
├── tailwind.config.js          # Tailwind configuration
├── tsconfig.json               # TypeScript configuration
└── package.json
```

## Environment Variables

### Development (.env.local)
```env
NEXT_PUBLIC_API_URL=http://localhost:8000
```

### Production (.env.production)
```env
NEXT_PUBLIC_API_URL=https://api.hras.owezzy.tech
```

## Code Style

### Prettier Configuration
- **Indentation**: Tabs (tabWidth: 4)
- **Quotes**: Single quotes
- **Trailing Commas**: None
- **Line Width**: 120 characters
- **Semicolons**: Required
- **JSX**: Single attribute per line

### ESLint Rules
- `unused-imports/no-unused-imports`: error
- `no-console`: error (except console.error)
- Unused vars with `_` prefix are allowed

### TypeScript
- **Strict Mode**: OFF (legacy Fuse codebase)
- **Module Resolution**: Node
- **JSX**: preserve
- **Target**: ESNext

## Key Components

### Chat Interface
```typescript
// src/app/(main)/chat/page.tsx
// Main chat interface with message history
```

### API Integration
```typescript
// src/lib/api.ts
import { useQuery, useMutation } from '@tanstack/react-query';

// Send chat message
const { mutate: sendMessage } = useMutation({
  mutationFn: (message: string) =>
    fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message })
    }).then(res => res.json())
});
```

## Path Aliases

```typescript
// Configured in tsconfig.json
@auth/*        → ./src/@auth/*
@i18n/*        → ./src/@i18n/*
@fuse/*        → ./src/@fuse/*
@history*      → ./src/@history
@schema        → ./src/@schema
@/*            → ./src/*
```

## Styling

### TailwindCSS
Use utility classes for layout and basic styling:
```jsx
<div className="flex flex-col gap-4 p-6">
  <h1 className="text-2xl font-bold">Chat</h1>
</div>
```

### Material-UI
Use MUI components for complex UI elements:
```jsx
import { Button, TextField } from '@mui/material';

<Button variant="contained" color="primary">
  Send
</Button>
```

### Emotion
Use for MUI theme customization and component overrides.

## React Patterns

### Components
- Functional components only
- Named exports preferred
- Use TypeScript for props

```tsx
interface ChatMessageProps {
  message: string;
  role: 'user' | 'assistant';
  sources?: Source[];
}

export function ChatMessage({ message, role, sources }: ChatMessageProps) {
  return (
    <div className={`message message-${role}`}>
      {message}
      {sources && <SourceList sources={sources} />}
    </div>
  );
}
```

### State Management
- **Local State**: useState/useReducer
- **Server State**: React Query
- **Form State**: react-hook-form + Zod

```tsx
import { useForm } from 'react-hook-form';
import { z } from 'zod';

const chatSchema = z.object({
  message: z.string().min(1).max(4000)
});

type ChatForm = z.infer<typeof chatSchema>;

function ChatInput() {
  const { register, handleSubmit } = useForm<ChatForm>();

  const onSubmit = (data: ChatForm) => {
    sendMessage(data.message);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('message')} />
      <button type="submit">Send</button>
    </form>
  );
}
```

## Production Deployment

The frontend is deployed to AWS Amplify with automatic builds on push to main branch.

**Production URL**: https://hras.owezzy.tech

See [Amplify Deployment Guide](../docs/deployment/aws/AMPLIFY_DEPLOYMENT.md) for details.

## Development Tips

### Hot Reload
Turbopack provides fast hot module replacement. Changes to components reflect immediately.

### Type Checking
```bash
# Run type checker
npx tsc --noEmit
```

### Debugging
1. Use browser DevTools
2. React DevTools extension
3. Check network tab for API calls

### Common Issues

**CORS Errors:**
- Verify `NEXT_PUBLIC_API_URL` is correct
- Check backend CORS configuration includes frontend URL

**Module Not Found:**
- Clear Next.js cache: `rm -rf .next`
- Reinstall dependencies: `npm install`

**Styling Not Applied:**
- Check Tailwind config includes all content paths
- Verify MUI theme is properly initialized

## Fuse React

This project is built on the Fuse React template. The `@fuse/` directory contains the Fuse framework code.

**Fuse Documentation**: https://fusetheme.com/

**Key Fuse Features:**
- Pre-built layouts (vertical navigation, horizontal navigation)
- Theme customization system
- Navigation configuration
- Settings panel
- Message/notification system

## Contributing

When adding new components:
1. Place HRAS-specific components in `src/components/`
2. Follow existing naming conventions
3. Add TypeScript types in `src/types/`
4. Use React Query for API calls
5. Keep components small and focused
6. Add error boundaries where appropriate

## License

MIT License - See LICENSE file for details
