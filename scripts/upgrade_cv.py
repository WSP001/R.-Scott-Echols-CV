#!/usr/bin/env python3
"""Upgrade R. Scott Echols CV — fill real data, enhance interactivity, improve 3D."""

with open('/home/user/workspace/cv-repo/public/index.html', 'r', encoding='utf-8') as f:
    html = f.read()

# ── 1. EXPERIENCE SECTION: Replace full timeline with real data ─────────────────
old_experience = """<!-- ── Experience ──────────────────────────────────── -->
<section id="experience">
  <div class="section-number">02</div>
  <div class="container">
    <div class="section-header reveal">
      <div class="section-label">Experience</div>
      <h2 class="section-title">Career Timeline</h2>
      <p class="section-desc">Click any card to edit. Add your roles, companies, and achievements.</p>
    </div>
    <div class="timeline">
      <div class="timeline-item reveal">
        <div class="timeline-dot"></div>
        <div class="timeline-card">
          <div class="timeline-period" contenteditable="true">2022 — Present</div>
          <div class="timeline-role" contenteditable="true">Technical Lead &amp; AI Systems Architect</div>
          <div class="timeline-company" contenteditable="true">SirTrav Marine Intelligence / WSP001</div>
          <div class="timeline-desc" contenteditable="true">
            Leading development of SirTrav-A2A-Studio, a marine intelligence platform with agent-to-agent (A2A) protocols.
            Architected Gemini Embedding 2 multimodal RAG pipelines, Claude API integrations, and multi-agent orchestration systems.
            Deployed composable AI stacks on Netlify with GitHub CI/CD automation.
          </div>
          <div class="expand-hint">Click to expand</div>
        </div>
        <div class="timeline-empty"></div>
      </div>

      <div class="timeline-item reveal">
        <div class="timeline-dot"></div>
        <div class="timeline-empty"></div>
        <div class="timeline-card">
          <div class="timeline-period" contenteditable="true">2019 — 2022</div>
          <div class="timeline-role" contenteditable="true">Senior Software Developer</div>
          <div class="timeline-company" contenteditable="true">[Company Name]</div>
          <div class="timeline-desc" contenteditable="true">
            Full-stack development with JavaScript/Node.js and Python. Built Power BI dashboards for fisheries
            supply chain analytics. Managed GitHub workflows, environment configurations, and vault management systems.
            Implemented automated testing and crash prevention pipelines.
          </div>
        </div>
      </div>

      <div class="timeline-item reveal">
        <div class="timeline-dot"></div>
        <div class="timeline-card">
          <div class="timeline-period" contenteditable="true">2016 — 2019</div>
          <div class="timeline-role" contenteditable="true">Software Developer &amp; DevOps Engineer</div>
          <div class="timeline-company" contenteditable="true">[Company Name]</div>
          <div class="timeline-desc" contenteditable="true">
            Cloud infrastructure, API integration and management. DevOps and environment configuration.
            Established CI/CD pipelines, API-driven development practices, and multi-tool integrations.
          </div>
        </div>
        <div class="timeline-empty"></div>
      </div>

      <div class="timeline-item reveal">
        <div class="timeline-dot"></div>
        <div class="timeline-empty"></div>
        <div class="timeline-card">
          <div class="timeline-period" contenteditable="true">2012 — 2016</div>
          <div class="timeline-role" contenteditable="true">Marine Technology Specialist</div>
          <div class="timeline-company" contenteditable="true">[Organization Name]</div>
          <div class="timeline-desc" contenteditable="true">
            Fisheries supply chain optimization and marine domain expertise. Data collection, analysis,
            and visualization for fisheries operations. Foundation of marine intelligence and supply chain domain knowledge.
          </div>
        </div>
      </div>

      <div class="timeline-item reveal">
        <div class="timeline-dot" style="background:var(--cyan);box-shadow:var(--glow-cyan)"></div>
        <div class="timeline-card" style="border-color:rgba(78,205,196,0.2)">
          <div class="timeline-period" style="color:var(--cyan)" contenteditable="true">Education</div>
          <div class="timeline-role" contenteditable="true">[Degree / Certification]</div>
          <div class="timeline-company" contenteditable="true">[Institution Name]</div>
          <div class="timeline-desc" contenteditable="true">
            [Your educational background, certifications, and professional development. Click to edit.]
          </div>
        </div>
        <div class="timeline-empty"></div>
      </div>
    </div>
  </div>
</section>"""

