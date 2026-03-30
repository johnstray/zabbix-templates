# Postfix SMTP Server (Zabbix Template)

## Introduction

This project provides a ready-to-use Zabbix template for monitoring a Postfix SMTP server.

This template is part of a collection of templates I am creating and adding to this repository and is based on the work by [Alexander Fox (PlaNet Fox)](https://github.com/linuser/Mailcow-Zabbix-Monitoring) and his templates for [Mailcow-Dockerized](https://mailcow.email). The aim of this project was to separate out monitoring sections for each software component for server administrators that are using the software, but in their own stack and not part of Mailcow (like me).

Tested with Zabbix 7.4 and Postfix 3.10.5 on Debian 13.

It is designed for `zabbix-agent2` and includes:

- A Zabbix template export: `postfix-smtp.yaml`
- Agent user parameters: `/etc/zabbix/zabbix_agent2.d/postfix-smtp.conf`
- A helper collection script: `/usr/local/bin/postfix_zabbix.sh`

With this template, you can monitor Postfix service health, queue behavior, SMTP reachability, TLS certificate status, mail flow counters, log anomaly counters, and postscreen activity.

## Installation

1. **Copy the helper script to the monitored host**
	- Source: `files/postfix_zabbix.sh`
	- Target: `/usr/local/bin/postfix_zabbix.sh`
	- Make it executable:
	  - `chmod +x /usr/local/bin/postfix_zabbix.sh`

2. **Copy the Zabbix agent config file**
	- Source: `files/postfix.conf`
	- Target: `/etc/zabbix/zabbix_agent2.d/postfix-smtp.conf`

3. **Ensure required binaries are available on the monitored host**
	- `postqueue`, `postconf`, `pflogsumm`, `ss`, `openssl`, `timeout`, `jq`, `bc`

4. **Ensure the server's FQDN Hostname is correctly set**
	- To set:
	  - `echo "server.example.com" > /etc/hostname` & `echo "server.example.com" > /etc/mailname`
	  - Modify `/etc/hosts` to include the following:
	    - `127.0.1.1 server.example.com server`
    - `hostname --fqdn` should then return the postfix server's correct hostname

5. **Restart the Zabbix agent**
	- Example:
	  - `systemctl restart zabbix-agent2`

6. **Import the template into Zabbix**
	- In Zabbix UI: **Data collection → Templates → Import**
	- Import file: `postfix-smtp.yaml`

7. **Link template to your Postfix host**
	- Link template **Postfix SMTP Server** to the target host.

## Monitored Metrics

The template monitors the following item keys from `postfix-smtp.yaml`:

### Service and availability

- `postfix.process.running` — Postfix master process running state
- `postfix.connections` — active SMTP connections
- `postfix.smtp.check` — SMTP port 25 reachability
- `postfix.submission.check` — submission port 587 reachability
- `postfix.submissions.check` — submissions port 465 reachability
- `postfix.version` — Postfix version

### Queue and storage

- `postfix.pfmailq` — mail queue size
- `postfix.queue.disk` — queue disk usage (%)

### TLS certificate monitoring

- `postfix.tls.cert.raw.465` — TLS certificate details (465)
- `postfix.tls.cert.days.465` — TLS certificate days remaining (465)
- `postfix.tls.cert.raw.587` — TLS certificate details (587)
- `postfix.tls.cert.days.587` — TLS certificate days remaining (587)

### Log and error counters

- `postfix.fetch_log_data` — raw/JSON log data item
- `postfix.log.errors` — log errors
- `postfix.log.warnings` — log warnings
- `postfix.log.sasl_auth_failed` — SASL authentication failures
- `postfix.log.relay_denied` — relay denials
- `postfix.log.spam_rejected` — spam rejections
- `postfix.log.rbl_reject` — RBL rejections
- `postfix.log.user_unknown` — unknown user logins
- `postfix.log.connection_timeout` — connection timeouts
- `postfix.log.tls_failed` — TLS failures
- `postfix.log.quota_exceeded` — quota exceeded events
- `postfix.log.virus_found` — virus detections

### Mail flow counters

- `postfix.emails.received` — received emails
- `postfix.emails.delivered` — delivered emails
- `postfix.emails.bounced` — bounced emails
- `postfix.emails.deferred` — deferred emails
- `postfix.emails.rejected` — rejected emails
- `postfix.emails.reject_warnings` — reject warnings
- `postfix.emails.discarded` — discarded emails
- `postfix.emails.held` — held emails
- `postfix.emails.forwarded` — forwarded emails
- `postfix.bytes_received` — bytes received
- `postfix.bytes_delivered` — bytes delivered

### Postscreen metrics

- `postfix.postscreen.active` — postscreen activity status
- `postfix.postscreen.connect` — postscreen connection count
- `postfix.postscreen.pass_new` — new passed connections
- `postfix.postscreen.pass_old` — recurrent passed connections
- `postfix.postscreen.reject` — rejected connections
- `postfix.postscreen.dnsbl` — DNSBL hits
- `postfix.postscreen.pregreet` — pregreet clients
- `postfix.postscreen.hangup` — client hangups
- `postfix.postscreen.whitelisted` — whitelisted clients

## Included Triggers

The template includes the following triggers:

- **Total triggers:** `55`
- **Severity breakdown:** `WARNING=22`, `HIGH=25`, `CRITICAL=4`, `DISASTER=4`

### Service availability

- **DISASTER** — Postfix Master Process is not running on `{{HOST.NAME}}`
- **CRITICAL** — Postfix SMTP Service is not reachable on `{{HOST.NAME}}`
- **HIGH** — Postfix Submission Service is not reachable on `{{HOST.NAME}}`
- **HIGH** — Postfix Submissions Service is not reachable on `{{HOST.NAME}}`

### Mail queue

- **WARNING** — Postfix Queue Disk Usage is high - `({ITEM.VALUE}%)` on `{{HOST.NAME}}`
- **HIGH** — Postfix Queue Disk Usage is very high - `({ITEM.VALUE}%)` on `{{HOST.NAME}}`
- **WARNING** — Postfix Mail Queue Size is too high - `({ITEM.VALUE} messages)` on `{{HOST.NAME}}`
- **HIGH** — Postfix Mail Queue Size is very high - `({ITEM.VALUE} messages)` on `{{HOST.NAME}}`
- **DISASTER** — Postfix Mail Queue Size is critical - `({ITEM.VALUE} messages)` on `{{HOST.NAME}}`

### TLS certificate expiration

The following trigger set is defined for both certificate checks (port `465` and port `587`):

- **WARNING** — Postfix TLS Certificate Expiration in `{ITEM.VALUE}` days on `{{HOST.NAME}}`
- **HIGH** — Postfix TLS Certificate Expiration soon in `({ITEM.VALUE} days)` on `{{HOST.NAME}}`
- **HIGH** — Postfix TLS Certificate Expiration imminent in `({ITEM.VALUE} days)` on `{{HOST.NAME}}`
- **CRITICAL** — Postfix TLS Certificate Expiration imminent in `({ITEM.VALUE} days)` on `{{HOST.NAME}}`
- **DISASTER** — Postfix TLS Certificate Expired `({ITEM.VALUE} days)` on `{{HOST.NAME}}`

### Log anomaly and security triggers

- **WARNING** — Postfix Log Errors Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Log Errors Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix Log Warnings Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Log Warnings Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix SASL Authentication Failures Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix SASL Authentication Failures Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix Relay Denials Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Relay Denials Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix Spam Rejections Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Spam Rejections Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix RBL Rejections Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix RBL Rejections Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix Unknown User Logins Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Unknown User Logins Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix Connection Timeouts Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Connection Timeouts Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix TLS Failures Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix TLS Failures Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix Quota Exceeded Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Quota Exceeded Detected on `{{HOST.NAME}}`
- **HIGH** — Postfix Virus Detections Detected on `{{HOST.NAME}}`
- **CRITICAL** — High Number of Postfix Virus Detections Detected on `{{HOST.NAME}}`

### Mail flow quality triggers

- **WARNING** — Postfix SMTP Connections are high - `({ITEM.VALUE} connections)` on `{{HOST.NAME}}`
- **HIGH** — Postfix connections are ery high - `({ITEM.VALUE} connections)` on `{{HOST.NAME}}`
- **WARNING** — Postfix Bounced Emails Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Bounced Emails Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix Deferred Emails Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Deferred Emails Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix Rejected Emails Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Rejected Emails Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix Discarded Emails Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Discarded Emails Detected on `{{HOST.NAME}}`
- **WARNING** — Postfix Held Emails Detected on `{{HOST.NAME}}`
- **HIGH** — High Number of Postfix Held Emails Detected on `{{HOST.NAME}}`

### Postscreen triggers

- **HIGH** — Postfix Postscreen Service is not active on `{{HOST.NAME}}`
- **WARNING** — Postfix: Postscreen rejecting heavily `({$ITEM.VALUE})` on `{{HOST.NAME}}`
- **HIGH** — Postfix: Postscreen reject flood `({$ITEM.VALUE})` on `{{HOST.NAME}}`
- **WARNING** — Postfix: Postscreen high number of connections with DNSBL Hits `({$ITEM.VALUE})` on `{{HOST.NAME}}`
- **WARNING** — Postfix: Postscreen high number of PREGREET clients `({$ITEM.VALUE})` on `{{HOST.NAME}}`
- **WARNING** — Postfix: Postscreen high number of client HANGUPs `({$ITEM.VALUE})` on `{{HOST.NAME}}`

## Template Macros

The template defines the following user macros (from `postfix-smtp.yaml`) for alert thresholds:

| Macro | Default | Description |
|---|---:|---|
| `{$POSTFIX.CONNECTIONS.WARN}` | `20` | Warning threshold for Postfix active connections |
| `{$POSTFIX.CONNECTIONS.HIGH}` | `50` | High threshold for Postfix active connections |
| `{$POSTFIX.QUEUE.DISK.WARN}` | `80` | Warning threshold for Postfix mail queue disk usage (%) |
| `{$POSTFIX.QUEUE.DISK.HIGH}` | '90' | High threshold for Postfix mail queue disk usage (%) |
| `{$POSTFIX.QUEUE.WARN}` | `20` | Warning threshold for Postfix mail queue size |
| `{$POSTFIX.QUEUE.HIGH}` | `50` | High threshold for Postfix mail queue size |
| `{$POSTFIX.QUEUE.DISASTER}` | `100` | Disaster threshold for Postfix mail queue size |
| `{$POSTFIX.ERR.WARN}` | `5` | Warning threshold for Postfix log errors (5min) |
| `{$POSTFIX.ERR.HIGH}` | `10` | High threshold for Postfix log errors (5min) |
| `{$POSTFIX.WARN.WARN}` | `5` | Warning threshold for Postfix log warnings (5min) |
| `{$POSTFIX.WARN.HIGH}` | `10` | High threshold for Postfix log warnings (5min) |
| `{$POSTFIX.SASL.WARN}` | `1` | Warning threshold for Postfix SASL authentication failures (5min) |
| `{$POSTFIX.SASL.HIGH}` | `5` | High threshold for Postfix SASL authentication failures (5min) |
| `{$POSTFIX.RELAY.WARN}` | `1` | Warning threshold for Postfix relay denials (5min) |
| `{$POSTFIX.RELAY.HIGH}` | `5` | High threshold for Postfix relay denials (5min) |
| `{$POSTFIX.SPAM.WARN}` | `1` | Warning threshold for Postfix spam rejections (5min) |
| `{$POSTFIX.SPAM.HIGH}` | `5` | High threshold for Postfix spam rejections (5min) |
| `{$POSTFIX.RBL.WARN}` | `1` | Warning threshold for Postfix RBL rejections (5min) |
| `{$POSTFIX.RBL.HIGH}` | `5` | High threshold for Postfix RBL rejections (5min) |
| `{$POSTFIX.USER.WARN}` | `1` | Warning threshold for Postfix unknown user logins (5min) |
| `{$POSTFIX.USER.HIGH}` | `5` | High threshold for Postfix unknown user logins (5min) |
| `{$POSTFIX.CONN.WARN}` | `1` | Warning threshold for Postfix connection timeouts (5min) |
| `{$POSTFIX.CONN.HIGH}` | `5` | High threshold for Postfix connection timeouts (5min) |
| `{$POSTFIX.TLS.WARN}` | `1` | Warning threshold for Postfix TLS failures (5min) |
| `{$POSTFIX.TLS.HIGH}` | `5` | High threshold for Postfix TLS failures (5min) |
| `{$POSTFIX.QUOTA.WARN}` | `1` | Warning threshold for Postfix quota exceeded entries (5min) |
| `{$POSTFIX.QUOTA.HIGH}` | `5` | High threshold for Postfix quota exceeded entries (5min) |
| `{$POSTFIX.VIRUS.WARN}` | `1` | Warning threshold for Postfix virus detections (5min) |
| `{$POSTFIX.VIRUS.HIGH}` | `5` | High threshold for Postfix virus detections (5min) |
| `{$POSTFIX.VIRUS.CRIT}` | `10` | Critical threshold for Postfix virus detections (5min) |
| `{$POSTFIX.BOUNCE.WARN}` | `1` | Warning threshold for Postfix bounced emails |
| `{$POSTFIX.BOUNCE.HIGH}` | `5` | High threshold for Postfix bounced emails |
| `{$POSTFIX.DEFER.WARN}` | `1` | Warning threshold for Postfix deferred emails |
| `{$POSTFIX.DEFER.HIGH}` | `5` | High threshold for Postfix deferred emails |
| `{$POSTFIX.REJECT.WARN}` | `1` | Warning threshold for Postfix rejected emails |
| `{$POSTFIX.REJECT.HIGH}` | `5` | High threshold for Postfix rejected emails |
| `{$POSTFIX.DISCARD.WARN}` | `1` | Warning threshold for Postfix discarded emails |
| `{$POSTFIX.DISCARD.HIGH}` | `5` | High threshold for Postfix discarded emails |
| `{$POSTFIX.HELD.WARN}` | `1` | Warning threshold for Postfix held emails |
| `{$POSTFIX.HELD.HIGH}` | `5` | High threshold for Postfix held emails |
| `{$POSTFIX.POSTSCREEN.WARN}` | `1` | Warning threshold for Postfix postscreen rejected connections (5min) |
| `{$POSTFIX.POSTSCREEN.HIGH}` | `5` | High threshold for Postfix postscreen rejected connections (5min) |
| `{$POSTFIX.POSTSCREEN.DNSBL.WARN}` | `1` | Warning threshold for Postfix postscreen DNSBL hits (5min) |
| `{$POSTFIX.POSTSCREEN.PREGREET.WARN}` | `1` | Warning threshold for Postfix postscreen pregreet clients (5min) |
| `{$POSTFIX.POSTSCREEN.HANGUP.WARN}` | `1` | Warning threshold for Postfix postscreen client hangups (5min) |

### Tuning recommendations

Default values are conservative and suitable for low-traffic environments. Adjust macros based on normal baseline behavior for your mail server.

#### Small server (low volume)

- Keep most defaults.
- Typical choices:
	- `{$POSTFIX.QUEUE.WARN}=20`, `{$POSTFIX.QUEUE.HIGH}=50`, `{$POSTFIX.QUEUE.DISASTER}=100`
	- `{$POSTFIX.ERR.WARN}=5`, `{$POSTFIX.ERR.HIGH}=10`
	- `{$POSTFIX.BOUNCE.WARN}=1`, `{$POSTFIX.BOUNCE.HIGH}=5`

#### Medium server (moderate volume)

- Increase log/event thresholds to reduce noise.
- Typical choices:
	- `{$POSTFIX.QUEUE.WARN}=100`, `{$POSTFIX.QUEUE.HIGH}=300`, `{$POSTFIX.QUEUE.DISASTER}=600`
	- `{$POSTFIX.ERR.WARN}=20`, `{$POSTFIX.ERR.HIGH}=50`
	- `{$POSTFIX.WARN.WARN}=20`, `{$POSTFIX.WARN.HIGH}=40`
	- `{$POSTFIX.BOUNCE.WARN}=10`, `{$POSTFIX.BOUNCE.HIGH}=30`

#### Large server (high volume)

- Use trend-based thresholds aligned to historical peaks.
- Typical starting points:
	- `{$POSTFIX.QUEUE.WARN}=500`, `{$POSTFIX.QUEUE.HIGH}=1500`, `{$POSTFIX.QUEUE.DISASTER}=3000`
	- `{$POSTFIX.ERR.WARN}=100`, `{$POSTFIX.ERR.HIGH}=250`
	- `{$POSTFIX.WARN.WARN}=80`, `{$POSTFIX.WARN.HIGH}=200`
	- `{$POSTFIX.BOUNCE.WARN}=50`, `{$POSTFIX.BOUNCE.HIGH}=150`

#### Practical guidance

- Start with warning thresholds around the 95th percentile of normal activity.
- Set high/critical thresholds around known incident levels.
- Tune in steps of 20–30% and observe alert quality for 1–2 weeks.
- Keep security-sensitive thresholds (`{$POSTFIX.SASL.*}`, `{$POSTFIX.TLS.*}`, `{$POSTFIX.VIRUS.*}`) relatively strict.
