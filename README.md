# FreeSWITCH Call Center Base Image

A high-performance, lightweight, multi-architecture (**linux/amd64** + **linux/arm64**) Docker base image for **FreeSWITCH 1.10**, custom-tailored specifically for **Call Center** and inbound queue applications.

This repository serves as a robust alternative to upstream FreeSWITCH Docker images, delivering a curated set of pre-compiled modules (including `mod_callcenter`, `mod_fifo`, `mod_conference`, `mod_shout`, and `mod_http_cache`) to build modern, scalable contact centers without the overhead of compiling from source.

---

## Why Choose This Image?

*   **Designed for Call Centers:** Includes core queue-management engines like `mod_callcenter` (skill-based routing, agent tier scheduling) and `mod_fifo` out-of-the-box.
*   **Media & MOH Ready:** Includes `mod_shout` for MP3 music on hold (MOH) playback and `mod_http_cache` for caching voice prompts, greetings, and MOH assets from remote HTTP servers (e.g. S3 buckets) for zero-latency execution.
*   **Supervisor Capabilities:** Ships with `mod_conference` to enable real-time call monitoring, whispering, and agent coaching/barge-in features.
*   **Multi-Architecture Support:** Built for both `linux/amd64` (production environments) and `linux/arm64` (native execution on Apple Silicon Macs for local development).
*   **Official Stable Packages:** Built on top of official SignalWire Debian packages (FreeSWITCH 1.10 Stable) on `debian:bookworm-slim`.
*   **Secure Credentials:** SignalWire personal access tokens are handled securely using BuildKit secrets and are never baked into the final image layers.

---

## Published Image

The base image is built and published automatically to the GitHub Container Registry:

```bash
ghcr.io/snapwre/freeswitch-call-center:latest
```

---

## Curated Module Set for Call Center

Below is the list of FreeSWITCH modules pre-packaged in this image:

| Category | Module | Description |
| :--- | :--- | :--- |
| **Queue & Routing** | `mod_callcenter` | ACD (Automated Call Distribution) engine managing queues, agents, and routing strategies. |
| | `mod_fifo` | Standard First-In-First-Out queue engine for simpler call-distribution schemas. |
| | `mod_valet_parking` | Call parking lot manager allowing agents to park and retrieve active calls. |
| **Supervisor & Live** | `mod_conference` | Conferencing engine used for silent monitoring, coaching (whispering), and call barge-in. |
| **Core Engine** | `mod_commands` | Core API command interface. |
| | `mod_dptools` | Essential dialplan tools and applications. |
| | `mod_dialplan_xml` | XML dialplan support. |
| | `mod_expr` | Mathematical and logical expression evaluation. |
| **Protocols & Interface**| `mod_sofia` | SIP engine for trunking and registrations. |
| | `mod_event_socket` | Event Socket Library (ESL) interface for external control and dashboards. |
| **Media & Audio** | `mod_sndfile` | High-quality audio playback and recording backend. |
| | `mod_native_file` | Direct native audio format playback. |
| | `mod_tone_stream` | Multi-frequency tone generation (DTMF, ringback, custom cadences). |
| | `mod_shout` | MP3 streaming and local MP3 playback (critical for custom Music on Hold). |
| | `mod_http_cache` | HTTP/HTTPS caching client to download and store audio files on demand. |
| **IVR & Scripting** | `mod_lua` | In-process Lua scripting for ultra-low latency call flows. |
| **Web Integration** | `mod_curl` | HTTP client capabilities directly from the dialplan or Lua scripts. |
| | `mod_httapi` | HTML-like RESTful IVR engine via HTTP/HTTPS. |
| **Accounting & Logging**| `mod_xml_cdr` | Detailed Call Detail Records (CDRs) sent as XML to web endpoints. |
| | `mod_json_cdr` | Detailed Call Detail Records (CDRs) sent as JSON to HTTP web endpoints. |
| | `mod_console` | Console logger. |
| | `mod_logfile` | Output logs to disk. |
| **Utilities & Codecs** | `mod_hash` | High-performance in-memory key-value lookup tables. |
| | `mod_db` | Database integration for basic limits and state management. |
| | `mod_cidlookup` | Dynamic caller ID lookup via HTTP, DB, or local lists. |
| | `mod_spandsp` | DSP services, tone detection, and fax support. |
| | `mod_say_en` | English speech formatting helper (numbers, times, dates). |
| | `mod_amr` | Adaptive Multi-Rate (AMR) audio codec support. |
| **System Precision** | `mod_timerfd` | Kernel-level high-precision timer (crucial for smooth queue hold audio). |