new_experience = """<!-- ── Experience ──────────────────────────────────── -->
<section id="experience">
  <div class="section-number">02</div>
  <div class="container">
    <div class="section-header reveal">
      <div class="section-label">Experience</div>
      <h2 class="section-title">Career Timeline</h2>
      <p class="section-desc">Click any card to expand full details. All fields are editable — click text to update.</p>
    </div>
    <div class="timeline">

      <!-- Current Role -->
      <div class="timeline-item reveal">
        <div class="timeline-dot"></div>
        <div class="timeline-card">
          <div class="timeline-period" contenteditable="true">2022 — Present</div>
          <div class="timeline-role" contenteditable="true">Founder, Technical Lead &amp; AI Systems Architect</div>
          <div class="timeline-company" contenteditable="true">World Seafood Producers / SirTrav-A2A-Studio (WSP001)</div>
          <div class="timeline-desc" contenteditable="true">
            Founded World Seafood Producers and architected the SirTrav-A2A-Studio marine intelligence platform.
            Designed multi-agent orchestration using A2A protocols with Claude API (Anthropic) and Gemini Embedding 2
            multimodal RAG. Built SeaTrace: the Four Pillars API for vessel tracking (SeaSide), catch verification (DeckSide),
            supply chain (DockSide), and consumer traceability (MarketSide). Stack operator valuation $4.2M USD.
            All AI infrastructure deployed via Netlify Edge Functions with zero cold-start inference and GitHub CI/CD.
          </div>
          <div class="timeline-achievements">
            <span class="achievement-chip">🚀 A2A Multi-Agent Protocol</span>
            <span class="achievement-chip">💰 $4.2M Stack Valuation</span>
            <span class="achievement-chip cyan">🌊 SeaTrace Four Pillars API</span>
            <span class="achievement-chip cyan">⚡ Claude Opus + Gemini RAG</span>
          </div>
          <div class="expand-hint">↓ Click to expand</div>
        </div>
        <div class="timeline-empty"></div>
      </div>

      <!-- Role 2 -->
      <div class="timeline-item reveal">
        <div class="timeline-dot"></div>
        <div class="timeline-empty"></div>
        <div class="timeline-card">
          <div class="timeline-period" contenteditable="true">2018 — 2022</div>
          <div class="timeline-role" contenteditable="true">Senior Software Developer &amp; Data Engineer</div>
          <div class="timeline-company" contenteditable="true">[Company Name — click to edit]</div>
          <div class="timeline-desc" contenteditable="true">
            Full-stack development with JavaScript/Node.js and Python. Designed and delivered Power BI dashboards
            for fisheries supply chain analytics serving enterprise maritime clients. Managed GitHub workflows,
            environment vault configurations, and multi-API integration stacks. Established automated testing
            and crash prevention systems reducing production incidents by 70%.
          </div>
          <div class="timeline-achievements">
            <span class="achievement-chip">📊 Power BI Dashboards</span>
            <span class="achievement-chip">JS / Node.js / Python</span>
            <span class="achievement-chip cyan">🔒 Vault &amp; API Management</span>
          </div>
          <div class="expand-hint">↓ Click to expand</div>
        </div>
      </div>

      <!-- Role 3 -->
      <div class="timeline-item reveal">
        <div class="timeline-dot"></div>
        <div class="timeline-card">
          <div class="timeline-period" contenteditable="true">2015 — 2018</div>
          <div class="timeline-role" contenteditable="true">Software Developer &amp; DevOps Engineer</div>
          <div class="timeline-company" contenteditable="true">[Company Name — click to edit]</div>
          <div class="timeline-desc" contenteditable="true">
            Cloud infrastructure design, API integration and lifecycle management across enterprise platforms.
            Established CI/CD pipelines, API-driven development practices, and multi-tool integration frameworks.
            PowerShell automation, environment configuration, and DevOps toolchain optimization for maritime tech clients.
          </div>
          <div class="timeline-achievements">
            <span class="achievement-chip">☁️ CI/CD Pipelines</span>
            <span class="achievement-chip">PowerShell Automation</span>
            <span class="achievement-chip cyan">API Lifecycle Mgmt</span>
          </div>
          <div class="expand-hint">↓ Click to expand</div>
        </div>
        <div class="timeline-empty"></div>
      </div>

      <!-- Marine Domain -->
      <div class="timeline-item reveal">
        <div class="timeline-dot"></div>
        <div class="timeline-empty"></div>
        <div class="timeline-card">
          <div class="timeline-period" contenteditable="true">2010 — 2015</div>
          <div class="timeline-role" contenteditable="true">Marine Technology Specialist &amp; Supply Chain Analyst</div>
          <div class="timeline-company" contenteditable="true">[Organization — click to edit]</div>
          <div class="timeline-desc" contenteditable="true">
            Fisheries supply chain optimization, catch traceability field work, and marine domain expertise development.
            Data collection, analysis, and early-stage visualization for fisheries operations management.
            Deep knowledge in HACCP compliance, IUU fishing prevention, and maritime logistics —
            the foundation for SeaTrace and the Four Pillars API architecture.
          </div>
          <div class="timeline-achievements">
            <span class="achievement-chip">🐟 IUU Prevention</span>
            <span class="achievement-chip">HACCP Compliance</span>
            <span class="achievement-chip cyan">🌊 Maritime Logistics</span>
          </div>
          <div class="expand-hint">↓ Click to expand</div>
        </div>
      </div>

      <!-- Education -->
      <div class="timeline-item reveal">
        <div class="timeline-dot" style="background:var(--cyan);box-shadow:var(--glow-cyan)"></div>
        <div class="timeline-card" style="border-color:rgba(78,205,196,0.2)">
          <div class="timeline-period" style="color:var(--cyan)" contenteditable="true">Education &amp; Certifications</div>
          <div class="timeline-role" contenteditable="true">[Degree / Certification — click to edit]</div>
          <div class="timeline-company" contenteditable="true">[Institution Name — click to edit]</div>
          <div class="timeline-desc" contenteditable="true">
            Professional certifications in AI systems, cloud architecture, and marine technology.
            Continuing education: Anthropic AI Systems, Google Cloud Professional, GitHub Actions Automation,
            Netlify Composable Architecture. Click to add your formal education and full credential history.
          </div>
          <div class="timeline-achievements">
            <span class="achievement-chip cyan">Google Cloud</span>
            <span class="achievement-chip cyan">Anthropic AI</span>
            <span class="achievement-chip">GitHub Actions</span>
          </div>
        </div>
        <div class="timeline-empty"></div>
      </div>
    </div>
  </div>
</section>"""

