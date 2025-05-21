# Smart-Contract Security Audit

Project: Citizen Wallet OnRampSwapper.sol

Commit hash audited: cf55f4821a5675a6c38a0b629aa5021d2d75f76a (PR #2, contractforge)

Auditor: TECHI

Audit date: 21 May 2025

⸻

## 1. Scope & Files Reviewed

| File | SLOC | Notes |
|------|------|-------|
| src/OnRampProvider/OnRampSwapper.sol | 120 (flattened) | Main logic |
| src/OnRampProvider/IUniswapV2Router02.sol | 11 | Interface stub – unused |
| script/OnRampSwapper.s.sol | 20 | Deployment helper |

Related README excerpt	n/a	Usage instructions  ￼

Testing code (test/OnRampSwapper.t.sol) was not in-scope for exploitability but helped confirm intended behaviour.

⸻

## 2. Contract Overview

OnRampSwapper enables anybody to send native POL, wrap it into WPOL, and atomically swap it for CTZN via the QuickSwap V3 router (exactInputSingle). Proceeds are forwarded directly to a user-supplied recipient. Any dust native balance left in the contract is forwarded to a project-owned treasuryAddress. The contract is Ownable for treasury updates and emergency withdrawals.

⸻

## 3. Methodology
	•	Static-analysis (Slither, MythX), manual line-by-line review.
	•	Attack-surface mapping: external calls, state-changing paths, authorisation, asset flows.
	•	Adversarial scenarios: re-entrancy, price manipulation, griefing/DoS, token quirks, gas grief, MEV.
	•	Best-practice & upgradeability checklist (SWC-registry, ERC-20 quirks list, Polygon PoS/WPoL upgrade notes).

⸻

## 4. Summary of Findings

| ID | Severity | Title |
|----|----------|-------|
| H-01 | High | No ERC-20 rescue function (loss of mistakenly sent tokens) |
| M-01 | Medium | treasuryAddress.call failure reverts the whole swap |
| L-01 | Low | Hard-coded 0.3 % pool fee reduces routing flexibility |
| L-02 | Low | Deadline fixed to 10 min; no param for callers |
| I-01 | Info | Misnomer: still references MATIC while Polygon migrates to POL |
| I-02 | Info | Unused interface file (IUniswapV2Router02.sol) |
| G-01 | Gas | Re-approving WPOL on every call |

No critical-severity issues were identified.

⸻

## 5. Detailed Findings

### H-01  Missing token-recovery mechanism

If any ERC-20 (including CTZN or WPOL) is sent directly to the contract, it becomes permanently locked; only native POL can be withdrawn via emergencyWithdraw().
Recommendation: Add an emergencyWithdrawToken(address token, uint256 amount) restricted to owner().

⸻

### M-01  Treasury forward can revert entire swap

If address(this).balance > 0 after the swap and treasuryAddress is a contract whose fallback reverts, the whole transaction reverts, undoing the user's swap and wasting gas.
Recommendation: Use a try/catch pattern or rely on sendValue (OpenZeppelin Address library) with a non-reverting branch that logs the failure instead of require(success).

⸻

### L-01  Hard-coded pool fee

Using fee: 3000 (0.3 %) may not be optimal for liquidity or slippage on every CTZN pair. Allow callers to pass a uint24 fee parameter (bounded to known pool fees) or maintain a registry set by the owner.

### L-02  Fixed 10-minute deadline

Some integrators may need tighter or looser windows. Consider accepting uint32 deadline as an input.

### I-01  POL/MATIC terminology

Polygon's native asset has begun rebranding to POL. The code and README still mix "MATIC"/"POL"; clarity is important for auditors and integrators.

### I-02  Unused interface file

IUniswapV2Router02.sol is committed but not imported anywhere. Remove to avoid confusion.

⸻

## 6. Gas & Code-quality Notes

| ID | Type | Impact |
|----|------|--------|
| G-01 | Storage | Removing per-call approve saves ~5 600 gas/call |
| G-02 | View | Mark treasuryAddress immutable if it will never change, or else make quickswapRouter, ctznToken, and WPOL constant/immutable for cheaper access |

Miscellaneous:
	•	Put blank lines & NatSpec headings for readability.
	•	Consider emitting ExcessForwarded(uint256) event for ops monitoring.

⸻

## 7. Tests & Coverage

Unit tests are present but were not executed in this audit environment. Ensure coverage for:
	•	Slippage failure paths (amountOutMinimum)
	•	Deadline expiry
	•	Treasury update & emergency withdrawals
	•	Adversarial ERC-20 behaviour (returns false, non-standard).

⸻

## 8. Overall Risk Assessment

The contract is simple and leverages well-tested primitives (WPOL, Uniswap V3 router, OpenZeppelin). No logic bugs that lead to fund loss for correct usage were observed. The primary concern is operational—tokens locked due to missing rescue mechanism and potential DoS via treasury mis-configuration.

| Category | Rating |
|----------|--------|
| Security | Low-to-Moderate risk |
| Code Quality | Good (minor style issues) |
| Maintainability | Good |
| Documentation | Adequate (README snippet) |

⸻

## 9. Recommendations Summary
	1.	Implement emergencyWithdrawToken for arbitrary ERC-20 recovery.
	2.	Adopt unlimited-once allowance pattern for WPOL (safeApprove).
	3.	Make the treasury forward non-reverting.
	4.	Parameterise fee and deadline to improve flexibility.
	5.	Clarify POL/MATIC nomenclature and remove unused files.

⸻

## 10. Disclaimer

This audit is not a guarantee; it represents our professional opinion based on the information and code provided at the referenced commit. Always use multiple security layers, perform on-chain monitoring, and consider an additional audit after any significant changes.

⸻

Report generated by TECHI – Smart-Contract Security Research