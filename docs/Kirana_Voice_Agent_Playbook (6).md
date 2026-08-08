**THE KIRANA VOICE AGENT**

A Multilingual AI Calling Agent for Grocery & Daily-Essentials Ordering

*Full engineering build \+ deployment \+ costing playbook — India, 2026*

**Scope locked with you:**

Language: Hindi \+ English (Hinglish, code-mixed)

Stage: Pilot, under 500 calls/day — managed APIs, zero GPU ops

Goal: sounds like a real kirana bhaiya, ships in \~1 week

Prepared for Lakshya

July 2026

# **Contents**

# **1\. The honest verdict first**

Everything you described is buildable in 2026 with off-the-shelf pieces — the hard part is not any single component, it is the latency budget and the persona. A pilot that takes real orders in Hinglish, sends WhatsApp confirmation and bill, and reads live inventory/pricing is a one-week job for one competent engineer using managed services. Below is exactly how.

| Two things I have to flag up front (I would be a bad consultant if I hid them) 1\. “Nobody should know it’s an AI” collides with Indian law. Under TRAI’s TCCCPR framework as enforced in 2026, automated/AI voice calls carry a mandatory AI-disclosure and consent obligation, and promotional robocalls must run on 140-series numbers; service/transactional calls on 160-series. The winning move is to make the agent indistinguishable in warmth, language and competence — not to hide that it is automated. A one-line, friendly disclosure at the start costs you nothing in conversion and keeps you out of the ₹10 lakh-penalty zone. 2\. Outbound cold-calling is legally heavier than inbound. Start with inbound \+ warm outbound to your own opted-in customers (people who already bought from the shop). That is low-risk, high-conversion, and sidesteps most DND/telemarketer registration pain. Pure cold outbound comes later, with DLT registration. |
| :---- |

*With that framing, the rest of this document is the build.*

# **2\. What we’re actually building**

Think of it as five layers stitched together, each swappable. A phone call comes in (or the system dials out); the audio is streamed to a real-time orchestrator; that orchestrator runs a tight loop of hear → think → speak while calling your business tools (inventory, price, customer history); and when the order is confirmed, it fires a WhatsApp confirmation and bill. Nothing is bespoke — it is glue code around best-in-class APIs.

**The five layers**

* **Telephony (the phone line):** gets you a real Indian number, connects PSTN calls in/out, and hands raw audio to your code over SIP.

* **Voice orchestration (the brain-stem):** LiveKit Agents — manages the audio stream, turn-taking, barge-in, and the STT→LLM→TTS pipeline in real time.

* **The AI trio (the mind & mouth):** Speech-to-Text (hears Hinglish), the LLM (understands, decides, upsells), Text-to-Speech (speaks like a bhaiya).

* **Business tools (the memory & ledger):** live inventory, price/discount engine, customer \+ order history, demand prediction — exposed to the LLM as function calls.

* **Messaging (the paper trail):** WhatsApp Business API sends order confirmation, itemised bill, and payment link the moment the call ends.

# **3\. Anatomy of a single call (so the flow is concrete)**

Here is one inbound order, start to finish, with the sub-second loop that makes it feel human:

1. **Ring → answer.** Customer calls the shop number. Telephony provider routes the call over SIP into LiveKit, which spins up an agent session.

2. **Greeting (personalised).** System looks up the caller’s number in the customer DB before the first word. “Namaste Sharma ji\! Kirana Store se bol raha hoon. Aaj kya bhijwaana hai?” — it already knows who they are.

3. **Listen with barge-in.** STT streams a live transcript. The moment the customer starts talking, the agent stops talking (interruptible), like a real person.

4. **Understand \+ act.** LLM parses “do kilo aata, ek Amul butter, aur woh wala chai” → calls check\_inventory() and get\_price() → confirms stock and rate.

5. **Recommend / upsell.** “Aata toh hai. Aur bhaiya, aaj Tata Sampann daal par 15% off chal raha hai — daal khatam toh nahi ho gayi?” Driven by the customer’s purchase history \+ current offers.