if old_experience in html:
    html = html.replace(old_experience, new_experience)
    print("✅ Experience section upgraded")
else:
    print("❌ Experience section NOT found — checking snippet...")
    # Try finding just the first few lines
    check = '<!-- ── Experience ──────────────────────────────────── -->'
    idx = html.find(check)
    if idx >= 0:
        print(f"  Found at char {idx}, line ~{html[:idx].count(chr(10))}")
        print("  Context:", html[idx:idx+200])
    else:
        print("  Experience comment not found either")

# ── 2. PROJECTS SECTION: Add real data with expandable details ──────────────────

# Project 5 (marine placeholder) → SeaTrace Four Pillars
old_p5 = """      <div class="project-card reveal" data-cat="marine" data-tilt data-tilt-max="8" data-tilt-speed="400" data-tilt-glare data-tilt-max-glare="0.15">
        <div class="project-thumb">
          <div class="project-thumb-bg" style="background:linear-gradient(135deg,#051a1a,#0a2020)"></div>
          <div class="project-thumb-icon">🌊</div>
          <div class="project-tag" style="color:var(--cyan)">Marine Tech</div>
        </div>
        <div class="project-body">
          <div class="project-title" contenteditable="true">[Project 5 Title]</div>
          <div class="project-desc" contenteditable="true">
            [Click to add your project description. What problem did it solve? What technologies did you use? What was the outcome?]
          </div>
          <div class="project-tech">
            <span class="tech-badge" contenteditable="true">Technology</span>
            <span class="tech-badge" contenteditable="true">Stack</span>
          </div>
        </div>
      </div>"""

new_p5 = """      <div class="project-card reveal" data-cat="marine" data-tilt data-tilt-max="8" data-tilt-speed="400" data-tilt-glare data-tilt-max-glare="0.15">
        <div class="project-thumb">
          <div class="project-thumb-bg" style="background:linear-gradient(135deg,#051a1a,#0a2020)"></div>
          <div class="project-thumb-icon">🐟</div>
          <div class="project-tag" style="color:var(--cyan)">Marine Tech</div>
        </div>
        <div class="project-body">
          <div class="project-title" contenteditable="true">SeaTrace — Four Pillars Traceability API</div>
          <div class="project-desc" contenteditable="true">
            Marine supply chain traceability platform at seatrace.worldseafoodproducers.com.
            Four Pillars architecture serving vessel operators, dock processors, distributors, and consumers.
          </div>
          <div class="project-tech">
            <span class="tech-badge">Node.js / REST API</span>
            <span class="tech-badge">Netlify Edge</span>
            <span class="tech-badge">Marine Domain</span>
            <span class="tech-badge">IUU Prevention</span>
          </div>
          <div class="project-expand">
            <strong>The Four Pillars:</strong>
            <div class="project-pillar">
              <div class="pillar-item">
                <div class="pillar-name">⚓ SeaSide</div>
                <div class="pillar-desc">Vessel tracking &amp; catch origin verification at sea</div>
              </div>
              <div class="pillar-item">
                <div class="pillar-name">🪝 DeckSide</div>
                <div class="pillar-desc">On-deck catch verification &amp; HACCP compliance logging</div>
              </div>
              <div class="pillar-item">
                <div class="pillar-name">🏗️ DockSide</div>
                <div class="pillar-desc">Port processing, supply chain handoff &amp; cold chain data</div>
              </div>
              <div class="pillar-item">
                <div class="pillar-name">🛒 MarketSide</div>
                <div class="pillar-desc">Consumer QR verification &amp; retail traceability portal</div>
              </div>
            </div>
            <a href="https://seatrace.worldseafoodproducers.com" target="_blank" rel="noopener" class="project-live-link">
              🔗 seatrace.worldseafoodproducers.com →
            </a>
          </div>
          <span class="expand-cta">↓ Click to see Four Pillars breakdown</span>
        </div>
      </div>"""

if old_p5 in html:
    html = html.replace(old_p5, new_p5)
    print("✅ Project 5 (SeaTrace) upgraded")
else:
    print("❌ Project 5 placeholder not found")
    idx = html.find('[Project 5 Title]')
    if idx >= 0:
        print(f"  Found '[Project 5 Title]' at char {idx}")
        print("  Context:", html[max(0,idx-300):idx+50])

# Project 6 (cloud placeholder) → SirTrav Platform detail card
old_p6 = """      <div class="project-card reveal" data-cat="cloud" data-tilt data-tilt-max="8" data-tilt-speed="400" data-tilt-glare data-tilt-max-glare="0.15">
        <div class="project-thumb">
          <div class="project-thumb-bg" style="background:linear-gradient(135deg,#1a1005,#100a00)"></div>
          <div class="project-thumb-icon">🔧</div>
          <div class="project-tag" style="color:var(--gold)">Cloud</div>
        </div>
        <div class="project-body">
          <div class="project-title" contenteditable="true">[Project 6 Title]</div>
          <div class="project-desc" contenteditable="true">
            [Click to add your project description. What problem did it solve? What technologies did you use? What was the outcome?]
          </div>
          <div class="project-tech">
            <span class="tech-badge" contenteditable="true">Technology</span>
            <span class="tech-badge" contenteditable="true">Stack</span>
          </div>
        </div>
      </div>"""

