FROM node:22-alpine

WORKDIR /app

# Copy everything
COPY . .

# Install dependencies
RUN npm ci --legacy-peer-deps

# Build application
ENV NODE_ENV=production
RUN npm run build

# Create non-root user for security (UID 1001 for K8s compatibility)
RUN addgroup -g 1001 -S nextjs && \
    adduser -S -u 1001 -G nextjs nextjs

# Set ownership of /app and .next directories to non-root user
RUN chown -R nextjs:nextjs /app

# Create .npm cache directory with proper ownership
RUN mkdir -p /home/nextjs/.npm && chown -R nextjs:nextjs /home/nextjs

# Set HOME environment variable for the user
ENV HOME=/home/nextjs

# Switch to non-root user
USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["npm", "start"]