6. **Confirm the cart.** Agent reads back items \+ total, asks for confirmation, notes delivery time.

7. **Close warmly, then act.** Call ends. Backend writes the order, then fires two WhatsApp messages: order confirmation \+ itemised bill (PDF or text) \+ optional UPI payment link.

8. **Learn.** Order is appended to history; demand model updates. Next week the agent can proactively say “chai aur doodh dono khatam hone waale honge, add kar doon?”

| The number that decides whether it feels human Target end-to-end response latency: under 800 ms from “customer stops speaking” to “agent starts speaking.” Above \~1.2s it feels like a bot; under 800ms it feels like a person who is really listening. Every tool in this doc is chosen to protect that budget. |
| :---- |

# **4\. The recommended 2026 stack, layer by layer**

For each layer: my primary pick for your pilot, why, and the credible alternative if you outgrow it. All primary picks are managed (no servers to babysit) so you can ship in a week.

## **4.1 Telephony — the phone line**

You need an Indian virtual number that can do SIP so LiveKit can grab the audio. Two clean paths:

| Option | Best for | Notes |
| :---- | :---- | :---- |
| Plivo (India DID \+ SIP) | Developer-first pilots | Pay-as-you-go, clean SIP trunking, India numbers (080/022 local or mobile). Connects natively to LiveKit SIP. |
| Exotel / Ozonetel / Knowlarity | India-native, compliance-heavy | Strong DLT/TRAI tooling, local support, bundled credits. Slightly less “raw SIP” but great for scaling in India. |
| Twilio Elastic SIP | Global / multi-country later | Premium reliability, priciest; overkill for an India-only pilot. |

**My pick for the pilot:** Plivo for the number \+ SIP trunk (fast to self-serve, plugs straight into LiveKit), with Exotel as the fallback if you want India-based support and turnkey DLT. Rough India voice cost lands around **₹0.30–₹0.60 / minute** for the PSTN leg.

## **4.2 Orchestration — LiveKit Agents**

This is the spine. LiveKit Agents (1.x in 2026\) handles the real-time media, native SIP for phone calls, semantic turn-detection (knowing when the customer is actually done talking), barge-in, and clean plugins for every STT/LLM/TTS vendor. It is the de-facto standard for production voice agents and gives you sub-500ms transport latency.

* **Why not build the WebSocket/audio plumbing yourself:** turn-detection, jitter buffering and interruption handling are where months disappear. LiveKit gives them to you free.

* **Alternative:** Pipecat (open-source, also excellent, more DIY) or a fully-managed agent platform like Vapi/Retell if you want to skip even LiveKit — faster to demo, less control, higher per-minute cost.

## **4.3 Speech-to-Text — hearing Hinglish**

This is where most global stacks fail on Indian calls. Hinglish \+ phone-quality audio \+ regional accents need an Indic-tuned model.

| STT engine | Why | Indicative price |
| :---- | :---- | :---- |
| Sarvam AI — Saarika | Primary pick. Built for Indian languages \+ code-mixed Hinglish, streaming, low latency. Best accuracy-per-rupee for your use case. | \~₹30 / hour of audio (\~₹0.50/min) |
| Deepgram (Nova, Hindi) | Strong streaming latency; good if you want a global vendor. Weaker on heavy code-mixing than Sarvam. | \~$0.004–$0.01 / min |
| Google / Azure Speech | Broad language coverage, enterprise SLAs; heavier and pricier. | \~$0.016–$0.024 / min |

## **4.4 The LLM — understanding, deciding, upselling**

The LLM is the shopkeeper’s judgment. For voice, you optimise for time-to-first-token and reliable function-calling, not raw IQ. You do NOT need a giant frontier model to take a grocery order.