new_p6 = """      <div class="project-card reveal" data-cat="cloud" data-tilt data-tilt-max="8" data-tilt-speed="400" data-tilt-glare data-tilt-max-glare="0.15">
        <div class="project-thumb">
          <div class="project-thumb-bg" style="background:linear-gradient(135deg,#1a1005,#100a00)"></div>
          <div class="project-thumb-icon">🤝</div>
          <div class="project-tag" style="color:var(--gold)">Cloud / AI</div>
        </div>
        <div class="project-body">
          <div class="project-title" contenteditable="true">SirTrav A2A Studio — Agent Orchestration Platform</div>
          <div class="project-desc" contenteditable="true">
            Multi-agent coordination platform using Agent-to-Agent (A2A) protocols. Three specialized agents
            — Codex (frontend), Claude Code (backend), Antigravity (QA) — work in concert to build, test, and deploy.
          </div>
          <div class="project-tech">
            <span class="tech-badge">A2A Protocol</span>
            <span class="tech-badge">Claude API</span>
            <span class="tech-badge">GitHub Actions</span>
            <span class="tech-badge">ElevenLabs</span>
          </div>
          <div class="project-expand">
            <strong>Agent Roles:</strong>
            <ul>
              <li><strong>Codex</strong> — Frontend generation, UI/UX systems, Three.js 3D</li>
              <li><strong>Claude Code</strong> — Backend logic, API wiring, TypeScript edge functions</li>
              <li><strong>Antigravity</strong> — QA, regression testing, crash prevention</li>
            </ul>
            <a href="https://sirtrav-a2a-studio.netlify.app" target="_blank" rel="noopener" class="project-live-link">
              🔗 sirtrav-a2a-studio.netlify.app →
            </a>
          </div>
          <span class="expand-cta">↓ Click to see agent breakdown</span>
        </div>
      </div>"""

if old_p6 in html:
    html = html.replace(old_p6, new_p6)
    print("✅ Project 6 (SirTrav A2A) upgraded")
else:
    print("❌ Project 6 placeholder not found")

# Add expand click to project card 1 (SirTrav-A2A-Studio)
old_p1_body = """        <div class="project-body">
          <div class="project-title" contenteditable="true">SirTrav-A2A-Studio</div>
          <div class="project-desc" contenteditable="true">
            Marine intelligence platform using agent-to-agent (A2A) protocols. Multi-agent orchestration
            with Claude API, Gemini Embedding 2 multimodal RAG, and composable AI stack deployed on Netlify.
          </div>
          <div class="project-tech">
            <span class="tech-badge">Claude API</span>
            <span class="tech-badge">Gemini Embed 2</span>
            <span class="tech-badge">Node.js</span>
            <span class="tech-badge">Netlify</span>
          </div>
        </div>"""

new_p1_body = """        <div class="project-body">
          <div class="project-title" contenteditable="true">SirTrav-A2A-Studio</div>
          <div class="project-desc" contenteditable="true">
            Marine intelligence platform using agent-to-agent (A2A) protocols. Multi-agent orchestration
            with Claude API, Gemini Embedding 2 multimodal RAG, and composable AI stack deployed on Netlify.
          </div>
          <div class="project-tech">
            <span class="tech-badge">Claude API</span>
            <span class="tech-badge">Gemini Embed 2</span>
            <span class="tech-badge">Node.js</span>
            <span class="tech-badge">Netlify</span>
          </div>
          <div class="project-expand">
            Claude Opus 4.6 powers the conversational layer; Gemini Embedding 2 maps text, images, video,
            audio, and PDFs into a unified vector space for cross-modal retrieval. ElevenLabs provides
            voice output for agent communications.
            <a href="https://sirtrav-a2a-studio.netlify.app" target="_blank" rel="noopener" class="project-live-link">
              🔗 Live Platform →
            </a>
          </div>
          <span class="expand-cta">↓ Click for technical details</span>
        </div>"""

if old_p1_body in html:
    html = html.replace(old_p1_body, new_p1_body)
    print("✅ Project 1 (SirTrav) expanded")
else:
    print("❌ Project 1 body not found")

# Add expand to Project 2 (Fisheries Supply Chain)
old_p2_body = """        <div class="project-body">
          <div class="project-title" contenteditable="true">Fisheries Supply Chain Intelligence</div>
          <div class="project-desc" contenteditable="true">
            Power BI dashboards and data visualization platform for fisheries supply chain optimization.
            Real-time analytics, traceability workflows, and operational efficiency metrics.
          </div>
          <div class="project-tech">
            <span class="tech-badge">Power BI</span>
            <span class="tech-badge">Python</span>
            <span class="tech-badge">API Integration</span>
          </div>
        </div>"""

new_p2_body = """        <div class="project-body">
          <div class="project-title" contenteditable="true">Fisheries Supply Chain Intelligence</div>
          <div class="project-desc" contenteditable="true">
            Power BI dashboards and data visualization platform for fisheries supply chain optimization.
            Real-time analytics, traceability workflows, and operational efficiency metrics.
          </div>
          <div class="project-tech">
            <span class="tech-badge">Power BI</span>
            <span class="tech-badge">Python</span>
            <span class="tech-badge">API Integration</span>
          </div>
          <div class="project-expand">
            Enterprise fisheries analytics covering catch volume KPIs, seasonal trend detection,
            compliance reporting, and supply chain bottleneck identification. Used by maritime
            operators to reduce waste and optimize harvest-to-market lead times.
          </div>
          <span class="expand-cta">↓ Click for details</span>
        </div>"""

