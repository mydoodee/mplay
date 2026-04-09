FROM node:18-alpine

# Install system dependencies:
# - python3 and py3-pip: Required for yt-dlp
# - ffmpeg: Often required by yt-dlp to extract or convert audio
RUN apk add --no-cache python3 py3-pip ffmpeg

# Create a virtual environment for Python and install yt-dlp
# This avoids the "externally-managed-environment" error in modern pip
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip3 install -U yt-dlp

# Set the working directory inside the container
WORKDIR /app

# Copy package.json to install Node.js dependencies
COPY package*.json ./

# Install Node.js dependencies
RUN npm install

# Copy the server source code
COPY server.js ./

# Expose the port that the Express app uses
EXPOSE 34560

# Command to run the application
CMD ["npm", "start"]