| Model | Role in your stack | Why |
| :---- | :---- | :---- |
| Gemini 3.x Flash / GPT-4.1-mini / Claude Haiku 4.5 | Primary — the workhorse | Fast time-to-first-token, cheap, solid tool-calling. Ideal for order-taking \+ upsell logic. |
| Sarvam-M (Indic LLM) | Optional Indic reasoning | Strong native Hindi phrasing; can improve naturalness of responses. |
| Speech-to-speech (GPT-Realtime / Gemini Live) | Alternative architecture | Audio-in/audio-out in one loop, \~200ms latency. Fewer moving parts, but less control over the exact bhaiya voice \+ harder to inject tool data mid-sentence. |

**My recommendation:** start with the **chained pipeline** (separate STT → LLM → TTS) using Gemini Flash or GPT-4.1-mini as the brain. It gives you full control over the persona voice and lets the LLM call your inventory/price tools cleanly. Move to speech-to-speech later only if you want to shave the last \~150ms.

## **4.5 Text-to-Speech — the bhaiya voice**

This is 50% of “feels human.” You need a warm, natural Hindi/Hinglish voice with correct pronunciation of grocery brand names (Aashirvaad, Tata Sampann, Amul).

| TTS engine | Why | Indicative price |
| :---- | :---- | :---- |
| Sarvam — Bulbul v3 | Primary pick. Native Indian-language TTS, natural Hinglish prosody, handles brand names, low latency. | \~₹30 / 10K characters |
| ElevenLabs (Flash/Turbo, Hindi) | Most expressive/emotional voices; great for a signature brand voice. Pricier, watch latency. | \~$0.05–$0.10 / min equivalent |
| Google/Azure Neural TTS | Reliable, cheaper, slightly more ‘robotic’ on Hinglish. | \~$0.004–$0.016 / min |

**Pro move:** clone/design ONE consistent voice for your shop persona and use it everywhere. Consistency is what makes regulars trust “the bhaiya.”

## **4.6 WhatsApp — the paper trail**

The moment the call ends, the customer must get confirmation \+ bill. This runs on the official WhatsApp Business Platform (Cloud API) through a BSP (Business Solution Provider).

* **BSP options (India):** AiSensy, Gupshup, Interakt, WATI, or Meta Cloud API direct. For a pilot, a BSP like AiSensy/Interakt is fastest — they handle template approval and give you a clean API.

* **What you send:** an approved “utility” template for order confirmation \+ bill (utility messages are \~7–8x cheaper than marketing). The bill can be text or an attached PDF generated server-side.

* **The free window trick:** once the customer replies to your WhatsApp, a 24-hour service window opens where all messages are free — use it for delivery updates and support.

## **4.7 The data layer — inventory, price, customers, demand**

This is your moat. The AI is a commodity; your live data and prediction are not. Keep it boring and reliable:

| Data | Where it lives | How the agent uses it |
| :---- | :---- | :---- |
| Inventory \+ price/discount | PostgreSQL (managed: AWS RDS / Supabase / Neon). One row per SKU: stock, MRP, your price, active offer. | Exposed as check\_inventory() / get\_price() function calls the LLM makes mid-conversation. |
| Customer profile \+ order history | Same Postgres, keyed by phone number. | Personalises greeting, powers “you usually buy…” upsells. |
| Fast lookups / session cache | Redis (managed: Upstash / ElastiCache). | Sub-10ms reads so tool calls don’t break the latency budget. |
| Demand prediction | Start as a nightly SQL/Python job over order history (reorder-cycle model). Graduate to a proper model later. | Flags “likely to reorder” items for proactive outbound \+ upsell. |
| **Demand prediction — don’t over-engineer it on day one** **For the pilot, ‘prediction’ \= a simple reorder-cycle heuristic:** if a customer buys atta every \~18 days, on day 16 flag it. This is a GROUP BY \+ date-diff query, not deep learning, and it already feels magical on a call. Add gradient-boosted or time-series models (Prophet/XGBoost) only once you have a few thousand orders. |  |  |

## **4.8 Hosting & infra**