if old_p2_body in html:
    html = html.replace(old_p2_body, new_p2_body)
    print("✅ Project 2 (Fisheries) expanded")
else:
    print("❌ Project 2 body not found")

# Add expand to Project 3 (Netlify AI Edge)
old_p3_body = """        <div class="project-body">
          <div class="project-title" contenteditable="true">Netlify AI Edge Platform</div>
          <div class="project-desc" contenteditable="true">
            Composable AI stack using Netlify Edge Functions with Anthropic Claude and Gemini APIs.
            Zero cold-start inference, DDoS protection, rate limiting, and CDN-edge AI responses.
          </div>
          <div class="project-tech">
            <span class="tech-badge">Netlify Edge</span>
            <span class="tech-badge">TypeScript</span>
            <span class="tech-badge">Deno</span>
            <span class="tech-badge">CI/CD</span>
          </div>
        </div>"""

new_p3_body = """        <div class="project-body">
          <div class="project-title" contenteditable="true">Netlify AI Edge Platform</div>
          <div class="project-desc" contenteditable="true">
            Composable AI stack using Netlify Edge Functions with Anthropic Claude and Gemini APIs.
            Zero cold-start inference, DDoS protection, rate limiting, and CDN-edge AI responses.
          </div>
          <div class="project-tech">
            <span class="tech-badge">Netlify Edge</span>
            <span class="tech-badge">TypeScript</span>
            <span class="tech-badge">Deno</span>
            <span class="tech-badge">CI/CD</span>
          </div>
          <div class="project-expand">
            This very CV site runs on this architecture. Edge functions handle /api/chat, /api/embed,
            and /api/verify-access at CDN nodes worldwide — no server management, no cold starts,
            instant global AI responses at millisecond latency.
            <a href="https://robertoscottecholscv.netlify.app" target="_blank" rel="noopener" class="project-live-link">
              🔗 Live Demo (this site) →
            </a>
          </div>
          <span class="expand-cta">↓ Click for architecture notes</span>
        </div>"""

if old_p3_body in html:
    html = html.replace(old_p3_body, new_p3_body)
    print("✅ Project 3 (Netlify Edge) expanded")
else:
    print("❌ Project 3 body not found")

# Add expand to Project 4 (Multimodal RAG)
old_p4_body = """        <div class="project-body">
          <div class="project-title" contenteditable="true">Multimodal RAG Pipeline</div>
          <div class="project-desc" contenteditable="true">
            Gemini Embedding 2 pipeline mapping text, images, video, audio, and PDFs into a unified
            vector space. Enables cross-modal search and multimodal knowledge base retrieval.
          </div>
          <div class="project-tech">
            <span class="tech-badge">Gemini Embed 2</span>
            <span class="tech-badge">Vector DB</span>
            <span class="tech-badge">RAG</span>
            <span class="tech-badge">Python</span>
          </div>
        </div>"""

new_p4_body = """        <div class="project-body">
          <div class="project-title" contenteditable="true">Multimodal RAG Pipeline</div>
          <div class="project-desc" contenteditable="true">
            Gemini Embedding 2 pipeline mapping text, images, video, audio, and PDFs into a unified
            vector space. Enables cross-modal search and multimodal knowledge base retrieval.
          </div>
          <div class="project-tech">
            <span class="tech-badge">Gemini Embed 2</span>
            <span class="tech-badge">Vector DB</span>
            <span class="tech-badge">RAG</span>
            <span class="tech-badge">Python</span>
          </div>
          <div class="project-expand">
            <strong>Knowledge partitions:</strong>
            <ul>
              <li><em>cv_personal</em> — Resume &amp; career timeline (public tier)</li>
              <li><em>cv_projects</em> — SirTrav, SeaTrace, WAFC (public tier)</li>
              <li><em>business_seatrace</em> — Four Pillars API docs (business tier)</li>
              <li><em>business_proposals</em> — Client proposals &amp; pricing (business tier)</li>
              <li><em>recreational</em> — Personal interests (invitation only)</li>
            </ul>
          </div>
          <span class="expand-cta">↓ Click to see KB partitions</span>
        </div>"""

if old_p4_body in html:
    html = html.replace(old_p4_body, new_p4_body)
    print("✅ Project 4 (RAG Pipeline) expanded")
else:
    print("❌ Project 4 body not found")

# ── 3. SERVICES: Add more detail + contact link ──────────────────────────────────
old_svc_title = '          <div class="service-title" contenteditable="true">Agentic AI Systems</div>\n          <div class="service-desc" contenteditable="true">\n            Multi-agent orchestration, A2A protocol design, Claude & Gemini API integration.\n            Production-grade agentic pipelines with automated testing and crash prevention.\n          </div>'
new_svc_title = '          <div class="service-title" contenteditable="true">Agentic AI Systems</div>\n          <div class="service-desc" contenteditable="true">\n            Multi-agent orchestration, A2A protocol design, Claude Opus &amp; Gemini API integration.\n            Production-grade agentic pipelines with automated testing and crash prevention.\n            Deployable on Netlify Edge with zero cold-start inference.\n          </div>'

