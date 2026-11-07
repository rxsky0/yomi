// Set with `npm run set-repo -- your-name/yomi` (also updates src-tauri/src/branding.rs).
export const REPO = "https://github.com/YOUR_GITHUB_USERNAME/yomi";
export const RELEASES_PAGE = `${REPO}/releases`;

// Invite link to your own Discord server. Leave empty to hide the "Join the Discord" buttons.
export const DISCORD_INVITE = "";

function windowsVersion() {
  return /Windows NT 10/.test(navigator.userAgent) ? "Windows 10/11" : "Windows";
}

function issueUrl({ title, body, label }) {
  const params = new URLSearchParams({ title, body, labels: label });
  return `${REPO}/issues/new?${params}`;
}

export function bugReportUrl(version) {
  const body = [
    "**What happened?**",
    "",
    "",
    "**What did you expect?**",
    "",
    "",
    "**How to make it happen again** (the VN, what you clicked…)",
    "",
    "",
    "---",
    `Yomi ${version} · ${windowsVersion()}`,
  ].join("\n");

  return issueUrl({ title: "Bug: ", body, label: "bug" });
}

export function suggestionUrl(version) {
  const body = [
    "**What would you like?**",
    "",
    "",
    "**Why / when would it help?**",
    "",
    "",
    "---",
    `Yomi ${version}`,
  ].join("\n");

  return issueUrl({ title: "Idea: ", body, label: "enhancement" });
}