For a sub-500-calls/day pilot you do NOT need Kubernetes or GPUs. Everything AI is a managed API call.

* **Compute:** one small cloud VM or container (AWS ECS Fargate / a single EC2 t3.medium, or Railway/Render) running your LiveKit agent worker \+ backend. Host in an India region (ap-south-1, Mumbai) to cut latency to Indian callers.

* **Database:** managed Postgres \+ Redis (above).

* **LiveKit:** use LiveKit Cloud (their managed tier) for the pilot — free/Build tier covers early testing, paid tiers scale concurrency.

* **Observability:** log every call’s transcript, latency per turn, and tool calls. LiveKit \+ a tool like Langfuse/Helicone for LLM traces. You will live in these logs during tuning.

# **5\. The part that actually matters: making it sound human**

Anyone can wire the boxes together. The difference between a demo and a bhaiya customers love is these details:

**Latency budget (defend 800ms like your life depends on it)**

| Stage | Target | How to protect it |
| :---- | :---- | :---- |
| Telephony \+ transport | \~150 ms | India-region hosting, LiveKit SIP. |
| STT (streaming, partial) | \~150–250 ms | Streaming STT, act on partials; don’t wait for the full sentence. |
| LLM time-to-first-token | \~250–400 ms | Small fast model, short system prompt, stream tokens. |
| TTS first audio chunk | \~150–250 ms | Streaming TTS, start speaking on first chunk. |

**Human tricks to engineer in**

* **Barge-in / interruptibility:** customer can cut the agent off mid-sentence and it stops instantly. Non-negotiable.

* **Filler \+ backchannel:** tiny “hmm”, “ji”, “achha”, “ek second” while a tool call runs, so silence never feels dead.

* **Thinking-noise over tool latency:** when calling inventory, speak a natural bridge (“dekh raha hoon bhaiya…”) so the 200ms DB call is invisible.

* **Warm, imperfect speech:** contractions, regional particles (‘na’, ‘toh’, ‘bhaiya’), varied phrasing. Never read like a form.

* **Memory:** greet by name, reference last order. This single thing is what makes people forget they’re on an automated line.

* **Graceful fallback:** if confused twice, warmly offer “main aapko dukaan par transfer kar deta hoon” — a human handoff path prevents the worst-case bad call.

# **6\. Real costing — per minute, per call, per month**

Let’s cost a realistic pilot call. Assume an average order call is \~3 minutes and ends with 2 WhatsApp messages (confirmation \+ bill). All figures are 2026 indicative rates; treat them as ±20% and confirm on each vendor’s console.

**Per-minute cost of a live conversation**

| Component | Rate (indicative) | Per min |
| :---- | :---- | :---- |
| Telephony (PSTN, India) | ₹0.30–₹0.60 / min | \~₹0.45 |
| LiveKit agent session | \~$0.01 / min (≈₹0.85) | \~₹0.85 |
| LiveKit SIP | \~$0.004 / min | \~₹0.35 |
| STT (Sarvam Saarika) | \~₹30 / hr | \~₹0.50 |
| LLM (fast model) | \~$0.01–$0.05 / call | \~₹1.00 (spread) |
| TTS (Sarvam Bulbul) | \~₹30 / 10K chars | \~₹1.00 |
| TOTAL conversation |  | \~₹4.0–₹5.0 / min |

**Cost of one complete 3-minute order call**

| Item | Cost |
| :---- | :---- |
| 3 min of conversation (≈₹4.5/min) | \~₹13.5 |
| WhatsApp: 2 utility messages (≈₹0.13 each \+ 18% GST) | \~₹0.3 |
| Data / infra amortised per call | \~₹0.5 |
| Total per completed order call | \~₹14–₹16 |

Headline number: roughly **₹14–₹16 (≈ $0.17–$0.19) per 3-minute order call**, all-in. That is dramatically cheaper than a human tele-caller and available 24/7 in the customer’s language.

**Monthly pilot cost (illustrative)**

