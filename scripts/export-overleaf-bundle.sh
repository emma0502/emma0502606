#!/usr/bin/env bash
# Build a self-contained directory (and optional zip) for uploading to Overleaf.
# Usage:
#   ./scripts/export-overleaf-bundle.sh
#   OUTPUT_ZIP=1 ./scripts/export-overleaf-bundle.sh   # also writes ../emma0502606-overleaf.zip next to repo root

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${ROOT}/dist/overleaf-emma0502606"

rm -rf "${OUT}"
mkdir -p "${OUT}"

echo "Exporting LaTeX tree → ${OUT}"

# Core driver + wiring
cp "${ROOT}/emma0502606.tex" "${ROOT}/Subfiles.ltx" "${ROOT}/._relpath-to-latexroot.ltx" "${OUT}/"
cp "${ROOT}/Abstract.txt" "${ROOT}/references.bib" "${OUT}/" 2>/dev/null || true
[[ -f "${ROOT}/emma0502606.bbl" ]] && cp "${ROOT}/emma0502606.bbl" "${OUT}/"

# BibTeX does not read LaTeX's \input@path — ship bst next to .tex for reliability.
cp "${ROOT}/@resources/texlive/texmf-local/bibtex/bst/econark.bst" "${OUT}/"

# Overleaf / latexmk: point BibTeX at bundled styles if cwd differs.
cat > "${OUT}/.latexmkrc" << 'EOF'
# Local econark.bst lives in ./@resources/texlive/texmf-local/bibtex/bst/
ensure_path( 'BSTINPUTS', './@resources/texlive/texmf-local/bibtex/bst//');
EOF

mkdir -p "${OUT}/Subfiles"
cp "${ROOT}/Subfiles/"*.tex "${OUT}/Subfiles/"

# Figures actually referenced by the paper (tracked in git)
mkdir -p "${OUT}/Figures"
git -C "${ROOT}" ls-files Figures/ | while read -r f; do
  mkdir -p "${OUT}/$(dirname "$f")"
  cp "${ROOT}/${f}" "${OUT}/${f}"
done

# Bundled class + style paths (required by econark.cls outside vanilla TeX Live)
mkdir -p "${OUT}/@resources" "${OUT}/@local"
cp "${ROOT}/@resources/project-metadata.ltx" "${ROOT}/@resources/tex-paths.ltx" "${OUT}/@resources/"
[[ -f "${ROOT}/@resources/subfile-setup.ltx" ]] && cp "${ROOT}/@resources/subfile-setup.ltx" "${OUT}/@resources/"
rsync -a --delete "${ROOT}/@resources/texlive/" "${OUT}/@resources/texlive/"

# Full @local tree (metadata, local.sty, owner, texlive extras on input@path)
rsync -a "${ROOT}/@local/" "${OUT}/@local/"

# Optional equation snippets if ever referenced (currently unused by wired subfiles; cheap to include)
if [[ -d "${ROOT}/Equations" ]]; then
  rsync -a "${ROOT}/Equations/" "${OUT}/Equations/"
fi

cat > "${OUT}/README-OVERLEAF.txt" << 'EOF'
Who Holds Government Debt? — Overleaf upload bundle
==================================================

1. Zip this entire folder (contents at top level, not the parent dist/ folder):
      cd dist && zip -r ../emma0502606-overleaf.zip overleaf-emma0502606

2. Overleaf → New Project → Upload Project → select the zip.

3. Menu (left) → Main document: emma0502606.tex

4. Compiler: pdfLaTeX (default Full TeX Live on Overleaf is usually fine).

5. Build:
   - Menu → Compiler → pdfLaTeX + BibTeX (or latexmk if offered).
   - We ship econark.bst in the project root and under @resources/.../bst/;
     .latexmkrc sets BSTINPUTS for local latexmk builds.
   - We also ship emma0502606.bbl (pre-built bibliography). Overleaf may still
     run BibTeX once — references.bib must stay alongside emma0502606.tex.

6. Folder names @local and @resources are intentional — they hold the econark
   document class and project-specific style files bundled with this REMARK.

Do NOT delete @resources/texlive or @local/texlive subtrees unless you know
exactly which CTAN packages Overleaf already provides; this project pins a
minimal local texmf for reproducibility.

Source of truth for edits remains your Git repository; re-export after major
changes with:
      ./scripts/export-overleaf-bundle.sh
EOF

echo "Done. Bundle ready at: ${OUT}"

if [[ "${OUTPUT_ZIP:-}" == "1" ]]; then
  ZIP="${ROOT}/../emma0502606-overleaf.zip"
  rm -f "${ZIP}"
  (cd "${ROOT}/dist" && zip -rq "${ZIP}" overleaf-emma0502606)
  echo "Wrote ${ZIP}"
fi