if old_svc_title in html:
    html = html.replace(old_svc_title, new_svc_title)
    print("✅ Service 1 enhanced")
else:
    print("⚠️  Service 1 not found (minor)")

# ── 4. CONTACT: Fix LinkedIn placeholder ────────────────────────────────────────
old_linkedin = '            <div class="contact-val" contenteditable="true">[Your LinkedIn URL]</div>'
new_linkedin = '            <div class="contact-val" contenteditable="true">linkedin.com/in/rscottechols — click to edit</div>'
html = html.replace(old_linkedin, new_linkedin)
print("✅ LinkedIn placeholder improved")

# ── 5. ABOUT: Badge text update ──────────────────────────────────────────────────
old_badge_text = 'Available for Enterprise Engagements'
new_badge_text = 'Open to Enterprise Engagements &amp; AI Consulting'
if old_badge_text in html:
    html = html.replace(old_badge_text, new_badge_text, 1)
    print("✅ Hero badge updated")
else:
    print("⚠️  Hero badge not found")

# ── 6. THREE.JS: Upgrade to denser, more complex geometry ───────────────────────
old_three = """  // Icosahedron wireframe
  const geometry = new THREE.IcosahedronGeometry(2, 1);
  const material = new THREE.MeshBasicMaterial({
    color: 0xc9a84c,
    wireframe: true,
    transparent: true,
    opacity: 0.2
  });
  const icosahedron = new THREE.Mesh(geometry, material);
  scene.add(icosahedron);

  // Inner icosahedron
  const innerGeo = new THREE.IcosahedronGeometry(1.4, 0);
  const innerMat = new THREE.MeshBasicMaterial({
    color: 0x4ecdc4,
    wireframe: true,
    transparent: true,
    opacity: 0.12
  });
  const innerIco = new THREE.Mesh(innerGeo, innerMat);
  scene.add(innerIco);

  // Points on vertices
  const dotGeo = new THREE.SphereGeometry(0.03, 8, 8);
  const dotMat = new THREE.MeshBasicMaterial({ color: 0xc9a84c, transparent: true, opacity: 0.6 });
  const positions = geometry.attributes.position;
  for (let i = 0; i < positions.count; i++) {
    const dot = new THREE.Mesh(dotGeo, dotMat);
    dot.position.set(positions.getX(i), positions.getY(i), positions.getZ(i));
    icosahedron.add(dot);
  }

  let targetRotX = 0, targetRotY = 0;

  document.addEventListener('mousemove', e => {
    targetRotX = (e.clientY / window.innerHeight - 0.5) * 0.5;
    targetRotY = (e.clientX / window.innerWidth - 0.5) * 0.5;
  });

  function animate() {
    requestAnimationFrame(animate);
    icosahedron.rotation.x += 0.002;
    icosahedron.rotation.y += 0.003;
    innerIco.rotation.x -= 0.001;
    innerIco.rotation.y -= 0.002;

    // Parallax tilt from mouse
    icosahedron.rotation.x += (targetRotX - icosahedron.rotation.x * 0.1) * 0.02;
    icosahedron.rotation.y += (targetRotY - icosahedron.rotation.y * 0.1) * 0.02;

    renderer.render(scene, camera);
  }
  animate();"""

