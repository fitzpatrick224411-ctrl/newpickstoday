#!/bin/bash
# Generates one complete, quality-checked affiliate article and publishes it.
# Article is NOT published if it fails quality checks.
set -e

SITE_DIR="/home/openclaw/site"
OPENCLAW="/home/openclaw/.npm-global/bin/openclaw"
LOG_FILE="$SITE_DIR/generation.log"
MAX_RETRIES=3

# Load API key from systemd drop-in so the script works outside the service env
ANTHROPIC_API_KEY=$(grep -oP '(?<=ANTHROPIC_API_KEY=)[^\s"]+' /home/openclaw/.config/systemd/user/openclaw-gateway.service.d/env.conf 2>/dev/null || true)
export ANTHROPIC_API_KEY

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

TOPICS=(
  "NordVPN review 2026: Is it worth the price? Include pros, cons, speed test results, pricing tiers, and a verdict."
  "Best VPN for streaming in 2026: Compare NordVPN, ExpressVPN, and Surfshark for Netflix, Disney+, and BBC iPlayer unblocking. Include a comparison table."
  "Surfshark vs NordVPN 2026: Head-to-head comparison of price, speed, security, and server count. Recommend the best for different use cases."
  "ExpressVPN review 2026: Full breakdown of features, performance, pricing, and whether it beats cheaper alternatives."
  "Best VPN for Windows 2026: Top 5 picks with pros and cons. Focus on ease of use, kill switch, and DNS leak protection."
  "Best password manager 2026: Compare 1Password, Bitwarden, Dashlane, and NordPass. Include a pricing table and recommendation for families vs individuals."
  "1Password review 2026: Detailed review of features, family plan, Travel Mode, and Watchtower."
  "Is a free VPN safe in 2026? Compare free VPNs to paid options. Explain the real risks and recommend budget paid alternatives."
  "Best antivirus software 2026: Compare Norton, Bitdefender, Malwarebytes, and Kaspersky. Include independent test scores and pricing."
  "Bitdefender review 2026: Full review of Total Security vs Internet Security plans. Performance impact, features, pricing."
  "Best VPN for iPhone 2026: Top 5 iOS VPNs ranked by ease of use, speed, and price."
  "Best VPN for Android 2026: Top picks with focus on battery usage, kill switch, and streaming support."
  "NordVPN vs ExpressVPN 2026: Which is faster? Price comparison, server locations, and security features."
  "Does a VPN slow down your internet? Explain how VPNs affect speed. Recommend the fastest options."
  "Best cheap VPN 2026: Top 5 VPNs under dollar3/month. Compare Surfshark, Private Internet Access, and Atlas VPN."
  "Private Internet Access VPN review 2026: Great for advanced users? Review open-source apps, WireGuard support, pricing."
  "Best VPN for gaming 2026: Low latency picks, DDoS protection, and game-specific servers."
  "How to set up a VPN on a router in 2026: Step-by-step guide. Recommend VPNs with router support."
  "Proton VPN review 2026: Is the free tier worth it? Compare free vs paid plans. Focus on privacy."
  "Best VPN for torrenting 2026: P2P-optimized servers, no-logs policy, kill switch. Top 5 picks."
)

