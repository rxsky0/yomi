//! Everything that ties this build to a GitHub repository lives here.
//! Run `npm run set-repo -- your-name/yomi` to fill it in (it also updates ui/js/links.js).

macro_rules! github_repo {
    () => {
        "rxsky0/yomi"
    };
}

/// `owner/name` of the repository that publishes releases.
pub const REPO: &str = github_repo!();

/// Small icon shown on the Discord profile. Served straight from the repository.
pub const APP_ICON: &str = concat!(
    "https://raw.githubusercontent.com/",
    github_repo!(),
    "/main/ui/assets/app_icon.png"
);

/// True until `npm run set-repo` has been run. Update checks are skipped while
/// this is true, so a fresh fork never talks to a repository that doesn't exist.
pub fn repo_is_placeholder() -> bool {
    REPO.starts_with("YOUR_GITHUB_USERNAME/")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn icon_points_at_the_repo() {
        assert!(APP_ICON.contains(REPO));
        assert!(APP_ICON.ends_with("/ui/assets/app_icon.png"));
    }
}