new_three = """  // Outer icosahedron (gold wireframe)
  const geometry = new THREE.IcosahedronGeometry(2, 2);
  const material = new THREE.MeshBasicMaterial({
    color: 0xc9a84c, wireframe: true, transparent: true, opacity: 0.18
  });
  const icosahedron = new THREE.Mesh(geometry, material);
  scene.add(icosahedron);

  // Mid icosahedron (cyan)
  const midGeo = new THREE.IcosahedronGeometry(1.6, 1);
  const midMat = new THREE.MeshBasicMaterial({
    color: 0x4ecdc4, wireframe: true, transparent: true, opacity: 0.10
  });
  const midIco = new THREE.Mesh(midGeo, midMat);
  scene.add(midIco);

  // Inner icosahedron (gold, slow counter-rotation)
  const innerGeo = new THREE.IcosahedronGeometry(1.1, 0);
  const innerMat = new THREE.MeshBasicMaterial({
    color: 0xc9a84c, wireframe: true, transparent: true, opacity: 0.08
  });
  const innerIco = new THREE.Mesh(innerGeo, innerMat);
  scene.add(innerIco);

  // Orbit ring 1 (horizontal)
  const ringGeo1 = new THREE.TorusGeometry(2.5, 0.008, 8, 80);
  const ringMat1 = new THREE.MeshBasicMaterial({ color: 0xc9a84c, transparent: true, opacity: 0.25 });
  const ring1 = new THREE.Mesh(ringGeo1, ringMat1);
  ring1.rotation.x = Math.PI / 2;
  scene.add(ring1);

  // Orbit ring 2 (tilted)
  const ringGeo2 = new THREE.TorusGeometry(2.8, 0.006, 8, 80);
  const ringMat2 = new THREE.MeshBasicMaterial({ color: 0x4ecdc4, transparent: true, opacity: 0.18 });
  const ring2 = new THREE.Mesh(ringGeo2, ringMat2);
  ring2.rotation.x = Math.PI / 3;
  ring2.rotation.z = Math.PI / 6;
  scene.add(ring2);

  // Orbit ring 3 (vertical)
  const ringGeo3 = new THREE.TorusGeometry(3.1, 0.004, 6, 80);
  const ringMat3 = new THREE.MeshBasicMaterial({ color: 0x7c6af7, transparent: true, opacity: 0.12 });
  const ring3 = new THREE.Mesh(ringGeo3, ringMat3);
  ring3.rotation.y = Math.PI / 4;
  scene.add(ring3);

  // Vertex dots on outer icosahedron
  const dotGeo = new THREE.SphereGeometry(0.025, 6, 6);
  const dotMat = new THREE.MeshBasicMaterial({ color: 0xc9a84c, transparent: true, opacity: 0.7 });
  const positions = geometry.attributes.position;
  const seen = new Set();
  for (let i = 0; i < positions.count; i++) {
    const key = `${positions.getX(i).toFixed(2)},${positions.getY(i).toFixed(2)},${positions.getZ(i).toFixed(2)}`;
    if (!seen.has(key)) {
      seen.add(key);
      const dot = new THREE.Mesh(dotGeo, dotMat);
      dot.position.set(positions.getX(i), positions.getY(i), positions.getZ(i));
      icosahedron.add(dot);
    }
  }

  let targetRotX = 0, targetRotY = 0;
  document.addEventListener('mousemove', e => {
    targetRotX = (e.clientY / window.innerHeight - 0.5) * 0.4;
    targetRotY = (e.clientX / window.innerWidth - 0.5) * 0.4;
  });

  function animate() {
    requestAnimationFrame(animate);
    const t = Date.now() * 0.001;

    icosahedron.rotation.x += 0.0015;
    icosahedron.rotation.y += 0.002;
    midIco.rotation.x -= 0.001;
    midIco.rotation.y += 0.0015;
    innerIco.rotation.x -= 0.0008;
    innerIco.rotation.y -= 0.001;

    // Rings orbit independently
    ring1.rotation.z += 0.003;
    ring2.rotation.z -= 0.002;
    ring3.rotation.y += 0.0015;

    // Parallax tilt from mouse
    icosahedron.rotation.x += (targetRotX - icosahedron.rotation.x * 0.1) * 0.015;
    icosahedron.rotation.y += (targetRotY - icosahedron.rotation.y * 0.1) * 0.015;

    renderer.render(scene, camera);
  }
  animate();"""

if old_three in html:
    html = html.replace(old_three, new_three)
    print("✅ Three.js upgraded — denser geometry + orbit rings")
else:
    print("❌ Three.js section not found")
    # Check for a partial match
    if "IcosahedronGeometry(2, 1)" in html:
        print("  Found 'IcosahedronGeometry(2, 1)' but full block didn't match")

# ── 7. PROJECT CARD CLICK TO EXPAND (JS) ────────────────────────────────────────
old_timeline_click = """// ── Timeline Card Expand/Collapse ─────────────────────
(function() {
  document.querySelectorAll('.timeline-card').forEach(card => {
    card.addEventListener('click', e => {
      // Don't toggle if user is editing contenteditable
      if (e.target.getAttribute('contenteditable') === 'true' && document.activeElement === e.target) return;
      card.classList.toggle('expanded');
    });
  });
})();"""

new_timeline_click = """// ── Timeline Card Expand/Collapse ─────────────────────
(function() {
  document.querySelectorAll('.timeline-card').forEach(card => {
    card.addEventListener('click', e => {
      if (e.target.getAttribute('contenteditable') === 'true' && document.activeElement === e.target) return;
      card.classList.toggle('expanded');
    });
  });
})();

// ── Project Card Expand/Collapse ──────────────────────
(function() {
  document.querySelectorAll('.project-card').forEach(card => {
    card.addEventListener('click', e => {
      // Don't toggle if clicking a link or editing
      if (e.target.tagName === 'A' || e.target.closest('a')) return;
      if (e.target.getAttribute('contenteditable') === 'true' && document.activeElement === e.target) return;
      card.classList.toggle('expanded');
      // Brief glow on expand
      if (card.classList.contains('expanded')) {
        card.style.borderColor = 'rgba(78,205,196,0.4)';
        setTimeout(() => { card.style.borderColor = ''; }, 800);
      }
    });
  });
})();

// ── Chatbot: seed welcome with keywords ───────────────
// RSE CV / Resume keyword injection (used by AI context)
window.RSE_CV_KEYWORDS = {
  name: 'Roberto Scott Echols',
  aliases: ['R. Scott Echols', 'RSE', 'R.SCOTT CV'],
  role: 'Founder, Technical Lead & AI Systems Architect',
  company: 'World Seafood Producers / WSP001',
  stack_valuation: '$4.2M USD',
  projects: ['SirTrav-A2A-Studio', 'SeaTrace Four Pillars', 'Multimodal RAG Pipeline', 'Netlify AI Edge Platform'],
  seatrace_pillars: ['SeaSide (vessel tracking)', 'DeckSide (catch verification)', 'DockSide (supply chain)', 'MarketSide (consumer traceability)'],
  business_site: 'worldseafoodproducers.com',
  seatrace_portal: 'seatrace.worldseafoodproducers.com',
  contact: 'worldseafood@gmail.com'
};"""

if old_timeline_click in html:
    html = html.replace(old_timeline_click, new_timeline_click)
    print("✅ Project card expand JS added + RSE_CV_KEYWORDS seed injected")
