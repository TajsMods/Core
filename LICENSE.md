# **Taj's Mods Core License**

Copyright (c) 2025 TajemnikTV (Grzegorz Kaczmarski)

This license applies to the **Taj's Mods Core** library (the **"Core"**) for the game **Upload Labs**.

This license applies except where it conflicts with mandatory terms of the platform you obtained the Mod from (e.g., Steam Subscriber Agreement and any app-specific terms). In case of conflict, those terms control.

## 1) Definitions

* **"Core"** — The Taj's Mods Core library in any form (source code, scripts, binaries, assets, configs, documentation), including any updates.
* **"Official Source"** — The official repository at <https://github.com/TajsMods/Core> and official distribution channels controlled by the copyright holder.
* **"Add-on"** — An independent mod that interfaces with Core via its public APIs, but does not include Core's code/files.
* **"Commercial Add-on"** — Any Add-on for which you charge money, require payment, accept paid subscriptions, use paywalls, or otherwise monetize access.
* **"You"** — Any person or entity using Core.

## 2) Permitted Uses

### 2.1 Personal Use

You may download and use Core for personal gameplay and mod development.  

### 2.2 Creating Add-ons (Allowed)

You **may** create and distribute independent mods ("Add-ons") that:

* Interface with Core via its public APIs
* Declare Core as a **dependency** (without bundling it)
* Require users to obtain Core from the **Official Source**

✅ **Example:** Your mod has a `manifest.json` that lists `TajsMods/Core` as a dependency, and users download Core separately.

### 2.3 Source Availability Requirement (Commercial Add-ons Only)

If you distribute a **Commercial Add-on** (any Add-on that charges money or requires payment), you **must**:

* Make the Add-on's source code publicly accessible on **GitHub**
* Keep the source code reasonably up-to-date with distributed versions
* Not use technical measures to obfuscate the publicly available source code

**Free Add-ons** (those distributed at no cost, with no paywalls or monetization) are **not** required to share their source code.

**You may:**

* License your Commercial Add-on however you choose (including proprietary/ARR)
* Charge money for compiled/packaged versions
* Restrict commercial use, redistribution, or modification of your Add-on
* Keep your Add-on in a private repository during development (only public paid distribution triggers this requirement)

**Clarification:** This does not force your Commercial Add-on to be open source.  You retain all rights to your work and can license it restrictively.  This only requires source **availability** (not open source permissions) for paid Add-ons, fostering a collaborative ecosystem while allowing free mods to remain private.

**Donations and Tips:** Accepting voluntary donations or tips for a free Add-on does **not** make it a Commercial Add-on, as long as the Add-on remains freely accessible without payment requirements.

### 2.4 What is NOT Allowed for Add-ons

You may **not**:

* Bundle or redistribute Core files inside your Add-on
* Ship modified/patched builds of Core
* Publish "Core forks" as alternative distributions
* Rebrand or rename Core in your distribution
* Include Core's source code in your Add-on's repository (except as a git submodule pointing to Official Source)
* Distribute Commercial Add-ons publicly without making source code available on GitHub

### 2.5 Dependency Management

You may reference Core through:

* Git submodules pointing to the Official Source
* Dependency manifests that point to the Official Source
* Installation instructions directing users to the Official Source

## 3) Modification (Private Use Only)

You may modify Core **only for private, personal use**, unless Section 6 ("Contributions") applies.

You may **not** distribute modified versions of Core without explicit written permission.

## 4) Redistribution (Not Allowed)

**Redistribution of Core is NOT permitted**, including:

* Reuploading Core to other websites, repositories, or mirrors
* Bundling Core into mod-packs (users must obtain it separately)
* Providing direct downloads of Core files
* Publishing modified/forked versions as standalone distributions

✅ You **may** link to the **Official Source** for users to download Core themselves.

## 5) Commercial Use (Restricted)

You may **not**:

* Sell Core or any part of it
* Monetize access to Core (paywalls, paid downloads, etc.)
* Include Core in commercial products

However, you **may**:

* Create Commercial Add-ons that **depend on** Core (as long as Core remains freely available from Official Source, is not bundled, and your Add-on's source is available on GitHub per Section 2.3)
* Charge for compiled/packaged versions of your Add-on
* Accept voluntary donations or tips for free Add-ons (without source requirement)

## 6) Contributions & Pull Requests (Allowed, With Conditions)

To encourage community contributions, you may:  

1. **Fork** the Official Source **solely to prepare and submit Pull Requests (PRs)**
2. **Modify** your fork to develop features, fixes, or improvements
3. **Submit PRs** back to the Official Source

### 6.1 Fork Limitations

* Forks may be kept public on GitHub **only for PR purposes**
* You may **not** publish releases or builds from your fork
* You may **not** market your fork as an alternative to Core
* Any non-PR distribution remains prohibited

### 6.2 Contributor License Grant

By submitting a PR, you grant the copyright holder a **worldwide, perpetual, irrevocable, royalty-free, non-exclusive license** to:  

* Use, modify, distribute, and sublicense your contribution
* Include your contribution in Core and future versions
* Relicense Core in the future (including your contribution)

### 6.3 No Obligation

There is no obligation to merge, review, or support any contribution.

## 7) No Impersonation / Misrepresentation

You may **not**:

* Claim authorship of Core
* Remove or alter copyright/attribution notices
* Present modified versions as "official"

## 8) Attribution (Recommended)

When distributing Add-ons that depend on Core, you should:

* Clearly state that your Add-on requires Taj's Mods Core
* Link to the Official Source for Core
* Credit TajemnikTV (optional but appreciated)

## 9) Termination

Any violation **automatically terminates** your license.   You must delete all copies of Core in your possession.

Failure to comply with Section 2.3 (Source Availability Requirement for Commercial Add-ons) will result in termination of your license to use Core, and you must cease distribution of your Add-on immediately.

## 10) Contact (Permissions & Questions)

For special permissions, questions, or clarification:  

* **Email:** [tajemniktv@outlook.com](mailto:tajemniktv@outlook.com)
* **Social media:** @TajemnikTV

Special exemptions to the source availability requirement may be granted on a case-by-case basis.

## 11) Acknowledgments

Any assets, names, trademarks, and references related to **Upload Labs** remain the property of their respective owners.
Core is a fan-created project and is **not affiliated with or endorsed by** the game developers/publishers.

## 12) Disclaimer of Warranty

THE CORE IS PROVIDED **"AS IS"**, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY ARISING FROM THE USE OF CORE.  

## 13) Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, IN NO EVENT SHALL **Grzegorz "TajemnikTV" Kaczmarski** BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF CORE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

---

## TL;DR (Not Legally Binding)

**✅ You CAN:**

* Use Core as a dependency for your mods
* Tell users to download Core separately
* Submit improvements via Pull Requests
* Create free Add-ons (open or closed source - your choice!)
* Create Commercial Add-ons (with source on GitHub)
* Charge money for your Add-on while keeping source available
* Accept donations for free Add-ons (without source requirement)
* License your Add-on restrictively (ARR, no-redistribution, etc.)

**❌ You CANNOT:**

* Redistribute Core files
* Bundle Core in your mod
* Fork Core for alternative distribution
* Sell Core or charge for access to it
* Charge for Add-ons without making source code available on GitHub

**📋 You MUST (for Commercial Add-ons only):**

* Keep your Commercial Add-on's source code publicly accessible on GitHub
* Declare Core as a dependency (don't bundle it)

**💡 Free Add-ons can be open or closed source - your choice!**

**By using Core, you agree to these terms.**