At 300 calls/day × 30 days \= 9,000 calls/month × \~₹15 \= roughly ₹1.35 lakh/month in variable cost. Add fixed costs: LiveKit paid tier (\~$50–$500/mo depending on concurrency), managed DB \+ VM (\~$50–$150/mo), WhatsApp BSP platform fee (a few thousand rupees/mo). Realistic all-in pilot: ₹1.5–₹2.0 lakh/month at 9,000 calls.

| How to cut per-minute cost as you scale At higher volume, self-host STT/TTS on a GPU (Sarvam/Whisper-class \+ open TTS) instead of per-minute APIs — this is the single biggest lever, often halving conversation cost. Negotiate telephony volume rates with Exotel/Plivo once you cross \~50k min/month. Keep calls tight: a well-designed agent that closes in 2 minutes instead of 4 halves your bill instantly. Use utility (not marketing) WhatsApp templates, and lean on the free 24-hour service window. |
| :---- |

# **7\. What you legally and practically need (the paperwork)**

This is the part most people trip on. Here is the exact checklist for India, 2026\.

## **7.1 To get an Indian calling number (KYC)**

Telephony providers (Plivo/Exotel/etc.) will not give you a number without business KYC. You need:

* **Business registration proof —** a Certificate of Incorporation (private limited, from MCA) OR an Udyam/MSME registration (works for proprietorship/small business). This is the key document.

* **Business PAN OR GST certificate —** at least one; both is better. If you’re not GST-registered you can self-declare ‘GST unregistered’ on some consoles (e.g. Plivo), but GST helps.

* **Address proof \+ authorised-signatory ID** (Aadhaar/PAN of the person signing up).

* **For 080/022 local numbers:** verification is usually same-day to \~1 business day once docs are in.

**Bottom line:** you can operate as a **proprietor with Udyam \+ PAN** for the pilot. You do NOT strictly need a Pvt Ltd to start, but a registered entity \+ GST makes every vendor (telephony, WhatsApp, payments) smoother and is worth doing before you scale.

## **7.2 To get the WhatsApp Business API**

* **A Meta Business Manager account** (business verification: your registration docs \+ a matching business phone/website).

* **A dedicated phone number** not already on a personal WhatsApp (a new SIM or a number you can receive an OTP on).

* **Display-name \+ template approval** through your BSP (AiSensy/Gupshup/Interakt). Utility templates for ‘order confirmation’ / ‘bill’ get approved fast.

* **Note the two-layer bill:** Meta’s per-message fee (fixed) \+ your BSP’s platform fee (negotiable) \+ 18% GST on both.

## **7.3 Compliance you must respect (TRAI \+ DPDP)**

* **AI disclosure:** open with a friendly line making clear it’s an automated assistant from the shop. Legally expected in 2026; costs nothing in trust if done warmly.

* **Number series:** service/transactional calls to your own customers ride 160-series; promotional/cold calls need 140-series \+ DLT registration. Start with the former.

* **Consent \+ DND:** only call customers who opted in (existing buyers). Honour opt-out immediately. Keep a consent log.

* **DPDP (data protection):** you’re storing phone numbers \+ order history — collect consent, store securely, allow deletion. Basic hygiene, not a blocker.

* **Recording notice:** if you record calls (you should, for tuning), disclose it.

# **8\. Your one-week build plan**

A realistic day-by-day for one engineer (you or a hire) to get a working pilot that takes a real Hinglish order and sends a WhatsApp bill.

