# 🔱 **SubMerge – Unified Subdomain Recon Framework (v1.0)**

**Author:** Umang Mishra
**Version:** 1.0
**License:** For authorized security testing only

---

## 🚀 About SubMerge

**SubMerge** is an automated subdomain reconnaissance tool for Kali Linux that combines multiple popular recon tools into a single pipeline.

It performs:

1. **Passive subdomain enumeration**

   * `amass`
   * `subfinder`
   * `assetfinder`

2. **Permutation generation**

   * `dnsgen` (with safe limits)

3. **DNS validation**

   * `massdns` (chunked execution)

4. **Alive host detection**

   * `httprobe`

This tool is designed for **bug bounty hunters, penetration testers, and security students** who want a structured and automated recon workflow.

---

## ⚠️ Legal Disclaimer

> **Use this tool ONLY on assets you own or have explicit permission to test.
> Unauthorized scanning is illegal. The author is not responsible for misuse.**

---

## 📁 Project Structure

```
SubMerge/
│── readme.md
│── submerge.sh
│── resolvers.txt
│── install.sh
└── output/
```

---

## ✅ Requirements (Install Dependencies)

Before running SubMerge, install the required tools:

## Automatic Installation
```bash
1. cd submerge
2. chmod +x install.sh
3. ./install.sh

```

## Automatic Installation

### Install Amass

```bash
sudo apt install amass
sudo amass db -update
```

### Install Subfinder

```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
```

### Install Assetfinder

```bash
go install -v github.com/tomnomnom/assetfinder@latest
```

### Install dnsgen

```bash
pip3 install dnsgen
```

### Install MassDNS

```bash
git clone https://github.com/blechschmidt/massdns.git
cd massdns
make
sudo cp bin/massdns /usr/local/bin/
```

### Install httprobe

```bash
go install -v github.com/tomnomnom/httprobe@latest
```

### Add Go tools to PATH

```bash
export PATH=$PATH:~/go/bin
```

---

## 📥 Installation

Clone the repository:

```bash
git clone https://github.com/your-username/SubMerge-Subdomain-Finder-Tool.git
cd SubMerge-Subdomain-Finder-Tool
```

Make the script executable:

```bash
chmod +x submerge.sh
```

Ensure `resolvers.txt` is present in the same directory.

---

## ▶️ Usage

### Basic scan

```bash
./submerge.sh example.com
```

### Example

```bash
./submerge.sh tesla.com
```

---

## 📤 Output Files

After completion, results will be stored in:

```
output/example.com/final/
├── resolved.txt   → All valid resolved subdomains  
└── alive.txt      → Only live HTTP/HTTPS hosts  
```

---

## 🧠 What SubMerge v1.0 is good for

* Bug bounty recon
* Learning recon workflows
* Automation practice
* Medium-sized scopes

---

## 🔮 Roadmap – SubMerge v2.0 (Planned)

In the next version, we plan to add many more features, and made this tool more efficient.

---

## ⭐ Contribute

Feel free to:

* Open issues
* Suggest features
* Submit pull requests

---

## 👤 Author

**Umang Mishra**
Cyber Security Student | Bug Bounty Enthusiast

---