---

## How to Use It

This image is designed as a **base image**. You should consume it in your downstream projects by referencing it in your `Dockerfile` and copying your custom configuration files into it.

### 1. Structure of a Downstream Project
Create a folder structure for your call center project:
```text
my-callcenter-app/
├── Dockerfile
└── conf/
    ├── freeswitch.xml
    ├── vars.xml
    ├── autoload_configs/
    │   ├── modules.conf.xml
    │   ├── callcenter.conf.xml
    │   ├── http_cache.conf.xml
    │   ├── sofia.conf.xml
    │   └── ...
    └── dialplan/
        └── default.xml
```

### 2. Downstream Dockerfile Example
Write your downstream `Dockerfile` using `ghcr.io/snapwre/freeswitch-call-center` as the parent image:

```dockerfile
FROM ghcr.io/snapwre/freeswitch-call-center:latest

# Copy your custom configurations into FreeSWITCH configuration directory
COPY conf/ /etc/freeswitch/

# Ensure appropriate directories and permissions are set if needed
RUN mkdir -p /var/log/freeswitch /var/run/freeswitch /var/cache/freeswitch/http_cache \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/log/freeswitch /var/run/freeswitch /var/cache/freeswitch

# Default ports are already exposed:
# 5060/udp (SIP), 5080/udp (SIP alternative/carrier), 8021/tcp (ESL)
```

> [!IMPORTANT]
> The modules enabled in your downstream `autoload_configs/modules.conf.xml` must match the pre-compiled modules listed in this base image. If you try to load a module that isn't pre-packaged, FreeSWITCH will fail to start.

### 3. Example `callcenter.conf.xml` Queue & Agent Setup
Below is a basic queue and agent configuration example:

```xml
<configuration name="callcenter.conf" description="CallCenter">
  <settings>
    <!-- Keep agent state across restarts if needed -->
    <!-- <param name="odbc-dsn" value="dsn:user:pass"/> -->
  </settings>

  <queues>
    <queue name="sales@default">
      <param name="strategy" value="longest-idle-agent"/>
      <param name="moh-sound" value="local_stream://default"/>
      <param name="time-base-score" value="system"/>
      <param name="max-wait-time" value="0"/>
      <param name="max-wait-time-with-no-agent" value="30"/>
      <param name="max-wait-time-with-no-agent-time-reached" value="60"/>
      <param name="tier-rules-apply" value="false"/>
      <param name="tier-rule-wait-second" value="30"/>
      <param name="tier-rule-wait-multiply-level" value="true"/>
      <param name="tier-rule-no-agent-no-wait" value="false"/>
      <param name="discard-abandoned-after" value="60"/>
      <param name="abandoned-resume-allowed" value="false"/>
    </queue>
  </queues>

  <agents>
    <agent name="agent01" type="callback" contact="[leg_timeout=10]user/1000" status="Available" max-no-answer="3" wrap-up-time="10" reject-delay-time="10" busy-delay-time="60"/>
  </agents>

  <tiers>
    <tier agent="agent01" queue="sales@default" level="1" position="1"/>
  </tiers>
</configuration>
```

---

## Building Locally (Optional)

If you need to build this base image locally, you must provide your SignalWire Personal Access Token. This token is required because the FreeSWITCH 1.10 Debian repository is token-gated.

1. Generate a token at [SignalWire Dashboard](https://signalwire.com) -> **Personal Access Token**.
2. Run the build with BuildKit secrets:

```bash
export SIGNALWIRE_TOKEN=pat_your_signalwire_token_here

DOCKER_BUILDKIT=1 docker build \
  --secret id=signalwire_token,env=SIGNALWIRE_TOKEN \
  -t ghcr.io/snapwre/freeswitch-call-center:latest .
```

*The `--secret` flag ensures your token is mounted only during build execution and is not persisted in the final image layers.*

---

## Build & Publish via GitHub Actions

This repository includes a GitHub Action workflow to build and publish the image automatically:

1. **Configure Token:** Add your SignalWire Personal Access Token under **Settings → Secrets and variables → Actions** as `SIGNALWIRE_TOKEN`.
2. **Trigger the Workflow:**
   * Navigate to the **Actions** tab.
   * Select the **Build FreeSWITCH base image** workflow.
   * Click **Run workflow** (optionally supply a tag).
   * Note: The workflow is also triggered automatically on pushes to `main` and tag pushes matching `fs-v*`.
3. **Visibility:** When published to GHCR for the first time, go to the package page under your GitHub organization/account and update the package visibility to **Public** so downstream builds can pull it.
