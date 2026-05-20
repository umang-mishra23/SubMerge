# 🔱 SubMerge – Unified Subdomain Recon Framework (v1.3)

> Automated subdomain reconnaissance framework for bug bounty hunters, penetration testers, and cybersecurity students.

---

## 🚀 Features

- Passive subdomain enumeration
- Parallel execution for faster recon
- Subdomain permutation generation
- DNS validation using MassDNS
- Live host detection with status codes
- Organized output structure
- Lightweight and fast
- Beginner-friendly workflow

---

## 🛠 Tools Used

SubMerge combines the power of multiple reconnaissance tools:

- Amass
- Subfinder
- Assetfinder
- Findomain
- dnsgen
- MassDNS
- HTTPX

---

## ⚡ Recon Workflow

```text
Passive Enumeration
        ↓
Merge Results
        ↓
Permutation Generation
        ↓
DNS Resolution
        ↓
HTTPX Live Detection
        ↓
Final Results
```

---

## 📁 Project Structure

```text
SubMerge/
│── README.md
│── submerge.sh
│── install.sh
│── resolvers.txt
└── output/
```

---

## ⚠️ Legal Disclaimer

> Use this tool ONLY on assets you own or have explicit permission to test.
>
> Unauthorized scanning is illegal.
>
> The author is not responsible for misuse.

---

# ⚙️ Installation

## 1️⃣ Clone Repository

```bash
git clone https://github.com/your-username/SubMerge.git

cd SubMerge
```

---

## 2️⃣ Make Scripts Executable

```bash
chmod +x install.sh
chmod +x submerge.sh
```

---

## 3️⃣ Run Automatic Installer

```bash
./install.sh
```

---

# 🔧 Manual Installation

## Install Amass

```bash
sudo apt install -y amass
```

---

## Install Subfinder

```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
```

---

## Install Assetfinder

```bash
go install -v github.com/tomnomnom/assetfinder@latest
```

---

## Install Findomain

```bash
cargo install findomain
```

---

## Install HTTPX

```bash
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
```

---

## Install dnsgen

```bash
sudo apt install -y pipx

pipx install dnsgen
```

---

## Install MassDNS

```bash
git clone https://github.com/blechschmidt/massdns.git

cd massdns

make

sudo cp bin/massdns /usr/local/bin/
```

---

## Add Go To PATH

```bash
export PATH=$PATH:$(go env GOPATH)/bin
```

Make it permanent:

```bash
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc

source ~/.bashrc
```

---

# ▶️ Usage

## Basic Scan

```bash
./submerge.sh example.com
```

---

## Example

```bash
./submerge.sh tesla.com
```

---

# 📤 Output Structure

```text
output/example.com/
├── raw/
└── final/
```

---

## Final Results

```text
output/example.com/final/
├── resolved.txt
└── alive.txt
```

---

## resolved.txt

Contains all valid resolved subdomains.

Example:

```text
api.example.com
dev.example.com
admin.example.com
```

---

## alive.txt

Contains live HTTP/HTTPS hosts with status codes.

Example:

```text
https://api.example.com [200]
https://admin.example.com [403]
https://dev.example.com [302]
```

---

# 🧠 What SubMerge Is Good For

- Bug bounty reconnaissance
- Subdomain enumeration
- Recon workflow learning
- Bash scripting practice
- Medium and large scopes
- Automation learning

---

# ⚡ Current Features

✅ Parallel enumeration  
✅ Safe Bash scripting  
✅ Chunked MassDNS execution  
✅ HTTP status code detection  
✅ Organized outputs  
✅ Dependency checking  

---

# 🔮 Planned Features (v2.0)

- Nuclei integration
- Screenshot support
- Technology detection
- Resume mode
- ASN mapping
- Docker support
- JSON output
- Config file support
- Wordlist support

---

# 🤝 Contributing

Contributions are welcome.

You can:
- Open issues
- Suggest features
- Submit pull requests

---

# 👤 Author

**Umang Mishra**

Cyber Security Student | Bug Bounty Enthusiast

---

# ⭐ Disclaimer

This project is made for:

- Educational purposes
- Authorized penetration testing
- Bug bounty reconnaissance

Do NOT use against targets without permission.