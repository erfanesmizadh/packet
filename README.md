<div align="center">

```
    ██████╗ ██╗   ██╗ █████╗ ███████╗██╗  ██╗
   ██╔═══██╗██║   ██║██╔══██╗██╔════╝██║  ██║
   ███████║ ██║   ██║███████║███████╗███████║
   ██╔══██║  ██╗ ██╔╝██╔══██║╚════██║██╔══██║
   ██║  ██║   ████╔╝ ██║  ██║███████║██║  ██║
   ╚═╝  ╚═╝   ╚═══╝  ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
```

# AVASH Tunnel Manager

**مدیریت تانل چند پروتکله — ضد سانسور و فیلترینگ**

[![Version](https://img.shields.io/badge/Version-1.0-blue?style=for-the-badge)](https://github.com/erfanesmizadh/packet)
[![Shell](https://img.shields.io/badge/Shell-Bash-green?style=for-the-badge&logo=gnu-bash)](https://github.com/erfanesmizadh/packet)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](https://github.com/erfanesmizadh/packet)
[![Telegram](https://img.shields.io/badge/Telegram-@AVASH__NET-blue?style=for-the-badge&logo=telegram)](https://t.me/AVASH_NET)

</div>

---

## 📋 معرفی

**AVASH Tunnel Manager** یک اسکریپت bash حرفه‌ای برای راه‌اندازی و مدیریت انواع تانل‌های شبکه‌ای روی سرور لینوکس است.  
این ابزار به صورت خاص برای **دور زدن فیلترینگ و سانسور اینترنتی** طراحی شده و از **۶ پروتکل مختلف** پشتیبانی می‌کند.

---

## ⚡ نصب سریع

```bash
bash <(curl -sL https://raw.githubusercontent.com/erfanesmizadh/packet/main/install.sh)
```

---

## 🔥 پروتکل‌های پشتیبانی شده

| پروتکل | توضیح | رمزنگاری | کاربرد |
|--------|-------|----------|--------|
| 🚀 **KCP (Paqet)** | Raw Packet Tunnel — ضد QoS و سانسور | ✅ AES / ChaCha20 | ایران ↔ خارج |
| 🔒 **WireGuard** | مدرن‌ترین VPN — سطح kernel | ✅ ChaCha20-Poly1305 | VPN کامل |
| 🌐 **GRE** | Generic Routing Encapsulation | ❌ | سایت به سایت |
| 🛡️ **IPsec** | امن‌ترین تانل — IKEv2 | ✅ AES-256-GCM | سازمانی |
| 📡 **SIT / 6in4** | IPv6 روی IPv4 | ❌ | شبکه IPv6 |
| ⚡ **IPIP** | IP-in-IP ساده‌ترین | ❌ | شبکه داخلی |

---

## 📦 هسته Paqet (نسخه بهینه AVASH)

این اسکریپت از **نسخه بهینه‌سازی شده Paqet** استفاده می‌کند:

| معماری | لینک دانلود |
|--------|------------|
| **AMD64** (x86_64) | [paqet-linux-amd64-v2.2.0-optimize](https://github.com/erfanesmizadh/packet/releases/download/paget/paqet-linux-amd64-v2.2.0-optimize.tar.gz) |
| **ARM64** | [paqet_linux_arm64-v2.2.0-optimize](https://github.com/erfanesmizadh/packet/releases/download/paget/paqet_linux_arm64-v2.2.0-optimize.tar.gz) |

---

## 🖥️ سیستم‌عامل‌های پشتیبانی شده

| سیستم‌عامل | نسخه | وضعیت |
|-----------|------|--------|
| Ubuntu | 20.04 / 22.04 / 24.04 | ✅ کامل |
| Debian | 10 / 11 / 12 | ✅ کامل |
| CentOS | 7 / 8 | ✅ کامل |
| Rocky Linux | 8 / 9 | ✅ کامل |
| AlmaLinux | 8 / 9 | ✅ کامل |
| Fedora | 36+ | ✅ کامل |

> ⚠️ باید با دسترسی **root** اجرا شود.

---

## 📋 پیش‌نیازها

برای **KCP** هیچ پیش‌نیاز خاصی لازم نیست — اسکریپت همه چیز رو نصب می‌کنه.

| ابزار | کاربرد | نصب خودکار |
|------|--------|-----------|
| `curl` / `wget` | دانلود فایل‌ها | ✅ |
| `iptables` | مدیریت فایروال | ✅ |
| `wireguard-tools` | فقط برای WireGuard | ✅ |
| `strongswan` | فقط برای IPsec | ✅ |
| `libpcap` | برای KCP | ✅ |

---

## 🗺️ منوی اصلی

```
╔══════════════════════════════════════════════════════════════════╗
║  Main Menu                                                         ║
╚══════════════════════════════════════════════════════════════════╝

  [0] ⚙️  Install Dependencies & Manager
  [1] 🖥️  Configure Server (Abroad/Kharej)
  [2] 🇮🇷 Configure Client (Iran/Domestic)
  [3] 🛠️  Manage Tunnel Services
  [4] 📊 Test Connection
  [5] 🚀 Optimize Server
  [6] 🤖 Telegram Bot
  [7] 🗑️  Uninstall All
  [8] 📦 نصب / آپدیت هسته Paqet
  [9] 🚪 Exit
```

---

## 🚀 راهنمای راه‌اندازی KCP (پیشنهادی)

### سرور خارج (Kharej)

```bash
bash <(curl -sL https://raw.githubusercontent.com/erfanesmizadh/packet/main/install.sh)
```

گزینه `[1]` ← `[1] KCP` را انتخاب کنید و پیکربندی کنید.

### سرور ایران (Client)

```bash
bash <(curl -sL https://raw.githubusercontent.com/erfanesmizadh/packet/main/install.sh)
```

گزینه `[2]` ← `[1] KCP` را انتخاب کنید و اطلاعات سرور خارج را وارد کنید.

---

## 🔒 راهنمای WireGuard

### سرور

```
[1] Configure Server → [2] WireGuard
Interface: wg0
Listen Port: 51820
Tunnel IP: 10.0.0.1/24
```

پس از راه‌اندازی، **Public Key** نمایش داده می‌شود — آن را برای کلاینت نگه دارید.

### کلاینت

```
[2] Configure Client → [2] WireGuard
Server Public IP: <IP سرور خارج>
Server Port: 51820
Server Public Key: <کلید از مرحله قبل>
Client IP: 10.0.0.2
```

---

## 🌐 راهنمای GRE

روی **هر دو سرور** اجرا کنید:

**سرور ایران:**
```
Tunnel Name: gre-iran
Local IP: <IP ایران>
Remote IP: <IP خارج>
Tunnel Local IP: 172.16.0.1
Tunnel Remote IP: 172.16.0.2
```

**سرور خارج:**
```
Tunnel Name: gre-kharej
Local IP: <IP خارج>
Remote IP: <IP ایران>
Tunnel Local IP: 172.16.0.2
Tunnel Remote IP: 172.16.0.1
```

تست اتصال:
```bash
ping 172.16.0.2
```

---

## 🧪 تست اتصال

از منوی اصلی گزینه `[4]` را انتخاب کنید:

```
[1] Ping + MTU Test     ← تست پینگ و بهترین MTU
[2] Internet Test       ← تست اینترنت
[3] DNS Test            ← تست DNS
[4] All Tunnels Status  ← وضعیت همه تانل‌ها
```

---

## ⚙️ مدیریت سرویس‌ها

گزینه `[3]` از منوی اصلی:

- ▶️ Start / Stop / Restart سرویس
- 📝 مشاهده لاگ‌ها
- ⏰ تنظیم ری‌استارت خودکار (Cron)
- 🗑️ حذف سرویس

---

## 🚀 بهینه‌سازی سرور

گزینه `[5]` موارد زیر را اعمال می‌کند:

```
✓ TCP BBR congestion control
✓ Socket buffers (64MB)
✓ IP Forwarding
✓ TCP FastOpen
✓ Connection tracking optimization
✓ File descriptor limits (1M)
✓ UDP buffer optimization (KCP/WireGuard)
```

---

## 📦 نصب هسته Paqet

گزینه `[8]` از منوی اصلی:

```
[1] نصب AMD64 بهینه AVASH    ← برای سرورهای معمولی
[2] نصب ARM64 بهینه AVASH    ← برای ARM (Oracle Free Tier)
[3] نصب خودکار               ← تشخیص معماری و نصب
[4] دانلود از GitHub اصلی
[5] نصب از فایل لوکال
[6] دانلود از URL دلخواه
[7] حذف Paqet
```

---

## 🤖 ربات تلگرام

گزینه `[6]` از منوی اصلی برای دریافت اعلان‌ها:

1. یک ربات از [@BotFather](https://t.me/BotFather) بسازید
2. Token ربات را وارد کنید
3. Chat ID خود را وارد کنید
4. پیام تست بفرستید

---

## 📁 ساختار فایل‌ها

```
/etc/avash-tunnel/
├── kcp/          ← کانفیگ‌های KCP (YAML)
├── wg/           ← کانفیگ‌های WireGuard
├── gre/          ← کانفیگ‌های GRE
├── ipsec/        ← کانفیگ‌های IPsec
├── sit/          ← کانفیگ‌های SIT
├── ipip/         ← کانفیگ‌های IPIP
└── bot.conf      ← تنظیمات ربات تلگرام

/var/log/avash-tunnel/
└── bot.log       ← لاگ ربات

/usr/local/bin/
├── avash-tunnel  ← اسکریپت اصلی
└── paqet         ← باینری Paqet

/etc/systemd/system/
└── avash-*.service  ← سرویس‌های systemd
```

---

## 🔧 دستورات مفید

```bash
# اجرای مجدد مدیر
avash-tunnel

# وضعیت همه سرویس‌های AVASH
systemctl list-units 'avash-*' --type=service

# لاگ یک سرویس
journalctl -u avash-kcp-myserver -f

# وضعیت WireGuard
wg show

# تانل‌های فعال
ip tunnel show
```

---

## ❓ سوالات رایج

**Q: آیا به kernel خاصی نیاز دارم؟**  
A: خیر، برای KCP هیچ نیازی نیست. WireGuard روی Ubuntu 20.04+ در kernel هست.

**Q: آیا روی Oracle Free Tier کار می‌کنه؟**  
A: بله، نسخه ARM64 برای Oracle Free Tier آماده است.

**Q: تفاوت KCP با WireGuard چیست؟**  
A: KCP برای دور زدن فیلترینگ (Anti-QoS) طراحی شده. WireGuard سریع‌ترین VPN کامل است.

**Q: چطور کانفیگ را ویرایش کنم؟**  
A: از منوی `[3] Manage Services` → سرویس را انتخاب → `[5] Edit Config`

---

## 📢 ارتباط و پشتیبانی

<div align="center">

[![Telegram Channel](https://img.shields.io/badge/Telegram_Channel-@AVASH__NET-blue?style=for-the-badge&logo=telegram)](https://t.me/AVASH_NET)

برای آموزش‌ها، آپدیت‌ها و پشتیبانی به کانال تلگرام مراجعه کنید.

</div>

---

<div align="center">

**ساخته شده با ❤️ برای کاربران ایرانی**

© 2025 AVASH_NET — MIT License

</div>