TRACKER_FILE="$SITE_DIR/.topic_index"
if [ ! -f "$TRACKER_FILE" ]; then echo "0" > "$TRACKER_FILE"; fi
INDEX=$(cat "$TRACKER_FILE")
TOTAL=${#TOPICS[@]}

if [ "$INDEX" -ge "$TOTAL" ]; then
  log "All topics used. Add more to the TOPICS array in generate_article.sh."
  exit 0
fi

TOPIC="${TOPICS[$INDEX]}"
log "Starting article $((INDEX+1))/$TOTAL: ${TOPIC:0:70}..."

PROMPT="Write a fully complete, detailed blog post for an independent security software review site.

TOPIC: $TOPIC

COMPLETION REQUIREMENTS — every single one must be present or the article is incomplete:
1. H1 title (#) as the very first line
2. Introduction paragraph (2-3 sentences explaining what the article covers and who it helps)
3. At least 3 H2 sections (##) with substantive content under each
4. One markdown comparison or feature table
5. A section titled '## Cons to Consider' or '## Limitations' with at least 3 real drawbacks
6. A section titled '## Final Verdict' with a clear, specific recommendation
7. A CTA at the very end in this exact format:
   > **➡ [PRODUCT_AFFILIATE_LINK]** *(affiliate link — we may earn a commission)*

QUALITY STANDARDS:
- Every claim must be accurate to the best of your knowledge; flag uncertain specifics with '(verify current details at vendor site)'
- Include real cons — no product is perfect; readers trust honest reviews
- Disclose any known controversies or past incidents about the product
- No invented statistics; use ranges or general descriptions if unsure of exact numbers
- Tone: helpful and direct, like a knowledgeable friend — not a sales pitch
- Word count: minimum 900 words, target 1100

LEGAL:
- Do not make guarantees (legal, financial, or security)
- Do not invent discount percentages
- Affiliate CTA must use the placeholder format above, never a real URL

Output ONLY the article markdown. Do not explain yourself. Do not add commentary before or after."

generate_article() {
  # capability model run outputs 4 metadata lines before the article; strip them
  "$OPENCLAW" capability model run --local --prompt "$PROMPT" 2>/dev/null \
    | sed -n '/^#/,$p'
}

# Retry loop — try up to MAX_RETRIES times to get a complete article
ATTEMPT=0
ARTICLE=""
while [ $ATTEMPT -lt $MAX_RETRIES ]; do
  ATTEMPT=$((ATTEMPT + 1))
  log "Generation attempt $ATTEMPT/$MAX_RETRIES..."
  ARTICLE=$(generate_article)

  if [ -z "$ARTICLE" ]; then
    log "WARNING: Empty response on attempt $ATTEMPT."
    continue
  fi

  # Quality checks
  FAIL=0
  WORD_COUNT=$(echo "$ARTICLE" | wc -w)
  [ "$WORD_COUNT" -lt 600 ] && { log "FAIL: Too short ($WORD_COUNT words, need 600+)."; FAIL=1; }
  echo "$ARTICLE" | grep -q "^# " || { log "FAIL: Missing H1 title."; FAIL=1; }
  echo "$ARTICLE" | grep -q "^## " || { log "FAIL: Missing H2 sections."; FAIL=1; }
  echo "$ARTICLE" | grep -q "Final Verdict" || { log "FAIL: Missing Final Verdict section."; FAIL=1; }
  echo "$ARTICLE" | grep -qi "cons\|limitations\|drawback" || { log "FAIL: Missing cons/limitations section."; FAIL=1; }
  echo "$ARTICLE" | grep -q "PRODUCT_AFFILIATE_LINK\|affiliate" || { log "FAIL: Missing affiliate CTA."; FAIL=1; }
  echo "$ARTICLE" | grep -q "|" || { log "WARNING: No table found — article may be incomplete."; }

  if [ $FAIL -eq 0 ]; then
    log "Quality check PASSED ($WORD_COUNT words)."
    break
  else
    log "Quality check failed on attempt $ATTEMPT. Retrying..."
    ARTICLE=""
  fi
done

if [ -z "$ARTICLE" ]; then
  log "ERROR: Failed to generate a complete article after $MAX_RETRIES attempts. Topic saved for retry."
  exit 1
fi

# Extract title and build filename
TITLE=$(echo "$ARTICLE" | grep "^# " | head -1 | sed 's/^# //')
if [ -z "$TITLE" ]; then
  log "ERROR: Could not extract title from article."
  exit 1
fi

SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-60)
DATE=$(date +%Y-%m-%d)
FILENAME="$SITE_DIR/_posts/${DATE}-${SLUG}.md"

# Write Jekyll post with front matter
cat > "$FILENAME" << FRONTMATTER
---
layout: post
title: "$TITLE"
date: $DATE
author: "Editorial Team"
affiliate_disclaimer: "This post contains affiliate links. We may earn a commission if you purchase through our links, at no extra cost to you. Our recommendations are based on honest evaluation — not commission rates."
---

FRONTMATTER

# Append body (skip the H1 line — it's now in front matter as title)
echo "$ARTICLE" | grep -v "^# " | head -1 > /dev/null  # sanity
echo "$ARTICLE" | tail -n +2 >> "$FILENAME"

WORD_COUNT=$(echo "$ARTICLE" | wc -w)
log "Article saved: $FILENAME ($WORD_COUNT words)"

# Advance topic index only after successful save
echo $((INDEX + 1)) > "$TRACKER_FILE"

# Commit and push to GitHub
cd "$SITE_DIR"
git add "_posts/${DATE}-${SLUG}.md"
git commit -m "publish: $TITLE"

REMOTE=$(git remote 2>/dev/null)
if [ -n "$REMOTE" ]; then
  git push origin main && log "SUCCESS: Published + pushed — '$TITLE'"
else
  log "SUCCESS: Article committed locally — '$TITLE' (no remote set yet; run: git remote add origin https://TOKEN@github.com/USERNAME/securepickstoday.git)"
fi
