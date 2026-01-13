# 👤 HRAS User Guide

*Your friendly guide to getting answers about human rights using AI*

---

## 🎯 What is HRAS?

HRAS (Human Rights Advisory System) is like having a knowledgeable UN human rights expert available 24/7. It understands your questions in plain English and provides evidence-based answers using official UN documents.

**Think of it as:** Google Search + ChatGPT, but specifically trained on UN human rights documents with proper citations for every answer.

---

## 🚀 Getting Started in 60 Seconds

### Step 1: Access HRAS
- **Production:** Visit your organization's HRAS URL
- **Development:** Open http://localhost:3000 in your browser

### Step 2: Ask Your First Question
Type something like: *"What are the main human rights concerns in Kenya?"*

### Step 3: Review the Answer
You'll get a detailed response plus the specific UN documents that support the answer.

**That's it!** No account setup, no complex configuration - just ask and learn.

---

## 💬 How to Ask Great Questions

### ✅ **Questions That Work Well**

| Type | Example | Why It's Good |
|------|---------|---------------|
| **Country-specific** | "What human rights recommendations has Kenya received?" | Focused scope, clear context |
| **Topic-focused** | "How does the UN address child labor violations?" | Specific subject area |
| **Mechanism-specific** | "What did the 2023 Universal Periodic Review say about Syria?" | Precise source and timeframe |
| **Comparative** | "Compare women's rights progress in Ghana vs Nigeria" | Clear comparison request |

### ❌ **Questions to Avoid**

| Problem | Example | Better Version |
|---------|---------|----------------|
| Too vague | "Tell me about rights" | "What are the main civil and political rights protections?" |
| Too broad | "Everything about Africa" | "What are common human rights challenges across West Africa?" |
| Opinion-based | "Which country is worst for human rights?" | "Which countries have received the most UPR recommendations?" |
| Non-UN scope | "What does Amnesty International say?" | "What UN mechanisms monitor prison conditions?" |

---

## 📊 Understanding Your Answers

Every HRAS response has three parts:

### 1. 💭 **The Main Answer**
A comprehensive response written in plain language, synthesizing information from multiple UN documents.

### 2. 📚 **Source Citations**
Each answer includes specific references showing exactly which UN documents were used:

```json
{
  "country": "Kenya",
  "mechanism": "UPR",           ← Universal Periodic Review
  "year": "2023",
  "theme": "Civil Rights",
  "status": "Pending",
  "snippet": "The Committee recommends..."  ← Exact quote
}
```

### 3. 🆔 **Conversation ID**
A unique identifier that lets you continue the conversation with follow-up questions.

---

## 🔄 Having Conversations

HRAS remembers your conversation context, so you can ask follow-up questions naturally:

### Example Conversation Flow:

**You:** "What human rights issues exist in Myanmar?"

**HRAS:** *[Detailed response about Myanmar's human rights situation with sources]*

**You:** "What specific recommendations were made about the military?"

**HRAS:** *[Focused response about military-related recommendations, remembering we're talking about Myanmar]*

**You:** "How does this compare to similar situations in other countries?"

**HRAS:** *[Comparative analysis drawing on regional examples]*

### 💡 **Conversation Tips**
- Use **pronouns**: "Tell me more about *that*" or "What happened *there*?"
- **Reference previous answers**: "You mentioned three recommendations - can you elaborate on the second one?"
- **Ask for clarification**: "What does that legal term mean?" or "Can you explain that in simpler terms?"

---

## 🎛️ Advanced Features

### 🔍 **Focused Searches**
Be specific about what you want:
- *"Show me only the 2023 recommendations for Colombia"*
- *"What treaty body reports mention indigenous rights?"*
- *"Find UPR recommendations about press freedom"*

### 📈 **Trend Analysis**
Ask about patterns over time:
- *"How have women's rights recommendations changed from 2020 to 2023?"*
- *"What emerging human rights themes appear in recent reports?"*

### 🌍 **Regional Comparisons**
Compare across countries or regions:
- *"Compare refugee protection policies in Europe vs Africa"*
- *"Which Latin American countries have similar trafficking challenges?"*

### 📋 **Mechanism-Specific Queries**
Target specific UN processes:
- *"What did the Committee on the Rights of the Child say about Brazil?"*
- *"Show me all Special Rapporteur reports mentioning digital rights"*

---

## 🛠️ Troubleshooting Common Issues

### 😕 "The answer doesn't seem relevant"

**Possible causes:**
- Question too broad or vague
- Topic outside UN human rights scope
- Using non-standard terminology

**Solutions:**
- Rephrase with more specific terms
- Ask about a particular country or mechanism
- Try breaking complex questions into parts

### 🐌 "Responses are slow"

**Why this happens:**
- Complex questions require searching many documents
- AI is processing multiple sources simultaneously
- High system usage

**What to do:**
- Be patient - quality answers take time
- Try simpler questions first
- Break complex queries into smaller parts

### ❓ "I got an error message"

**Common fixes:**
- Refresh the page and try again
- Check your internet connection
- Make sure your question is complete
- Contact support if problems persist

### 🔄 "I lost my conversation"

**How conversations work:**
- Each conversation gets a unique ID
- Sessions typically last 24 hours
- No login required for basic usage

**To continue conversations:**
- Use the conversation ID from previous responses
- Start fresh if the session expired

---

## 🎯 Best Practices for Different Use Cases

### 📝 **For Research & Analysis**
- Start broad, then narrow down
- Ask for specific document types (UPR, treaty body reports)
- Request comparisons across time periods
- Follow up for clarification and details

### 📊 **For Report Writing**
- Ask for recent recommendations on your topic
- Request specific quotes and citations
- Compare different country situations
- Get background context on legal frameworks

### 🏛️ **For Policy Development**
- Look for emerging trends in recommendations
- Compare international best practices
- Ask about implementation challenges
- Research successful policy examples

### 🎓 **For Learning & Training**
- Start with basic concepts and definitions
- Ask for examples from different regions
- Request step-by-step explanations
- Follow interesting topics deeper

---

## 📞 Getting Help

### 🆘 **When You Need Support**
- **Technical Issues:** System errors, login problems, performance
- **Content Questions:** Understanding responses, finding specific information
- **Feature Requests:** Suggestions for improvements

### 📧 **Contact Information**
- **Support Team:** [Your organization's support email]
- **Documentation:** Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) first
- **Updates:** [Your organization's update channel]

### 💡 **Community Resources**
- **FAQ:** [Link to frequently asked questions]
- **Training Materials:** [Link to training resources]
- **User Forums:** [Link to user community]

---

## 🎉 You're Ready to Start!

HRAS is designed to be intuitive - the best way to learn is by asking questions. Start with something you're genuinely curious about and explore from there.

**Remember:** Every answer includes sources, so you can always verify and dive deeper into the original UN documents.

**Happy exploring!** 🌟
