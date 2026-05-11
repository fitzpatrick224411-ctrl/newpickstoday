#!/bin/bash
# Generates one complete, quality-checked affiliate article and publishes it.
set -e

SITE_DIR="/home/openclaw/site"
OPENCLAW="/home/openclaw/.npm-global/bin/openclaw"
LOG_FILE="$SITE_DIR/generation.log"
MAX_RETRIES=3

ANTHROPIC_API_KEY=$(grep -oP '(?<=ANTHROPIC_API_KEY=)[^\s"]+' /home/openclaw/.config/systemd/user/openclaw-gateway.service.d/env.conf 2>/dev/null || true)
export ANTHROPIC_API_KEY

# Load local .env (includes OPENAI_API_KEY)
if [ -f "$SITE_DIR/.env" ]; then
  set -a
  source "$SITE_DIR/.env"
  set +a
fi

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

TOPICS=(
  # --- VPN Reviews ---
  "NordVPN review 2026: Is it worth the price? Include pros, cons, speed test results, pricing tiers, and a verdict."
  "Best VPN for streaming in 2026: Compare NordVPN, ExpressVPN, and Surfshark for Netflix, Disney+, and BBC iPlayer unblocking. Include a comparison table."
  "Surfshark vs NordVPN 2026: Head-to-head comparison of price, speed, security, and server count. Recommend the best for different use cases."
  "ExpressVPN review 2026: Full breakdown of features, performance, pricing, and whether it beats cheaper alternatives."
  "Best VPN for Windows 2026: Top 5 picks with pros and cons. Focus on ease of use, kill switch, and DNS leak protection."
  "Is a free VPN safe in 2026? Compare free VPNs to paid options. Explain the real risks and recommend budget paid alternatives."
  "Private Internet Access VPN review 2026: Great for advanced users? Review open-source apps, WireGuard support, pricing."
  "Best VPN for gaming 2026: Low latency picks, DDoS protection, and game-specific servers."
  "How to set up a VPN on a router in 2026: Step-by-step guide. Recommend VPNs with router support."
  "Proton VPN review 2026: Is the free tier worth it? Compare free vs paid plans. Focus on privacy credentials."
  "Best VPN for torrenting 2026: P2P-optimized servers, no-logs policy, kill switch. Top 5 picks."
  "CyberGhost VPN review 2026: Streaming servers, privacy policy, price vs value. Who should buy it?"
  "NordVPN vs ExpressVPN 2026: Which is faster? Price, server locations, and security features compared."
  "Does a VPN slow down your internet? Explain how VPNs affect speed and recommend the fastest VPNs."
  "Best cheap VPN 2026: Top 5 VPNs under dollar3/month. Compare Surfshark, Private Internet Access, and Atlas VPN."
  "Best VPN for iPhone 2026: Top 5 iOS VPNs ranked by ease of use, speed, and price."
  "Best VPN for Android 2026: Top picks with focus on battery usage, kill switch, and streaming support."
  "IPVanish VPN review 2026: Fast speeds, unlimited devices, good for Firestick. Full breakdown."
  "Mullvad VPN review 2026: The most private VPN? Anonymous accounts, crypto payments, audit results."
  "Best VPN for travel 2026: Bypass geo-restrictions, work from anywhere, access home content abroad."
  "Best VPN for remote work 2026: Security for home offices, split tunneling, business VPN alternatives."
  "Windscribe VPN review 2026: Generous free tier, built-in ad blocker, pricing compared."
  "VPN vs proxy: What is the difference and which do you actually need in 2026?"
  "Best VPN for China 2026: Which VPNs still work behind the Great Firewall? Obfuscation explained."
  "Atlas VPN review 2026: Solid budget pick or too good to be true? Features, privacy, speed."
  # --- Password Managers ---
  "Best password manager 2026: Compare 1Password, Bitwarden, Dashlane, and NordPass. Include pricing table."
  "1Password review 2026: Detailed review of features, family plan, Travel Mode, and Watchtower security dashboard."
  "Bitwarden review 2026: Best free password manager? Open-source, self-hosting, premium upgrade breakdown."
  "Dashlane review 2026: Password manager with built-in VPN. Is the premium price justified?"
  "LastPass review 2026: Is it still safe after the breach? What changed and alternatives to consider."
  "Best password manager for families 2026: Shared vaults, parental controls, pricing for 5+ members."
  "Best password manager for business 2026: Team vaults, admin controls, SSO integration. Top 4 picks."
  "Keeper password manager review 2026: Zero-knowledge security, BreachWatch dark web monitoring."
  "NordPass review 2026: From the NordVPN team. How does their password manager stack up?"
  "1Password vs Bitwarden 2026: Free vs paid, which is better for most users? Side-by-side comparison."
  # --- Antivirus & Security ---
  "Best antivirus software 2026: Compare Norton, Bitdefender, Malwarebytes, and Kaspersky. Independent test scores."
  "Bitdefender review 2026: Full review of Total Security vs Internet Security. Performance impact, features, pricing."
  "Norton 360 review 2026: Full suite with VPN, dark web monitoring, and identity theft protection. Worth it?"
  "Malwarebytes review 2026: Best for malware removal? Free vs Premium, real-time protection compared."
  "Windows Defender vs paid antivirus 2026: Is the built-in protection good enough? Honest answer."
  "Best antivirus for Mac 2026: Do Macs need antivirus? Top 5 picks for macOS security."
  "Best antivirus for Android 2026: Real protection or bloatware? Top 4 tested apps."
  "McAfee Total Protection review 2026: Is it still worth buying? Performance, features, pricing."
  "Best antivirus for families 2026: Parental controls, multi-device plans, identity protection bundles."
  "Kaspersky review 2026: Is Kaspersky safe to use in 2026? Security concerns, features, alternatives."
  # --- Privacy and Identity ---
  "Best browser for privacy 2026: Brave vs Firefox vs Tor. Which protects you most and is easiest to use?"
  "Brave browser review 2026: Built-in ad blocker, crypto wallet, privacy features. Worth switching from Chrome?"
  "Best encrypted email service 2026: ProtonMail vs Tutanota vs Skiff. Features, free tiers, pricing."
  "Best identity theft protection 2026: LifeLock vs Identity Guard vs Aura. What do they actually cover?"
  "How to protect yourself from hackers in 2026: 10 practical steps anyone can take today."
  # --- VPN for Business/Enterprise ---
  "Best VPN for small business 2026: Dedicated IPs, team management, and site-to-site tunnels. Top 5 picks with pricing."
  "Best enterprise VPN 2026: Cisco AnyConnect vs Palo Alto GlobalProtect vs NordLayer. Features, deployment, cost."
  "NordLayer review 2026: NordVPN for business teams. Centralized admin, SSO, dedicated servers breakdown."
  "Best VPN for remote teams 2026: Zero-trust networking, split tunneling, and team access control compared."
  "Perimeter 81 review 2026: Cloud-delivered network security for SMBs. Features, pricing, ZTNA explained."
  "Business VPN vs consumer VPN: What is the difference and which does your company need in 2026?"
  "Best VPN with static IP 2026: Why businesses need dedicated IPs, and top 5 providers that offer them."
  "VPN vs ZTNA 2026: Is Zero Trust Network Access replacing traditional VPNs for enterprises? Full comparison."
  "Best VPN for accountants and financial firms 2026: Compliance, encryption standards, and audit trail features."
  "How to set up a business VPN in 2026: Step-by-step for IT admins. WireGuard vs OpenVPN for company use."
  # --- Password Manager Deep Dives ---
  "1Password Teams vs Business 2026: Feature differences, pricing tiers, and which plan suits your company size."
  "Bitwarden for teams 2026: How to self-host, set up organizations, and manage shared vaults securely."
  "Dashlane Business review 2026: Password health monitoring, dark web scanning, and SSO integration."
  "Keeper Business review 2026: Role-based access, audit logs, compliance reporting for enterprises."
  "Password manager security explained 2026: How zero-knowledge encryption works and why it matters."
  "Best free password manager for businesses 2026: Bitwarden vs Passbolt vs open-source alternatives."
  "How to migrate from LastPass in 2026: Step-by-step guide to exporting and importing to 1Password or Bitwarden."
  "Password manager vs browser password saving 2026: Why Chrome's built-in manager isn't enough for security."
  "RoboForm review 2026: Veteran password manager still worth it? Features, pricing, and form-filling compared."
  "Enpass review 2026: One-time purchase password manager with local storage. Who is it for?"
  # --- Antivirus Comparisons ---
  "Norton vs Bitdefender 2026: Which antivirus suite wins on protection, performance, and value?"
  "Bitdefender vs Kaspersky 2026: Protection rates, system impact, privacy concerns compared."
  "Best antivirus for Windows 11 2026: Top 5 tested suites with AV-TEST scores and feature breakdown."
  "ESET NOD32 review 2026: Lightweight antivirus for power users. Detection rates, CPU impact, pricing."
  "Sophos Home review 2026: Enterprise-grade antivirus for consumers. Remote management and real-time protection."
  "Trend Micro review 2026: Is it still a top-tier antivirus? Detection rates, privacy tools, and pricing."
  "Best antivirus with VPN included 2026: Norton 360, Bitdefender Premium, and McAfee+ compared."
  "Free antivirus vs paid 2026: What you miss with Avast Free vs Avast Premium. Honest comparison."
  "Avast One review 2026: All-in-one security suite with VPN, cleanup tools, and identity protection."
  "G Data antivirus review 2026: German-engineered security. Dual-engine protection, privacy features, pricing."
  # --- Identity Protection and Privacy Tools ---
  "Aura identity protection review 2026: All-in-one with VPN, antivirus, credit monitoring. Is it worth $12/month?"
  "LifeLock review 2026: Norton's identity theft service explained. Tiers, response guarantees, real value."
  "Identity Guard review 2026: IBM Watson-powered dark web monitoring. Features, pricing, and family plans."
  "Best credit monitoring service 2026: Experian vs Equifax vs TransUnion. Free vs paid compared."
  "Dark web monitoring explained 2026: What services actually scan and alert, and what they can't do."
  "Best privacy tools for 2026: VPN + password manager + identity protection bundle recommendations."
  "How to freeze your credit in 2026: Step-by-step guide to Experian, Equifax, and TransUnion freezes."
  "SSN theft: How to detect it early and what to do if your social security number is compromised."
  "Best family identity protection plan 2026: Aura Family vs LifeLock Family vs Identity Guard Family."
  "Privacy.com review 2026: Virtual card numbers for safe online shopping. How it works and who needs it."
  # --- Security Tools: YubiKey, 2FA, Secure Browsers, Dark Web ---
  "YubiKey review 2026: Best hardware security key? Setup guide, compatible services, and models compared."
  "Best 2FA authenticator app 2026: Google Authenticator vs Authy vs Microsoft Authenticator vs Aegis."
  "Authy vs Google Authenticator 2026: Which is safer? Backup features, multi-device support compared."
  "Best secure browser 2026: Brave vs Firefox vs Tor vs LibreWolf. Privacy settings, fingerprinting resistance."
  "Tor browser review 2026: How it works, when to use it, and what it can and cannot protect you from."
  "Best dark web monitoring tool 2026: Standalone scanners vs bundled identity services compared."
  "Have I Been Pwned explained 2026: How to check if your email is in a data breach and what to do next."
  "Hardware security keys vs software 2FA 2026: When a YubiKey is worth the investment."
  "Best VPN + antivirus + password manager bundle 2026: Top all-in-one security stacks for individuals."
  "Cybersecurity checklist for 2026: 15-point guide covering VPN, 2FA, password manager, and identity protection."
)