| Day | Focus | What you do |
| :---- | :---- | :---- |
| Day 1 | Accounts \+ numbers | Open LiveKit Cloud, Sarvam, an LLM provider (OpenAI/Google), a telephony account (Plivo/Exotel), and start WhatsApp BSP onboarding \+ business verification (this has the longest lead time — kick it off first). Get an India DID number. |
| Day 2 | Hello, phone | Wire telephony SIP → LiveKit. Get a call to connect and a canned TTS voice to answer. This proves the hardest plumbing early. |
| Day 3 | The voice loop | Plug in Sarvam STT \+ LLM \+ Sarvam TTS in LiveKit’s pipeline. Have a free-form Hinglish conversation with no business logic yet. Tune barge-in \+ latency. |
| Day 4 | Business tools | Stand up Postgres \+ Redis. Seed \~50 SKUs with stock/price/offers and a few test customers with history. Expose check\_inventory / get\_price / get\_customer / place\_order as LLM function calls. |
| Day 5 | The persona | Write the system prompt: bhaiya personality, greeting-by-name, upsell rules, confirmation script, fallback-to-human. Iterate on voice \+ phrasing until it feels real. This is where you spend the most love. |
| Day 6 | WhatsApp \+ bill | On place\_order, generate the bill and fire the approved utility template(s) via the BSP. Add a UPI payment link if you want. Test the full ring→order→WhatsApp loop end to end. |
| Day 7 | Harden \+ pilot | Add logging/observability, error handling, DND/consent checks and the AI-disclosure line. Do 20–30 live test calls with friends/family, listen to recordings, fix the worst 5 things. Ship to a handful of real customers. |

# **9\. Scaling path & the risks to watch**

**When you outgrow the pilot**

* **Cost:** self-host STT/TTS on GPUs (biggest saving); negotiate telephony volume rates.

* **Concurrency:** move LiveKit workers to autoscaling ECS/K8s; size your SIP trunk for peak simultaneous calls.

* **Intelligence:** real demand-forecasting models, per-customer upsell optimisation, multi-language beyond Hinglish.

* **Outbound at scale:** DLT registration, 140-series, campaign scheduling, DND scrubbing pipeline.

**The five risks that actually bite**

* **Latency creep:** one slow tool call ruins the illusion. Cache aggressively, monitor per-turn latency.

* **Hinglish edge cases:** brand names, quantities (‘paav kilo’, ‘dhai sau gram’), accents. Collect real call failures and tune weekly.

* **Order accuracy:** always read back the cart \+ total before confirming. A wrong order destroys trust faster than a robotic voice.

* **Compliance drift:** TRAI enforcement got aggressive in 2026 (tens of thousands of numbers disconnected). Stay on the right number series, keep consent logs.

* **Telephony reliability:** have a fallback provider; a dead line \= dead business.

| If you do only ONE thing right Spend 60% of your effort on the persona \+ latency, not the plumbing. The stack in this document is a solved problem — you can wire it in days. Whether customers love “the bhaiya” or feel like they’re fighting a robot comes down to voice quality, sub-800ms responses, memory of past orders, and warm human phrasing. That is the moat, and that is where a great AI engineer earns their keep. |
| :---- |

# **Appendix: one-glance stack summary**

| Layer | Pilot pick | Scale-up option |
| :---- | :---- | :---- |
| Telephony | Plivo (India DID \+ SIP) | Exotel/Ozonetel volume rates |
| Orchestration | LiveKit Cloud (Agents) | Self-hosted LiveKit / Pipecat |
| STT | Sarvam Saarika | Self-hosted Indic STT on GPU |
| LLM | Gemini Flash / GPT-4.1-mini / Haiku | Fine-tuned / speech-to-speech |
| TTS | Sarvam Bulbul v3 | ElevenLabs signature voice / self-host |
| Messaging | WhatsApp Cloud API via AiSensy/Interakt | Direct Meta Cloud API |
| Data | Postgres (RDS/Supabase) \+ Redis (Upstash) | Warehouse \+ feature store |
| Demand model | Reorder-cycle SQL heuristic | XGBoost / time-series forecasting |
| Hosting | 1 VM/Fargate in ap-south-1 (Mumbai) | Autoscaling ECS/K8s |

*Prices and vendor capabilities in this document are 2026 indicative figures gathered from public pricing pages; confirm exact rates on each provider’s console before you commit, as India telephony and WhatsApp rates change quarterly.*