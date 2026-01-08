# HRAS - User Guide

This document provides comprehensive instructions for end users of the HRAS (Human Rights Advisory System).

## Table of Contents

1. [Getting Started](#getting-started)
2. [ Using the System](#using-the-system)
3. [ asking Questions](#asking-questions)
4. [Interpreting Results](#interpreting-results)
5. [Managing Conversations](#managing-conversations)
6. [Advanced Features](#advanced-features)
7. [Troubleshooting Common Issues](#troubleshooting-common-issues)

## Getting Started

### 1. Prerequisites

- A device with internet access
- Modern web browser (Chrome, Firefox, Safari, Edge)
- Access to the HRAS application URL

### 2. Accessing the Application

The HRAS system can be accessed through:

1. **Web Interface:** https://hras.example.com (Production URL)
2. **Local Development:** http://localhost:3000 (Development URL)

### 3. Initial Setup

No installation is required for end users. Simply access the application through your web browser.

## Using the System

### 1. Basic Usage

1. Open the HRAS web application in your browser
2. You'll see a welcome screen with brief instructions
3. Locate the input field labeled "Ask a question about human rights..."
4. Type your question and press Enter or click the submit button

### 2. Example Questions

- "What are the most pressing human rights issues in Syria?"
- "How does the UN address refugee protection?"
- "What are the current trends in gender equality globally?"
- "Tell me about recent human rights violations in Ukraine"

## Asking Questions

### 1. Question Best Practices

1. **Be Specific:** Instead of "Tell me about human rights," try "What are the current child labor violations in Bangladesh?"
2. **Include Context:** "Based on the 2023 Universal Periodic Review, what recommendations were made to Kenya regarding police reform?"
3. **Use Clear Language:** Avoid overly technical jargon if you're new to the system
4. **Start Open:** Begin with broader questions and narrow down as needed

### 2. Advanced Query Techniques

1. **Referencing Previous Conversations:**
   - Include `conversation_id` in your request to continue a previous dialogue
   - Example: `"conversation_id": "550e8400-e29b-41d4-a716-446655440000"`

2. **Requesting Sources:**
   - The system automatically provides source citations
   - Look for the "sources" array in the response

3. **Requesting Clarification:**
   - If the response is unclear, you can ask follow-up questions
   - Example: "Can you elaborate on that point?" or "What does that recommendation mean in practice?"

## Interpreting Results

### 1. Understanding Responses

The system provides responses with three key components:

1. **Message Content:** The main AI-generated response
2. **Sources:** Citations from relevant UN documents
3. **Conversation ID:** Tracks the conversation thread

### 2. Example Response Breakdown

```json
{
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": {
    "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "role": "assistant",
    "content": "Based on UHRI recommendations, key human rights concerns in Kenya include...",
    "created_at": "2024-01-15T10:30:00.000Z"
  },
  "sources": [
    {
      "country": "Kenya",
      "mechanism": "UPR",
      "year": "2023",
      "theme": "Civil and Political Rights",
      "status": "Pending",
      "snippet": "The Committee recommends that Kenya..."
    }
  ]
}
```

### 3. Source Citations

- Each source includes country, mechanism, year, theme, status, and snippet
- You can reference these sources in your follow-up questions
- The system tracks which documents contributed to the response

## Managing Conversations

### 1. Continuing Conversations

- Use the `conversation_id` from the previous response to continue the thread
- This maintains context and shows the conversation history
- Example: Include `"conversation_id": "550e8400-e29b-41d4-a716-446655440000"` in your next request

### 2. Starting New Conversations

- Omit the `conversation_id` parameter to start a new conversation
- Previous context will not be carried forward

### 3. Session Management

- Sessions are typically maintained for 24 hours
- After inactivity, the system may require re-initialization
- No account creation is required for basic usage

## Advanced Features

### 1. Suggested Questions

The system may suggest related questions based on your query pattern.

### 2. Document Reference

- You can request specific document references
- The system can retrieve and quote from specific UN mechanisms

### 3. Customization Options

- **Language Preferences:** Change interface language if available
- **Content Filtering:** Filter results by region or issue area
- **Response Length:** Adjust response detail level

## Troubleshooting Common Issues

### 1. System Not Responding

- Check your internet connection
- Verify you can access other websites
- Try refreshing the page
- Check system status page if available

### 2. Slow Response Times

- The system may be processing complex queries
- Large document sets can increase processing time
- Consider breaking complex questions into smaller parts

### 3. Incorrect or Irrelevant Responses

- The system may not have relevant documents for your query
- Try rephrasing your question with different keywords
- Check if your query relates to recent UN activities

### 4. Technical Errors

- If you encounter system errors, try:
  - Refreshing the page
  - Clear browser cache
  - Using a different browser
  - Checking for system maintenance announcements

### 5. Feature Not Working

- Some advanced features may require specific conditions
- Consult the developer documentation for technical details
- Contact system administrator if issues persist

## Best Practices for Users

1. **Start Broad, Then Narrow:** Begin with general questions and refine as needed
2. **Be Patient:** Complex queries may take longer to process
3. **Use Follow-Ups:** Don't hesitate to ask clarifying questions
4. **Respect Ethical Boundaries:** The system won't provide unauthorized or classified information
5. **Provide Feedback:** If you encounter issues, report them through the appropriate channel

## Feedback and Support

For technical issues or feature requests, please contact:

- **Support Email:** support@hras.example.com
- **GitHub Issues:** https://github.com/hras/hras/issues
- **Documentation:** https://hras.example.com/docs

The system is designed to be intuitive and user-friendly while providing powerful insights into human rights data.