TRACKER_FILE="$SITE_DIR/.topic_index"
if [ ! -f "$TRACKER_FILE" ]; then echo "0" > "$TRACKER_FILE"; fi
INDEX=$(cat "$TRACKER_FILE")
TOTAL=${#TOPICS[@]}

if [ "$INDEX" -ge "$TOTAL" ]; then
  log "All $TOTAL topics published. Resetting index for refreshed content cycle."
  echo "0" > "$TRACKER_FILE"
  exit 0
fi

TOPIC="${TOPICS[$INDEX]}"
log "Starting article $((INDEX+1))/$TOTAL: ${TOPIC:0:70}..."

PROMPT="Write a fully complete, detailed blog post for an independent security software review site.

TOPIC: $TOPIC

COMPLETION REQUIREMENTS — every single one must be present or the article is incomplete:
1. H1 title (#) as the very first line
2. Introduction paragraph (2-3 sentences explaining what the article covers and who it helps)
3. At least 4 H2 sections (##) with substantive content under each
4. One markdown comparison or feature table
5. A section titled '## Cons to Consider' or '## Limitations' with at least 3 real drawbacks
6. A section titled '## Final Verdict' with a clear star rating (e.g. 4/5 stars) and specific recommendation
7. A CTA at the very end. Use the most relevant link from this list based on the article topic:
   - VPN articles: > **➡ [Get Surfshark →](https://surfshark.com/deal)** *(affiliate link — we may earn a commission)*
   - ExpressVPN-specific: > **➡ [Get ExpressVPN →](https://www.expressvpn.com/order)** *(affiliate link — we may earn a commission)*
   - Password manager articles: > **➡ [Try 1Password Free →](https://1password.com/sign-up/)** *(affiliate link — we may earn a commission)*
   - Antivirus articles: > **➡ [Get Bitdefender →](https://www.bitdefender.com/solutions/)** *(affiliate link — we may earn a commission)*
   - Identity/privacy articles: > **➡ [Try Aura →](https://www.aura.com/)** *(affiliate link — we may earn a commission)*
   - Generic security: > **➡ [Get Surfshark →](https://surfshark.com/deal)** *(affiliate link — we may earn a commission)*

QUALITY STANDARDS:
- Every claim must be accurate to the best of your knowledge; flag uncertain specifics with '(verify current details at vendor site)'
- Include real cons — no product is perfect; readers trust honest reviews
- Disclose any known controversies or past incidents about the product
- No invented statistics; use ranges or general descriptions if unsure of exact numbers
- Tone: helpful and direct, like a knowledgeable friend — not a sales pitch
- Word count: minimum 1000 words, target 1300+

LEGAL:
- Do not make guarantees (legal, financial, or security)
- Do not invent discount percentages
- Affiliate CTA must use the placeholder format above, never a real URL

Output ONLY the article markdown. Do not explain yourself."

generate_article() {
  "$OPENCLAW" capability model run --local --prompt "$PROMPT" 2>/dev/null \
    | sed -n '/^#/,$p'
}

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

  FAIL=0
  WORD_COUNT=$(echo "$ARTICLE" | wc -w)
  [ "$WORD_COUNT" -lt 600 ] && { log "FAIL: Too short ($WORD_COUNT words, need 600+)."; FAIL=1; }
  echo "$ARTICLE" | grep -q "^# " || { log "FAIL: Missing H1 title."; FAIL=1; }
  echo "$ARTICLE" | grep -q "^## " || { log "FAIL: Missing H2 sections."; FAIL=1; }
  echo "$ARTICLE" | grep -q "Final Verdict" || { log "FAIL: Missing Final Verdict section."; FAIL=1; }
  echo "$ARTICLE" | grep -qi "cons\|limitations\|drawback" || { log "FAIL: Missing cons/limitations section."; FAIL=1; }
  echo "$ARTICLE" | grep -q "PRODUCT_AFFILIATE_LINK\|affiliate" || { log "FAIL: Missing affiliate CTA."; FAIL=1; }

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

TITLE=$(echo "$ARTICLE" | grep "^# " | head -1 | sed 's/^# //')
if [ -z "$TITLE" ]; then log "ERROR: Could not extract title."; exit 1; fi

SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-60)
DATE=$(date +%Y-%m-%d)
FILENAME="$SITE_DIR/_posts/${DATE}-${SLUG}.md"

{
echo "---"
echo "layout: post"
echo "title: \"$TITLE\""
echo "date: $DATE"
echo "author: \"Editorial Team\""
echo "affiliate_disclaimer: \"This post contains affiliate links. We may earn a commission if you purchase through our links, at no extra cost to you.\""
echo "---"
echo ""
} > "$FILENAME"

echo "$ARTICLE" | tail -n +2 >> "$FILENAME"

WORD_COUNT=$(echo "$ARTICLE" | wc -w)
log "Article saved: $FILENAME ($WORD_COUNT words)"
echo $((INDEX + 1)) > "$TRACKER_FILE"

cd "$SITE_DIR"
git add "_posts/${DATE}-${SLUG}.md"
git commit -m "publish: $TITLE"

REMOTE=$(git remote 2>/dev/null)
if [ -n "$REMOTE" ]; then
  git push origin main && log "SUCCESS: Published + pushed — '$TITLE'"
else
  log "SUCCESS: Committed locally — '$TITLE'"
fi

# Track article performance for learning/analytics
echo "{\"date\": \"$DATE\", \"title\": \"$TITLE\", \"slug\": \"$SLUG\", \"words\": $WORD_COUNT, \"topic_index\": $INDEX}" >> "$SITE_DIR/.article_performance.jsonl"

# Auto-promote new article (IndexNow, sitemap pings, Reddit links)
if command -v python3 &>/dev/null; then
  ARTICLE_URL="https://fitzpatrick224411-ctrl.github.io/newpickstoday/${DATE//-/\/}... wait"
  YEAR=$(echo $DATE | cut -d- -f1)
  MONTH=$(echo $DATE | cut -d- -f2)
  DAY=$(echo $DATE | cut -d- -f3)
  ARTICLE_URL="https://fitzpatrick224411-ctrl.github.io/newpickstoday/$YEAR/$MONTH/$DAY/$SLUG/"
  python3 "$SITE_DIR/promote.py" --url "$ARTICLE_URL" --title "$TITLE" >> "$LOG_FILE" 2>&1 &
  log "Promotion queued for: $TITLE"
fi