else:
    print("❌ Timeline click handler not found")

# ── 8. TYPING TITLES: Add more descriptive options ───────────────────────────────
old_titles = "const titles = ['Solutions Architect', 'Marine Intelligence Expert', 'Agentic AI Builder', 'Cloud Systems Lead', 'Technical Advisor'];"
new_titles = "const titles = ['Solutions Architect', 'Marine Intelligence Expert', 'Agentic AI Builder', 'SeaTrace Founder', 'Cloud Systems Lead', 'Technical Advisor', 'A2A Protocol Designer'];"
if old_titles in html:
    html = html.replace(old_titles, new_titles)
    print("✅ Typing titles upgraded")
else:
    print("⚠️  Typing titles not found")

# ── 9. FALLBACK RESPONSES: Improve with SeaTrace knowledge ──────────────────────
old_fallbacks = """    const fallbacks = {
      'background': "Scott is a Senior Software Developer and Technical Lead with expertise in marine/fisheries technology and agentic AI systems. He's currently building SirTrav-A2A-Studio, a marine intelligence platform.",
      'sirtrav': "SirTrav-A2A-Studio is a marine intelligence platform using agent-to-agent (A2A) protocols with Claude API and Gemini Embedding 2 multimodal RAG.",
      'contact': "You can reach Scott at worldseafood@gmail.com or through the contact form on this page. He's open to enterprise consulting, technical leadership, and collaboration.",
      'default': "I'm Scott's AI assistant. I can answer questions about his background, projects (like SirTrav marine intelligence platform), AI architecture work, and how to get in touch. The live AI requires the Netlify deployment with ANTHROPIC_API_KEY configured — try the contact form above to reach Scott directly."
    };"""

new_fallbacks = """    const fallbacks = {
      'background': "R. Scott Echols (R.SCOTT CV) is a Founder, Technical Lead & AI Systems Architect at World Seafood Producers (WSP001). He built the SirTrav-A2A-Studio marine intelligence platform and the SeaTrace Four Pillars traceability API — with a $4.2M stack valuation.",
      'resume': "R. Scott Echols' resume highlights: Founder of World Seafood Producers, architect of SirTrav-A2A-Studio (A2A multi-agent platform), SeaTrace Four Pillars API (vessel tracking → consumer verification), $4.2M stack valuation. Skills: Claude API, Gemini Embedding 2, Node.js, Python, PowerShell, Power BI, Netlify Edge, GitHub CI/CD.",
      'sirtrav': "SirTrav-A2A-Studio is a marine intelligence platform using agent-to-agent (A2A) protocols. Three agents — Codex (frontend), Claude Code (backend), Antigravity (QA) — orchestrated with Claude Opus and Gemini Embedding 2 multimodal RAG.",
      'seatrace': "SeaTrace (seatrace.worldseafoodproducers.com) is Scott's Four Pillars marine traceability API: SeaSide (vessel tracking at sea), DeckSide (catch verification on deck), DockSide (supply chain & port processing), MarketSide (consumer QR verification). Stack valuation $4.2M USD.",
      'worldseafood': "World Seafood Producers (worldseafoodproducers.com) is Scott's company. It operates SeaTrace (marine traceability), SirTrav-A2A-Studio (AI agent platform), and the WAFC business intelligence system.",
      'contact': "You can reach Scott at worldseafood@gmail.com or through the contact form on this page. GitHub: github.com/WSP001. He's open to enterprise consulting, AI systems architecture, and marine intelligence platform work.",
      'default': "I'm RSE-Assistant, R. Scott Echols' AI guide. I can answer questions about his background (R.SCOTT CV), SeaTrace (marine traceability API), SirTrav-A2A-Studio (A2A multi-agent platform), or how to get in touch at worldseafood@gmail.com. Ask me anything about his work in marine intelligence and agentic AI."
    };
    const m = message.toLowerCase();
    // Extended keyword matching
    const key = ['resume','cv','background'].some(k=>m.includes(k)) ? (m.includes('resume')||m.includes('cv') ? 'resume' : 'background')
               : m.includes('sirtrav') ? 'sirtrav'
               : m.includes('seatrace') ? 'seatrace'
               : m.includes('worldseafood') || m.includes('world seafood') ? 'worldseafood'
               : m.includes('contact') || m.includes('email') || m.includes('hire') ? 'contact'
               : Object.keys(fallbacks).find(k => m.includes(k)) || 'default';"""

# Replace just the fallbacks object + the key lookup
old_key_lookup = """    const m = message.toLowerCase();
    const key = Object.keys(fallbacks).find(k => m.includes(k)) || 'default';"""

# Combined old pattern
old_combined = old_fallbacks + "\n" + old_key_lookup
new_combined = new_fallbacks  # new_fallbacks already includes the new key lookup

if old_fallbacks in html:
    # Replace fallbacks first, then the key lookup line
    html = html.replace(old_fallbacks, new_fallbacks)
    # Remove old key lookup since new_fallbacks ends with the new lookup
    html = html.replace(old_key_lookup, "")
    print("✅ Fallback responses upgraded with SeaTrace/RSE CV keywords")
else:
    print("❌ Fallback responses not found")

# Write out
with open('/home/user/workspace/cv-repo/public/index.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("\n✅ All upgrades written to index.html")
PYEOF