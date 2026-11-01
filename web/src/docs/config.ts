/** Where the markdown lives on GitHub. The single place that names the repository. */
export const REPO_URL = 'https://github.com/arniber21/ustax';
export const REPO_BRANCH = 'main';
export const REPO_BLOB = `${REPO_URL}/blob/${REPO_BRANCH}`;
export const REPO_TREE = `${REPO_URL}/tree/${REPO_BRANCH}`;
export const REPO_RAW = `https://raw.githubusercontent.com/arniber21/ustax/${REPO_BRANCH}`;

/** GitHub URL of a repo file, for the "Edit this page" link. */
export const githubBlobUrl = (repoPath: string) => `${REPO_BLOB}/${repoPath}`;
