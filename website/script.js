// ApexKey landing — small enhancements
(function () {
  // Reformat GitHub "latest release" URL as an absolute download anchor
  const downloadLink = document.querySelector('.download-actions .btn[href*="releases/latest"]');
  if (downloadLink) {
    fetch('https://api.github.com/repos/BoraSarang/ApexKey/releases/latest', { headers: { Accept: 'application/vnd.github.v3+json' } })
      .then((r) => (r.ok ? r.json() : Promise.reject()))
      .then((data) => {
        const asset = (data.assets || []).find((a) => a.name.endsWith('.dmg') || a.name.endsWith('.zip'));
        if (asset) {
          downloadLink.href = asset.browser_download_url;
          downloadLink.textContent = '⬇ 최신 릴리즈 (' + (data.tag_name || 'v' + data.name) + ')';
        }
      })
      .catch(() => { /* keep default link */ });
  }
})();
